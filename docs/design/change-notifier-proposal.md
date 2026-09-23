# Especificación: FactoryChangeNotifier

Estado: diseño aceptado con Q1–Q9 confirmadas. Implementado en el núcleo Dart
y el adaptador Flutter, con pruebas de contrato y de integración con Provider.

## Uso

```dart
class ProfileController extends FactoryChangeNotifier {
  ProfileController(super.resolver);

  Future<void> load() async {
    final repository = resolve(userRepository);
    await repository.loadProfileName();
  }
}

final profileController = Factory<ProfileController>(
  (ref) => ProfileController(ref.resolver),
  dispose: (controller) => controller.dispose(),
);
```

`userRepository` es una declaración `Factory<UserRepository>` instalada en un
ámbito accesible. `FactoryChangeNotifier`, `FactoryResolver`, `resolve` y
`FactoryRef.resolver` son la superficie pública. El método `load` ilustra solo
la resolución; la aplicación sigue gestionando su estado y sus notificaciones.

## Contrato confirmado

- Integración opcional que introduce acoplamiento a Factory; la inyección por
  constructor de dependencias concretas sigue disponible.
- Clase base Flutter que recibe explícitamente un resolver por constructor.
- Selección por declaración `Factory<T>`; sin búsqueda implícita por tipo.
- Resolución al inicializar y desde métodos mientras notifier y ámbito estén
  activos. No hay observación automática de reemplazos ni cambios de estado.
- Cada lectura respeta `scoped`/`unique` sin caché adicional. Para conservar un
  resultado, el consumidor lo guarda explícitamente en un campo.
- Se mantiene `resolve(...)` como acceso explícito. Las anotaciones `@Inject`
  y la generación de inicialización de campos quedan para otro alcance.

## Contratos de acceso y vigencia

- `FactoryResolver` ofrece resolución síncrona tipada y se obtiene de
  `FactoryRef.resolver` durante la construcción. Queda ligado al ámbito dueño
  y a la instancia consumidora que se está construyendo, sin exponer operaciones
  de administración del ámbito.
- La base delega `resolve` en esa capacidad y rechaza el acceso después de su
  propio `dispose`; el cierre del ámbito invalida el acceso desde su inicio.
  Se lanzan `StateError` descriptivos para esos usos inválidos.
- El acceso se permite desde el cuerpo del constructor, inicializadores `late`
  y métodos. No se promete llamar a métodos de instancia desde la lista de
  inicialización previa a `super`.
- Una lectura obtiene la resolución vigente en ese momento. Guardar un resultado
  en un campo conserva esa referencia y no suscribe al notifier a reemplazos.
- Se rechazan con `StateError` descriptivo las lecturas que introduzcan
  un ciclo entre dependientes, aunque ambas instancias ya estén construidas.
  Esto permite mantener el orden de limpieza sin definir un orden arbitrario
  para recursos mutuamente dependientes. Una lectura rechazada no agrega la
  arista que cerraría el ciclo; no se revierte la construcción de dependencias
  realizada al intentar esa lectura, y esas instancias conservan su limpieza.

## Contratos existentes que se conservan

- Las declaraciones deben estar instaladas y las sustituciones respetan el
  ámbito dueño y su cadena de padres; no se agrega un contenedor global.
- La limpieza se declara en `Factory.dispose`. La base no dispone las
  dependencias resueltas ni cierra el contenedor. Las instancias recibidas
  conservan propietario externo.
- Resolver es síncrono; un servicio resuelto puede ofrecer operaciones
  asíncronas. La nueva API no cancela ni administra esas operaciones.
- El puente Provider sigue exponiendo y escuchando `ChangeNotifier` con su
  mecanismo existente.

## Condiciones de implementación y verificación

1. Probar construcción y uso posterior sin árbol de widgets, con overrides
   y resolución de dos declaraciones del mismo tipo.
2. Comprobar aislamiento entre ámbitos y política de reutilización acordada.
3. Rechazar acceso después de `dispose` o inicio del cierre, incluyendo
   continuaciones asíncronas que intenten resolver de nuevo.
4. Preservar aristas y orden de limpieza para dependencias adquiridas tarde,
   con liberación única y respeto de valores prestados.
5. Mantener cada capacidad asociada a su instancia original al recrear el
   notifier. El core conserva instancias anteriores hasta el cierre; sus
   lecturas no deben atribuirse al nuevo notifier.
6. Probar el rechazo de ciclos introducidos por lecturas tardías, además de los
   detectados durante construcción. Una lectura rechazada no agrega su arista.
7. Verificar que la base conserva las notificaciones y la limpieza del puente
   Provider, y que leer no agrega suscripciones a dependencias.

La [investigación](../research/change-notifier-dependency-resolution.md) recoge
las fuentes; la [entrevista](change-notifier-discovery.md) distingue respuestas
confirmadas de propuestas. El [ADR 0012](../adr/0012-resolucion-opcional-en-notifiers.md)
documenta la excepción de acoplamiento.
