# Investigación: resolución de dependencias desde `ChangeNotifier`

Fecha: 23 de septiembre de 2026. Esta nota recoge hechos del código y de las
APIs propietarias, y delimita decisiones pendientes. No decide una API ni
propone una implementación.

Las preguntas y referencias al código describen la investigación previa al
cambio. El diseño resultante quedó aceptado en Q1–Q9 y se implementó; su contrato
vigente está en la [especificación](../design/change-notifier-proposal.md).

## Pregunta

Se quiere que un `ChangeNotifier` pueda resolver con facilidad dependencias
inyectadas por Factory. Las alternativas a evaluar son un mixin y una nueva
base/implementación de notifier. La pregunta de diseño no es sólo sintáctica:
incluye qué scope resuelve, cuánto dura el acceso, qué identidad recibe, quién
libera recursos y si la resolución observa cambios.

## Hechos del repositorio

- `Factory<T>` recibe un `FactoryRef` únicamente al construir o actualizar el
  valor. `FactoryRef.read`, `watch` y `select` reciben una declaración
  `Factory<T>`, no un tipo; por tanto pueden distinguir dos implementaciones
  del mismo contrato mientras que el Provider expuesto sólo permite una por
  tipo y scope. [factory.dart](../../packages/factory_core/lib/src/factory.dart#L21)
  [container.dart](../../packages/factory_core/lib/src/container.dart#L401)
- El ref actual es una vista interna de un _record_ concreto: cada lectura
  registra la arista de dependencia; `watch` exige que la factory consumidora
  elija una `ChangePolicy`; `select` además registra un listener mediante el
  observer del contenedor. No hay contrato que diga que un `FactoryRef` pueda
  guardarse y usarse después de que termine el callback de construcción.
  [container.dart](../../packages/factory_core/lib/src/container.dart#L401)
- El contenedor local es el propietario de las factories instaladas allí y
  busca hacia el padre si no las encuentra. Conserva una instancia `scoped` por
  scope y crea una `unique` en cada resolución. Las instancias propias con
  cleanup se liberan al cerrar, después de los scopes hijos y de los
  dependientes; los valores de `overrideWithValue` no tienen callback de
  liberación. [container.dart](../../packages/factory_core/lib/src/container.dart#L83)
  [container.dart](../../packages/factory_core/lib/src/container.dart#L300)
  [factory.dart](../../packages/factory_core/lib/src/factory.dart#L87)
- La construcción es síncrona (`T Function(FactoryRef)`); el cierre sí puede
  esperar `Future<void>`. [factory.dart](../../packages/factory_core/lib/src/factory.dart#L21)
  [container.dart](../../packages/factory_core/lib/src/container.dart#L300)
- `FactoryScope` crea el contenedor en `didChangeDependencies`, conserva ese
  contenedor hasta `dispose`, y le entrega un observer para `Listenable`.
  Su marcador heredado permite obtener el scope más cercano desde un
  `BuildContext`, pero un notifier construido por Factory no recibe un
  `BuildContext`. [factory_scope.dart](../../lib/src/factory_scope.dart#L42)
  [factory_scope.dart](../../lib/src/factory_scope.dart#L66)
- La adaptación existente ya escucha automáticamente a los valores expuestos
  cuyo tipo declarado es `ChangeNotifier`: registra `addListener` y devuelve
  una función que ejecuta `removeListener`. El Provider no adquiere la
  liberación de la instancia; el contenedor lo hace únicamente si su factory
  declaró `dispose`. [factory_scope.dart](../../lib/src/factory_scope.dart#L251)
  [factory_scope_test.dart](../../test/factory_scope_test.dart#L168)
  [factory_scope_test.dart](../../test/factory_scope_test.dart#L198)
- El ejemplo mantiene la inyección por constructor: `ProfileController` no
  importa Factory y recibe repositorio y monitor en su constructor. Es el
  comportamiento de la ruta de inyección por constructor exigido por el ADR de
  retirada. La entrevista actual aceptó una excepción opcional para los
  notifiers que adopten resolución interna, documentada en
  [ADR 0012](../adr/0012-resolucion-opcional-en-notifiers.md).
  [profile_controller.dart](../../example/lib/presentation/profile_controller.dart#L6)
  [ADR 0001](../adr/0001-limitar-acoplamiento-a-configuracion.md#L1)
- La reactividad de grafo ya es optativa y explícita. `read` no reacciona a un
  reemplazo; `watch` puede recrear o actualizar; `select` sólo propaga si su
  valor seleccionado cambia. Los tests cubren identidad estable, recreación,
  desuscripción y orden de cleanup. [changes_test.dart](../../packages/factory_core/test/changes_test.dart#L167)
  [changes_test.dart](../../packages/factory_core/test/changes_test.dart#L244)

## Hechos de Dart y Flutter

- `ChangeNotifier` es una clase que puede extenderse o mezclarse y ofrece la
  API `Listenable`: `addListener`, `removeListener`, `notifyListeners` y
  `dispose`. Añadir listeners es O(1); quitarlos y notificar son O(N).
  [Flutter API: ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- Después de `dispose`, el objeto deja de ser utilizable, `addListener` falla,
  `dispose` no notifica y debe llamarlo sólo su propietario. Las subclases que
  lo sobreescriban deben llamar a `super.dispose()`. [Flutter API:
  ChangeNotifier.dispose](https://api.flutter.dev/flutter/foundation/ChangeNotifier/dispose.html)
- Un `mixin` no puede declarar constructores generativos ni recibir parámetros
  de constructor para inicializar sus propios campos. Puede declarar miembros
  abstractos que la clase receptora debe aportar. Una cláusula `on` restringe
  los receptores a subtipos del tipo indicado, y se usa para que `super` se
  resuelva contra esa superclase. [Dart: mixins](https://dart.dev/language/mixins)
- La construcción normal es donde Dart inicializa campos; el lenguaje también
  admite un constructor `factory` que puede devolver una instancia existente
  o una subclase, pero no puede acceder a `this`. [Dart:
  constructors](https://dart.dev/language/constructors)

## Consecuencias para las alternativas

| Alternativa | Qué puede resolver | Límite estructural | Acoplamiento y ciclo de vida |
| --- | --- | --- | --- |
| Mixin `on ChangeNotifier` | Puede exponer métodos que deleguen en un resolver que la clase aporte | No puede aceptar el resolver en su propio constructor; cada clase debe declarar/implementar cómo se obtiene el resolver, o se requiere estado externo | Un campo asignado por el constructor de la clase queda ligado a un scope concreto; hay que impedir uso tras cierre y decidir si este contrato hace que la clase de negocio dependa de Factory. |
| Clase base de Factory | Puede recibir y guardar una capacidad de resolución en su constructor y centralizar guardas | Dart sólo permite una superclase: una clase que ya extiende otra base no puede adoptarla; sigue sin eliminar la necesidad de una fuente de resolver y scope | Hace explícito el acoplamiento a Factory, en tensión directa con ADR 0001; `dispose` debe seguir llamar a `super.dispose()`. |
| Composición: resolver/capacidad como dependencia | El notifier recibe una interfaz reducida por constructor, igual que hoy recibe repositorios | Requiere decidir la interfaz y las claves/declaraciones permitidas; no da azúcar de mixin | Es testeable con un fake y puede mantener Factory fuera de la clase si la interfaz pertenece al dominio; aun así debe definir si vive más allá del scope. |
| Resolver global/ambiental | El notifier podría pedir dependencias sin parámetro | Requiere definir cómo se selecciona y conserva el scope; un singleton global no representa todos los ámbitos | Un acceso ambiental necesitaría un contrato adicional para respetar ámbitos anidados y overrides; no es una capacidad existente. |

`mixin class` no elimina la limitación relevante: puede usarse como clase o
mixin desde Dart 3, pero una aplicación que la mezcle no obtiene parámetros de
construcción para sus campos, y una que la extienda pierde su única herencia.
El SDK mínimo actual (Dart 3.3) sí permite declararla, pero esa disponibilidad
no resuelve su contrato de inicialización. [Dart: mixin class](https://dart.dev/language/mixins)

## Riesgos que cualquier contrato debe cerrar

1. **Procedencia y vigencia.** Una capacidad inyectada debe estar ligada al
   contenedor que construyó el notifier, no al scope que sea más cercano en un
   widget posterior. Tras `close`, resolver debe fallar de forma definida;
   conservar un `FactoryRef` actual más allá del callback no tiene garantía
   pública ni prueba que lo respalde.
   Además, delegar directamente en `FactoryContainer.read` no registra una
   arista entre el notifier y la dependencia. La nueva capacidad debe decidir
   cómo preservar el orden de limpieza cuando la dependencia se obtiene después
   de crear el notifier; ligar el acceso a un scope, por sí solo, no resuelve
   este punto. Esta es una inferencia del contraste entre `read`, `_Ref.read`
   y el recorrido de cierre. [container.dart](../../packages/factory_core/lib/src/container.dart#L95)
   [cierre](../../packages/factory_core/lib/src/container.dart#L335)
   Al recrear una instancia, `_build` conserva el valor anterior en otro record
   y reutiliza el record original para el nuevo valor. Un resolver retenido que
   siga apuntando al record original podría atribuir lecturas del notifier
   anterior al nuevo. La vinculación debe ser por instancia, no solamente por
   declaración, si ambas siguen vivas hasta el cierre.
   [recreación](../../packages/factory_core/lib/src/container.dart#L128)
2. **Identidad y caché.** Declarar que el notifier “resuelve” no basta:
   `scoped` devuelve la identidad del scope dueño y `unique` devuelve una por
   resolución. Una resolución tardía de `unique` también entra en el orden de
   cleanup si declara liberación. El usuario debe decidir si el notifier puede
   adquirir múltiples snapshots o debe cachearlos por cuenta propia.
3. **Asincronía.** Factory no construye de forma asíncrona. Un notifier puede
   iniciar trabajo asíncrono tras obtener una dependencia, pero debe comprobar
   su propio estado antes de publicar resultados y el contrato debe aclarar qué
   pasa si el scope se cierra durante ese trabajo.
4. **Propiedad.** Resolver una dependencia no transfiere su propiedad al
   notifier. El callback de `Factory.dispose` sigue siendo el único lugar que
   libera una instancia propia; una instancia recibida sigue siendo prestada.
   Añadir `notifier.dispose()` de manera automática además del callback puede
   duplicar `dispose`.
5. **Reactividad.** Obtener una dependencia al demandarla puede ser sólo
   `read`, o puede registrar `watch`/`select`. La segunda opción requiere
   elegir `ChangePolicy`, listener de `Listenable`, desuscripción y qué ocurre
   si el notifier ya fue dispuesto. No debe aparecer implícitamente sólo por
   usar el nuevo mixin/base.
6. **Pruebas.** Hace falta separar pruebas de contrato puro (resolver
   inexistente, scope cerrado, scoped/unique, override y ownership), pruebas
   del grafo core (propagación, desuscripción, cierre) y widget tests (el
   adaptador Provider agrega y quita exactamente un listener). El repositorio
   ya tiene seams para las tres capas. [container_test.dart](../../packages/factory_core/test/container_test.dart)
   [changes_test.dart](../../packages/factory_core/test/changes_test.dart)
   [factory_scope_test.dart](../../test/factory_scope_test.dart#L7)

## Recomendaciones de investigación, no decisiones

- Mantener la construcción por constructor como línea base: ya expresa el
  grafo, conserva la retirada por composición y entrega dependencias listas
  para usar. El ejemplo actual es el caso de referencia.
- Si se acepta una excepción para notifiers, preferir una capacidad pequeña y
  scope-bound sobre exponer `FactoryContainer` o reutilizar el `FactoryRef`
  interno actual. Esto permitiría definir explícitamente operaciones, vigencia
  y observación, y evita que una API interna de tracking quede retenida.
- Tratar mixin y base como ergonomía posterior a ese contrato. Primero se debe
  resolver de dónde nace la capacidad y si la clase de negocio puede conocerla;
  después se podrá evaluar si un mixin reduce repetición sin ocultar esa
  dependencia.
- Empezar con resolución no reactiva si el objetivo es sólo composición tardía.
  Ofrecer observación sólo con una política explícita y una prueba de
  desuscripción, ya que el core distingue con precisión `read`, `watch` y
  `select`.

## Preguntas abiertas para la entrevista

1. **Resuelto en Q1:** integración opcional; el camino de inyección por
   constructor conserva su contrato de retirada desde configuración.
2. **Resuelto en Q2:** solo resolución explícita, sin reacción automática a
   reemplazos ni escucha de estado. Sigue pendiente cuándo podrá resolver.
3. **Resuelto en Q3–Q5:** declaraciones `Factory<T>`, resolver explícito por
   constructor y disponibilidad al inicializar y desde métodos, mientras el
   notifier y el ámbito estén activos.
4. ¿Qué contrato tiene una llamada después del cierre del scope y qué debe
   ocurrir con operaciones asíncronas ya iniciadas?
5. Para `unique`, ¿cada llamada devuelve una nueva instancia deliberadamente,
   o la API debe exigir que el notifier declare una caché?
6. ¿Quién declara la limpieza de un notifier que también obtiene recursos:
   siempre su `Factory<T>.dispose`, o se admite alguna convención adicional?

## Apéndice: la sintaxis explorada `@Inject`

La forma literal propuesta, `@Inject final repository: Repository;`, **no es
sintaxis de declaración de campo Dart**. Un campo tipado se escribe con el tipo
antes del nombre. Aun con una anotación, un campo `final` no inicializado debe
recibir valor por el inicializador del constructor; por eso una forma que Dart
puede declarar para inicialización posterior es, como mínimo:

```dart
@Inject()
late final Repository repository;
```

`late final` permite una sola asignación posterior, pero leerlo antes de esa
asignación produce un error en tiempo de ejecución. Es una propiedad del
lenguaje, no una inyección automática. [Dart: variables `late`
y `final`](https://dart.dev/language/variables) [Dart: campos de
instancia](https://dart.dev/language/classes)

Una anotación puede describir el campo para una herramienta: Dart exige que la
metadata sea una referencia constante o una llamada a constructor `const`.
Por ello `@Inject(repositoryFactory)` no puede tomar directamente una variable
top-level `final` que contiene un `Factory<Repository>` (esa instancia no es
una constante de compilación). Una alternativa que requeriría diseño y soporte
del generador sería guardar en la annotation un selector constante, por ejemplo
un *tear-off* de función top-level que devuelva la declaración Factory. Esto
preserva la identidad de declaración requerida por el contenedor, pero todavía
hay que validar su forma exacta, genéricos e imports con el analizador y diseñar
el generador que lo interprete. [Dart: metadata](https://dart.dev/language/metadata)

### Qué puede y no puede hacer generación ordinaria

El builder actual no procesa campos: agrupa exclusivamente `@Register` sobre
`public top-level final Factory<T>` y escribe una biblioteca vecina
`.factory.dart`. No reescribe la clase original ni sus constructores.
[factory_module_builder.dart](../../packages/factory_generator/lib/src/factory_module_builder.dart#L18)
[factory_module_builder.dart](../../packages/factory_generator/lib/src/factory_module_builder.dart#L103)

En general, `build_runner`/`source_gen` generan una biblioteca o una parte
separada; no transforman un constructor existente para añadirle un
inicializador a un `final`. Una parte generada podría añadir un helper que
asigne el `late final`, pero la instancia ya existe: exige que el autor invoque
un hook explícito después de la construcción y antes de leer el campo. Eso no
es equivalente a inyectar por constructor, y abre la pregunta de quién llama
el hook, una sola vez y con qué resolver de scope. [source_gen:
builders](https://pub.dev/documentation/source_gen/latest/)

Otra forma de código generado es un mixin con un getter abstracto para la
capacidad de resolución y un getter concreto, perezoso y tipado para el campo.
Evita asignar un `late final` desde fuera, pero no crea ni entrega el resolver:
la clase debe aportar el getter/campo y el contrato debe impedir usarlo después
de cerrar el scope. Sigue siendo una decisión de API, no algo que la anotación
por sí sola pueda realizar.

Si no se elige generación, el equivalente explícito es que el notifier reciba
la capacidad de resolución en su constructor y asigne el campo `late final` o
lo inicialice perezosamente. El campo es entonces una **caché declarada por la
clase**: almacenar `repository` define que sus lecturas posteriores usan esa
misma instancia. Esto no cambia la decisión de no añadir caché implícita al
resolver y conserva la semántica de `scoped`/`unique` del apartado anterior.

Para la dirección ya explorada —resolver explícito, resolución solamente, sin
reactividad— el generador no debe introducir `watch`, `select`, listeners ni
una `ChangePolicy`. También debe conservar la declaración Factory como clave;
resolver por `Repository` perdería las implementaciones múltiples que el
contenedor distingue por `Factory<T>`.

## Fuentes y método

Se usó la documentación oficial de Dart y Flutter enlazada arriba y Context7
para localizarla; el resultado relevante de Context7 fue la documentación de
mixins de `dart-lang/site-www`. Los enlaces al repositorio son la fuente de los
hechos actuales. No se encontró `AGENTS.md`; los documentos de investigación
existentes usan `docs/research/`, por lo que esta nota sigue esa convención.
