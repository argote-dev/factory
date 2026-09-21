# Anotaciones para instalar Factory en Provider

Investigación: 20 de septiembre de 2026.

Alcance: evaluar una capa opcional de generación que evite repetir una lista de
declaraciones en cada `FactoryScope`. No se implementó código ni se decidió API.
La versión observada de `injectable` en pub.dev fue 3.0.0; las APIs de este
documento se presentan como ejemplos propios.

## Hallazgo principal

Dart permite adjuntar metadatos estáticos a declaraciones mediante `@` y una
constante de compilación. Una anotación sobre una variable `final` de nivel de
biblioteca puede, por tanto, marcar una declaración `Factory<T>` sin modificar la
clase `T` ni sus constructores. Esto preserva el acuerdo de que las clases de
negocio sólo reciban dependencias por constructor.
[Metadatos de Dart](https://dart.dev/language/metadata).

La generación de código es una vía habitual en Dart: `build_runner` ejecuta un
builder una vez con `dart run build_runner build` o lo mantiene actualizado con
`dart run build_runner watch`. La documentación describe activarla con una
anotación y un archivo generado, por lo que encaja como comodidad opcional y no
como requisito del runtime de Factory.
[build_runner: instalación y watch](https://pub.dev/packages/build_runner).

`source_gen` provee el modelo de builders que escriben partes (`.g.dart`) o una
biblioteca Dart independiente importable (`LibraryBuilder`). Un generador de
Factory puede analizar una biblioteca de composición, buscar sus declaraciones
anotadas y producir un agregador explícito por módulo/ámbito.
[source_gen: tipos de Builder](https://pub.dev/packages/source_gen).

## Forma que mejor conserva la filosofía

Anotar la *declaración Factory*, en un archivo de composición, separa la
configuración de la aplicación de sus clases de dominio:

```dart
// auth_factories.dart
@Expose(scope: 'app')
final authRepository = Factory<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClient)),
);

@Expose(scope: 'app')
final sessionController = Factory<SessionController>(
  (ref) => SessionController(ref.read(authRepository)),
);
```

El generador podría emitir, conceptualmente, algo como:

```dart
// auth_factories.factory.dart — generado
final appProviders = <Factory<Object>>[
  authRepository,
  sessionController,
];
```

La aplicación instalaría el módulo una vez:

```dart
FactoryScope(providers: appProviders, child: const App());
```

El código generado sólo reúne objetos `Factory`; no llama a `read`, no ejecuta
los closures y no crea instancias. Por ello no cambia el lazy acordado: una
dependencia se crea al resolverla por primera vez, conforme a su política de
vida. La lista también mantiene la visibilidad explícita aceptada: sólo las
fábricas marcadas se adaptan a Provider; las internas se resuelven para construir
otras, sin aparecer por accidente en `context.read`.

`scope: 'app'` es sólo una etiqueta de diseño. El paquete puede definir un tipo o
constante pública para evitar strings frágiles y diferenciar el ámbito raíz de
uno de flujo/pantalla. El ejemplo no adopta esos nombres todavía.

## Por qué no anotar las clases de dominio

`injectable` muestra el enfoque alternativo: marcar `class ServiceA` y
`class ServiceB(ServiceA serviceA)` con `@injectable`; el generador infiere
registros desde constructores. También ofrece anotaciones para singleton, lazy
singleton, nombres, módulos de terceros y ámbitos.
[Injectable: registro y código generado](https://pub.dev/packages/injectable),
[Injectable: módulos y ámbitos](https://pub.dev/packages/injectable).

Es una referencia útil para la ergonomía, pero no encaja completamente con este
proyecto. Anotar las clases propias obliga a importar la anotación de Factory en
el dominio; retirar el paquete ya no sería cambiar sólo la configuración. Además,
los paquetes externos, dos claves del mismo tipo, factories con lógica de
composición y callbacks `dispose` necesitan módulos o metadatos adicionales.

El propio Injectable soluciona dependencias de terceros con una clase `@module`
que contiene getters o métodos anotados. Eso apoya la idea de concentrar los
registros en composición, aunque nuestra propuesta puede ser aún más directa:
conservar las `Factory<T>` explícitas ya elegidas y generar únicamente listas de
exposición.
[Injectable: tipos de terceros y módulos](https://pub.dev/packages/injectable).

Su opción de registrar clases por patrón de nombre (`Service`, `Repository`,
`Bloc`) reduce anotaciones pero introduce convención implícita. No se recomienda
para Factory: puede exponer accidentalmente un tipo, dificulta explicar la
visibilidad y hace menos predecible la retirada.
[Injectable: auto-registro por patrón](https://pub.dev/packages/injectable).

## Comparación con Riverpod Generator

`riverpod_generator` demuestra una sintaxis de anotaciones sobre funciones: una
función marcada `@riverpod` genera un provider correspondiente. Ese mecanismo
reduce boilerplate, pero el resultado pertenece al modelo de consumo de
Riverpod, no al de Provider.
[Riverpod Generator: función anotada y provider generado](https://pub.dev/packages/riverpod_generator).

Factory puede tomar la lección de anotar la unidad de composición, sin generar
providers Riverpod ni alterar `context.read`, `watch`, `Consumer` o los
`ChangeNotifier` de una aplicación Provider existente.

## Sin descubrimiento dinámico ni macros

No conviene buscar factories por reflexión en ejecución. Flutter no proporciona
`dart:mirrors`; su FAQ señala la generación de código como la alternativa cuando
se necesita trabajar con metadatos.
[FAQ de Flutter: reflection/mirrors](https://docs.flutter.dev/resources/faq#does-flutter-come-with-a-reflection--mirrors-system).

Las macros tampoco son una base publicable: el equipo de Dart informó el 29 de
enero de 2025 que detuvo el trabajo de macros porque no veía convergencia hacia
una función lista para enviar con rendimiento de desarrollo aceptable.
[Actualización oficial sobre macros](https://dart.dev/blog/an-update-on-dart-macros-data-serialization).
La documentación actual de `build_runner` también indica que los compiladores
de Dart no admiten macros.
[Documentación actual de Dart](https://dart.dev/tools/build_runner).

Un builder estático conserva analizabilidad, árboles de dependencias explícitos
y diagnósticos de metadatos durante la generación. No implica inferir o validar
todas las conexiones dentro de closures arbitrarios. También permite que el paquete base no
dependa de `build_runner`, `source_gen` ni `analyzer`: se publicarían, si se
elige, `factory_annotations` y `factory_generator` como paquetes opt-in.

## Agregación explícita y módulos

El objetivo no debe ser escanear toda la aplicación y exponer todo. Cada archivo
de composición puede declarar una entrada anotada que nombre el módulo y alcance:

```dart
@FactoryModule(scope: FactoryScopeName.app)
void installAppFactories() {}
```

El generador puede asociar a esa entrada las anotaciones de la biblioteca, o una
lista explícita de imports/exports que admita el diseño, y emitir `appProviders`.
La aplicación conserva un único punto visible de instalación. Para un flujo, un
segundo módulo genera su lista y se instala en un `FactoryScope` anidado.

No conviene prometer la inferencia de closures arbitrarios: el builder puede leer
metadatos y referencias declaradas, pero `ref.read` ocurre dentro de código de
usuario. Diagnósticos de build deben limitarse a metadatos y agregación (ámbitos,
duplicados, referencias visibles); el grafo y los ciclos siguen en Factory runtime.
Una factory eager interna exige además un registro o instalación separado: una
lista de exposición a Provider no debe registrar silenciosamente todo el módulo.

Esta forma tiene dos ventajas frente a un registro universal: el ámbito donde se
crearán y liberarán las instancias está escrito en la composición, y un revisor
puede saber qué llega a Provider sin seguir un escaneo global. Si el paquete
admite nombres o claves para el mismo tipo, la anotación debe referenciar la
declaración `Factory` concreta, nunca reducir la identidad a `Type`.

La necesidad de una entrada de inicialización y métodos generados por ámbito
tiene precedente en Injectable: `@InjectableInit` genera la inicialización y
`@Scope` separa métodos de inicio por alcance.
[Injectable: inicialización](https://pub.dev/packages/injectable),
[Injectable: scopes](https://pub.dev/packages/injectable).

## Límites y preguntas para un futuro prototipo

La anotación no puede transportar closures de construcción ni `dispose`, pues
los argumentos de metadata deben ser constantes de compilación. Eso no es una
limitación: ambos permanecen en el valor `Factory<T>` explícito y el generador
sólo referencia ese valor.
[Dart: metadata y constantes](https://dart.dev/language/metadata).

El generador debe diagnosticar, durante build: identificador de scope desconocido,
declaración duplicada en el mismo módulo, una fábrica no pública si el archivo
generado necesita importarla, y una exposición incompatible con el adaptador de
Provider. La resolución de dependencias ausentes y ciclos sigue siendo trabajo
del runtime de Factory, porque depende de `ref.read` en closures de usuario.

Conviene probar un prototipo con: una app Provider existente que conserva sus
widgets, un cliente interno no expuesto, dos clientes del mismo tipo con claves,
un `ChangeNotifier` expuesto, y un módulo de flujo que se libera al salir. Medir
el coste de añadir `build_runner` y la experiencia de errores antes de prometer
generación en v1.

## Recomendación de investigación

Ofrecer primero la API manual ya acordada. Diseñar una extensión opcional de
anotaciones sobre variables `Factory<T>` en archivos de composición, con un
agregador generado por módulo/ámbito. No anotar clases de negocio, no usar
auto-registro por nombres, no hacer reflexión de runtime y no alterar la
semántica lazy ni la exposición explícita a Provider.

Esta es una recomendación informada, pendiente de una decisión de producto y de
un prototipo de `source_gen`; no modifica los ADRs existentes.
