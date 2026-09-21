# Recorrido completo de API para revisión

Estado: propuesta ilustrativa, no implementada ni compilada. Los contratos de
`specification.md` están acordados; los nombres auxiliares y detalles operativos
de este documento requieren revisión conjunta. Las clases de aplicación se omiten.

## Declaraciones y módulos

Se propone `Register` para marcar declaraciones internas o expuestas. Amplía el
`Expose` provisional para incluir dependencias internas eager en el mismo módulo.
Las anotaciones permanecen en composición, nunca en las clases de negocio.

```dart
@Register(module: 'app')
final apiClient = Factory<ApiClient>(
  (_) => ApiClient(),
  dispose: (client) => client.close(),
);

@Register(module: 'app', expose: true)
final userRepository = Factory<UserRepository>(
  (ref) => UserRepository(ref.read(apiClient)),
);

@Register(module: 'profile', expose: true)
final profileController = Factory<ProfileController>(
  (ref) => ProfileController(ref.read(userRepository)),
  dispose: (controller) => controller.dispose(),
);
```

ProfileController sería un ChangeNotifier propio de la app que recibe el repositorio
por constructor. El generador produciría `appModule` y `profileModule` desde un punto
de entrada que seleccione las bibliotecas de composición a procesar.

La alternativa manual equivalente para la raíz sería:

```dart
final appModule = FactoryModule(
  factories: [apiClient, userRepository],
  expose: [userRepository],
);
```

Propuesta operativa: instalar explícitamente cada declaración, manualmente o con
el generador, para que su ámbito propietario no dependa del primer consumidor.
No se exige ordenar la lista: Factory resuelve las conexiones. Una declaración
ausente produciría diagnóstico. El generador no ejecuta las funciones de construcción.

La política predeterminada sigue siendo lazy y reutilización por ámbito. Se propone
nombrar esta política `Lifetime.scoped`; `Lifetime.unique` produce otra instancia por
resolución. La opción `lazy: false` crea al abrir el ámbito, incluso si la declaración
no figura en `expose`. No actúa al declarar la variable.

## Ámbito raíz y flujo hijo

```dart
FactoryScope(
  modules: [appModule],
  child: ExistingApp(),
)

// Dentro del árbol anterior, al abrir el perfil:
FactoryScope(
  modules: [profileModule],
  child: ProfilePage(),
)
```

La pantalla conserva `context.watch<ProfileController>()`. El adaptador conserva
notificaciones cuando el tipo declarado es ChangeNotifier, sin duplicar su limpieza.
Las declaraciones distintas pueden compartir tipo, pero se propone rechazar dos
exposiciones del mismo tipo en un mismo ámbito para no elegir una silenciosamente.

## Recibir una dependencia existente

Se propone declarar un contrato externo tipado:

```dart
final session = Factory<Session>.external();
```

En esta variante del arranque, `appModule` incluiría también `session` como declaración
interna. Bajo el Provider existente de Session, el archivo de composición lo enlaza:

```dart
Builder(
  builder: (context) => FactoryScope(
    modules: [appModule],
    overrides: [
      session.overrideWithValue(context.watch<Session>()),
    ],
    child: ExistingApp(),
  ),
)
```

`overrideWithValue` presta la instancia; Factory no la libera. Se propone comparar
identidad al enlazarla de nuevo para no recrear dependientes solo por una reconstrucción
del widget. La escucha de estado dentro de Factory sigue siendo optativa y explícita.

## Sustituir localmente y elegir dependientes

```dart
FactoryScope(
  modules: [profileModule],
  overrides: [apiClient.overrideWithValue(previewClient)],
  local: [userRepository],
  child: ProfilePage(),
)
```

Se propone `local` para instalar en el hijo una declaración heredada que debe
construirse allí. El controlador local recibe el repositorio local y este usa
`previewClient`. El repositorio del padre conserva su cliente original.

Sin `local`, heredar el repositorio no vuelve a conectar sus campos. Una variante
de sustitución por función de construcción, con su callback opcional de limpieza,
permitiría recursos propios; su firma se concretará manteniendo la propiedad explícita.

## Observar cambios y recrear o actualizar

Propuesta: `read` no suscribe; `watch` observa reemplazos de instancia; un selector
explícito permite observar estado de un objeto compatible. Una declaración que
observe cambios debe elegir su política de actualización.

```dart
final accountRepository = Factory<AccountRepository>(
  (ref) => AccountRepository(
    ref.read(apiClient),
    ref.watch(session, select: (value) => value.userId),
  ),
  onChange: ChangePolicy.recreate,
  dispose: (repository) => repository.close(),
);
```

En esta variante Session sería observable. Conservar una instancia se expresaría
con `onChange: ChangePolicy.update` y un argumento `update` que recibe el acceso a
dependencias y la instancia anterior. La firma exacta debe validarse en el prototipo.

Si recrear falla, futuras resoluciones comunican el error y no entregan la instancia
anterior. No se pueden revocar referencias entregadas previamente. El fallo de una
actualización in situ no promete rollback. El momento de retirar instancias
reemplazadas y la propagación de cambios necesitan verificación técnica específica.

## Prueba sin widgets y cierre esperable

```dart
final container = FactoryContainer(
  modules: [appModule],
  overrides: [apiClient.overrideWithValue(fakeClient)],
);

try {
  final repository = container.read(userRepository);
  // Comprobar el comportamiento del repositorio.
} finally {
  await container.close();
}
```

Este caso usa el módulo simple inicial, sin el contrato externo Session. Cada prueba
crea su contenedor. El test conserva responsabilidad sobre el fake prestado.

`close()` esperaría toda la limpieza y comunicaría sus errores juntos, respetando
hijos antes del padre y dependientes antes de dependencias. Se propone un cierre
idempotente y rechazar resoluciones desde que comienza el cierre.

Para ámbitos de widgets se propone una vía de seguimiento del cierre y un callback
de errores configurables. Desmontar inicia el cierre sin esperar. La aplicación
podría cerrar explícitamente y esperar cuando deba terminar una escritura antes
de abandonar un flujo. No se introduce construcción asíncrona.

## Example y retirada

La aplicación `example` contendrá dos composiciones sobre las mismas clases y
widgets: con Factory y con Provider directo. Se propone seleccionarlas desde
entradas distintas para repetir las pruebas de comportamiento. La ruta sin Factory
no importará el paquete en su configuración, negocio ni consumidores.

## Qué requiere aceptación de esta propuesta

- Nombres y forma conjunta: `Register`, `FactoryModule`, `modules`, `local`,
  `FactoryContainer`, `Lifetime.scoped`, enlaces externos y observación/cierre.
- Instalación explícita para asignar ámbito propietario, en ambos modos.
- Diagnóstico de exposiciones del mismo tipo duplicadas en un ámbito.
- Cierre idempotente y rechazo de resoluciones una vez iniciado.

La forma exacta del entrypoint del generador, la adaptación tipada de notifiers,
el orden de propagación y la entrega de errores se validarán técnicamente. Si el
prototipo requiere cambiar un contrato acordado se volverá a discutir; no se
consideran cambios autorizados por omisión.
