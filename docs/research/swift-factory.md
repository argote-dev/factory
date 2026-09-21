# Swift Factory como referencia para Factory en Flutter

Investigación: 20 de septiembre de 2026. Se consultaron documentación y código
oficiales de `hmlongco/Factory`, rama `main`, commit
`b02457db582b6773c578f407e43350a15bf79cb6`. El README de esa revisión anuncia
Factory 3.4.0; se estudió esa revisión, sin asumir que corresponde al último tag
publicado. No se ejecutaron pruebas Swift ni se implementó una adaptación Dart.
[Repositorio en la revisión consultada](https://github.com/hmlongco/Factory/tree/b02457db582b6773c578f407e43350a15bf79cb6).

## Qué significa cada política

| Política de Swift Factory | Reutilización |
| --- | --- |
| `unique` | Nueva instancia en cada resolución; valor predeterminado salvo configuración del contenedor. |
| `cached` | Conserva la instancia en el contenedor hasta vaciar la caché o liberar el contenedor. |
| `singleton` | Comparte la instancia de esa fábrica entre contenedores mediante una caché externa a ellos. |
| `shared` | Caché débil: reutiliza mientras exista la instancia, sin mantenerla viva por sí sola. |
| `graph` | Reutiliza durante una cadena de resolución; requiere habilitación explícita. |

Se pueden crear políticas personalizadas, como una caché de sesión. `application`
no figura como política incorporada en las definiciones consultadas; no atribuirle
un significado oficial. `Container.shared` es el acceso al contenedor compartido,
no la política débil `.shared` de una dependencia.
[Scopes: documentación](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/Sources/FactoryKit/FactoryKit.docc/Basics/Scopes.md),
[definiciones de Scope](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/Sources/FactoryKit/FactoryKit/Scopes.swift),
[contenedores](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/Sources/FactoryKit/FactoryKit/Containers.swift).

Ejemplo explicativo propio: dos repositorios piden un cliente HTTP. Con `unique`
reciben clientes distintos; con `cached`, comparten el del mismo contenedor; con
`shared`, compartirán el existente mientras otros objetos lo retengan. Otro
contenedor tiene su propia caché `cached`; una fábrica `singleton` conserva la
identidad compartida entre contenedores.

## Lazy responde a otra pregunta

Las definiciones de fábricas proporcionan funciones de construcción. Resolver
una fábrica solicita su producto. `@Injected` resuelve al inicializar el wrapper;
`@LazyInjected` pospone la resolución hasta acceder a la propiedad por primera
vez y conserva su resultado. La reutilización de las resoluciones de la fábrica
se configura por separado. Por eso, lazy no equivale a singleton, shared ni async.
[Implementación de los wrappers](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/Sources/FactoryKit/FactoryKit/Injections.swift).

Para nuestro proyecto, distinguir:

- **Declarar**: proporcionar cómo se construye un objeto.
- **Resolver**: pedir el objeto y construirlo si la política lo requiere.
- **Reutilizar**: decidir si otra solicitud obtiene una instancia existente.

Estas distinciones explican el diseño; no fijan aún nombres públicos.

## API y pruebas: qué resulta aprovechable

El README muestra fábricas tipadas como propiedades del contenedor, resolución
directa y composición por constructor. También permite reemplazar la construcción
por implementaciones de prueba. Los ejemplos de Swift Testing usan contenedores
aislados por prueba; los de XCTest restablecen el contenedor entre casos.
[README: registros, resolución y pruebas](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/README.md).

**Propuesta para Flutter:** copiar la idea de una declaración tipada por
dependencia, referencias explícitas a otras declaraciones y sustituciones para
pruebas. Mantener las llamadas al contenedor dentro de la configuración y pasar
objetos por constructor conserva el contrato ya acordado de retirada. Copiar
wrappers o búsquedas de Factory dentro del negocio introduciría acoplamiento que
ese contrato no admite.

## Vaciar caché no actualiza objetos existentes

En Swift Factory, resetear un ámbito o contenedor afecta resoluciones futuras;
los objetos ya entregados no se reemplazan. La caché singleton se resetea por
separado. El TTL también se evalúa al resolver y se renueva al acceder antes de
su vencimiento.
[Reset y TimeToLive](https://github.com/hmlongco/Factory/blob/b02457db582b6773c578f407e43350a15bf79cb6/Sources/FactoryKit/FactoryKit.docc/Basics/Scopes.md).

**Consecuencia para nuestro diseño:** no confundir reset con la política acordada
de actualizar/recrear dependientes. Si un repositorio ya recibió un cliente,
vaciar su caché no modifica por sí solo el campo del repositorio. Esa propagación
sería una capacidad adicional que nuestro paquete debe definir explícitamente.

## Diferencias que importan en Dart y Provider

**Una referencia débil no define un cierre determinista.** Dart permite
`WeakReference`, pero no garantiza cuándo, ni siquiera si, se limpiará una
referencia débil. Tampoco admite todos los tipos de objeto. `Finalizer` no
garantiza ejecutar su callback. Por ello, una adaptación de `.shared` no puede
prometer liberar recursos al instante ni sustituir un contrato explícito de
`dispose` al cerrar un ámbito.
[WeakReference](https://api.dart.dev/dart-core/WeakReference-class.html),
[Finalizer](https://api.dart.dev/dart-core/Finalizer-class.html).

**Provider expone un valor almacenado.** Su constructor crea, conserva y expone
un objeto; `create` se ejecuta de forma lazy en la primera lectura. Por tanto,
una política `unique` de nuestro resolver no haría que cada `context.read<T>()`
construyera otra instancia: los widgets leerían el valor ya expuesto por Provider.
[API oficial de Provider](https://pub.dev/documentation/provider/latest/provider/Provider-class.html).

**Ownership sigue siendo una decisión explícita del paquete.** Nuestro contrato
es liberar instancias propias y conservar las recibidas. Una caché débil o vaciar
una caché no bastan para cumplirlo; habrá que definir el responsable de cada
instancia y cuándo finaliza su uso. Esta es una inferencia de diseño, no una API
copiada de Swift Factory.

## Recomendación, todavía no aceptada

Adoptar la separación entre construcción, reutilización y contenedor. Para una
primera API de Flutter, evaluar dos políticas fáciles de explicar:

1. `unique`: cada resolución construye otra instancia.
2. `scoped` o `cached`: reutilizar dentro del ámbito que posee la dependencia.

Un ámbito raíz puede durar toda la aplicación; uno hijo, una pantalla o flujo.
Así se puede expresar duración de aplicación sin añadir necesariamente un
singleton global ajeno a los contenedores. Es una propuesta nuestra, no la
semántica oficial del singleton de Swift.

Dejar `shared` débil y `graph` como candidatos posteriores salvo un caso concreto
que los justifique. No copiar nombres que prometan una semántica distinta en
Dart. No decidir todavía si cached es el valor predeterminado, cómo se heredan
dependientes al sustituir algo en un hijo o quién posee instancias unique.

Antes de elegir sintaxis, validar con ejemplos: cliente HTTP global, controlador
por flujo, dos clientes del mismo tipo y una prueba que sustituye un repositorio.
Las propuestas de este informe no modifican las decisiones de `docs/design/discovery.md`.
