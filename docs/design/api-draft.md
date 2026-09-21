# Borrador de API para discusión

Este documento conserva los primeros ejemplos de la entrevista. La propuesta
integrada que incorpora módulos internos/expuestos y el ciclo de vida acordado
está en [usage-proposal.md](usage-proposal.md). Usar ese recorrido para la revisión
final; los ejemplos de listas simples de este archivo son antecedentes.

Estado: el nombre `Factory<T>` y el uso de argumentos nombrados están aceptados.
Los demás detalles de sintaxis son ilustrativos y no están implementados; las
clases de la aplicación se omiten. Las decisiones aceptadas están en los ADRs.

## Declaraciones

Propuesta: una declaración tipada identifica la dependencia y contiene su función
de construcción. Reutilización por ámbito y creación lazy son los valores por defecto.
`Factory<T>` es el nombre elegido. `Lifetime`, `ref` y sus miembros siguen siendo
nombres provisionales; las opciones se expresarán mediante argumentos nombrados.

```dart
final apiClient = Factory<ApiClient>(
  (_) => ApiClient(),
  dispose: (client) => client.close(),
);

final userRepository = Factory<UserRepository>(
  (ref) => UserRepository(ref.read(apiClient)),
);

final exportJob = Factory<ExportJob>(
  (_) => ExportJob(),
  lifetime: Lifetime.unique,
  dispose: (job) => job.close(),
);

final appService = Factory<AppService>(
  (_) => AppService(),
  lazy: false,
);
```

Declarar estos objetos no ejecuta sus funciones de construcción. La opción
`lazy: false` actuaría cuando la declaración se instala en un ámbito, no al
declarar la variable. `ref.read` expresa la conexión; todavía no expresa una
suscripción a cambios. La API para observar y actualizar/recrear sigue abierta.

El objeto de declaración propone una identidad tipada que permitiría distinguir
dos clientes del mismo tipo. No se propone inferir construcciones desde un `Type`.
Las clases de negocio reciben objetos por constructor y no importan Factory.

## Opciones todavía pendientes

### Propuesta de integración con Provider

Concepto aceptado en Q23/Q24: un `FactoryScope` instala un ámbito y expone
explícitamente ciertas declaraciones a los widgets descendientes. Las dependencias
internas necesarias para construirlas pueden resolverse sin quedar expuestas a
Provider. Los consumidores conservan sus lecturas y suscripciones existentes.

```dart
FactoryScope(
  providers: [userRepository],
  child: ExistingApp(),
)
```

Este ejemplo es conceptual, no código de una API implementada. Instalar y exponer
son operaciones distintas; el módulo agrupará las declaraciones internas y la
selección de expuestas. Si el tipo declarado es `ChangeNotifier`, sus notificaciones
se adaptarán automáticamente. El nombre `providers` es provisional.
Si `userRepository` necesita `apiClient`, se propone resolver el cliente internamente
sin publicarlo automáticamente a los widgets.

Está aceptado generar opcionalmente esta lista mediante anotaciones en las
declaraciones `Factory` de la configuración, usando `build_runner watch` durante
el desarrollo. El nombre y los parámetros exactos de las anotaciones siguen abiertos.

Ejemplo conceptual de esa alternativa; sintaxis todavía provisional:

```dart
// Archivo de configuración; no se anota UserRepository.
@Expose(scope: 'app')
final userRepository = Factory<UserRepository>(
  (ref) => UserRepository(ref.read(apiClient)),
);

// appProviders sería una lista generada, no mantenida a mano.
FactoryScope(
  providers: appProviders,
  child: ExistingApp(),
)
```

`Expose` y `appProviders` no existen todavía. La anotación propone seleccionar
explícitamente la exposición; el generador agruparía declaraciones y produciría
referencias a ellas, sin construir sus servicios. La etiqueta `app` agrupa la salida
generada: no crea por sí sola un ámbito en ejecución ni sustituye su propiedad.
La alternativa manual sigue disponible. Está aceptado que el módulo generado
contenga también las dependencias internas eager, sin exponerlas. La forma concreta
del módulo debe reemplazar o ampliar este ejemplo de lista simple.

### Decisiones restantes

- Elegir nombres definitivos de las opciones restantes después de evaluar los
  ejemplos completos; `Factory<T>` y argumentos nombrados ya están aceptados.
- Registro/instalación de declaraciones y exposición selectiva a Provider,
  incluyendo `ChangeNotifier`, sin alterar consumidores existentes.
- Enlace de instancias recibidas y reconstrucción explícita en ámbitos hijos.
- Escucha explícita de cambios y callbacks de actualización/recreación.
- API de cierre esperable y comunicación de fallos: están aceptados callbacks
  síncronos/asíncronos, dependientes antes de dependencias, hijos antes de padre e
  intento de todas las limpiezas aunque una falle.
- Diagnóstico de ciclos, dependencias ausentes, uso de un ámbito cerrado y fallos
  de construcción.
- Compatibilidad y criterios de publicación, conforme a la investigación.

No hay código del paquete ni pruebas ejecutables de esta API todavía.
