# Factory: especificación consolidada

Estado: contratos de producto acordados en Q1–Q35. La propuesta de sintaxis y
detalles operativos de `usage-proposal.md` requiere revisión conjunta antes de cerrar
la entrevista. No existe todavía implementación ni compatibilidad comprobada.

## Propósito y límites

Paquete Flutter de inyección de dependencias para aplicaciones nuevas o existentes
con Provider. Simplifica la declaración, conexión, creación y liberación de
servicios, repositorios y controladores. Se priorizan facilidad de uso y retirada,
modernidad y una interfaz pequeña.

Retirarlo debe requerir cambios solo en configuración. Las clases de negocio
reciben objetos por constructor y los widgets conservan sus consumidores Provider.
Factory no introduce un sistema de estado de UI. Se requiere creación lazy, no
coordinación de construcción asíncrona.

## Declaración y resolución

- La declaración pública es `Factory<T>`, con función de construcción explícita
  y opciones mediante argumentos nombrados.
- Las conexiones se expresan mediante referencias tipadas. Factory resuelve el
  orden; no se infieren constructores desde un objeto Type.
- Declaraciones diferentes pueden representar dependencias del mismo tipo.
- La configuración se puede resolver y probar sin montar widgets.
- El comportamiento predeterminado es creación lazy y reutilización por ámbito.
- `unique` produce otra instancia en cada resolución de Factory. Leer repetidamente
  un objeto ya expuesto por Provider no es resolver de nuevo su factory.
- Una opción explícita crea la dependencia al abrir su ámbito.
- `shared` débil y `graph` quedan fuera de la primera propuesta.

## Ámbitos, sustituciones y propiedad

Un ámbito raíz cubre la aplicación; los hijos cubren pantallas o flujos. Las
sustituciones de un hijo no modifican las instancias del padre. Los dependientes
que deban reconstruirse localmente se indican explícitamente.

Factory libera las instancias que crea y administra. Las recibidas mediante
enlaces explícitos siguen bajo responsabilidad de quien las entrega. Las
instancias propias `unique` con limpieza se conservan hasta cerrar su ámbito;
las vidas cortas requieren ámbitos cortos para evitar acumulación.

## Cambios de dependencias

Reemplazar una instancia y escuchar cambios de su estado son cosas distintas.
La escucha de estado requiere configuración explícita. Ante cambios observados,
la declaración elige conservar y actualizar su instancia o recrearla.

Si una recreación falla, se comunica el fallo y no se entrega la instancia anterior
como alternativa silenciosa. Esto no revoca referencias entregadas previamente ni
promete deshacer mutaciones realizadas por una actualización fallida.

## Integración con Provider

`FactoryScope` instala un ámbito alrededor de una aplicación o flujo. Se exponen
solo las dependencias elegidas, conservando `read`, `watch`, `select` y `Consumer`.
Si el tipo declarado es `ChangeNotifier`, sus notificaciones se adaptan
automáticamente sin trasladar a Provider la propiedad de instancias de Factory.

La instalación de declaraciones internas es independiente de su exposición. Una
dependencia interna puede crearse inmediatamente sin quedar visible a los widgets.

## Generación opcional

Las anotaciones viven sobre declaraciones Factory en archivos de configuración,
nunca son necesarias en clases de negocio. El generador reúne las declaraciones
por módulo y la selección de cuáles se exponen. La aplicación instala el módulo
una vez; no enumera manualmente cada provider.

El modo manual sigue disponible. Se usa `dart run build_runner watch` durante
el desarrollo con generación. La generación produce referencias, no crea servicios
ni evalúa las funciones de construcción. Agrupar un módulo no crea por sí solo
un ámbito de ejecución.

## Cierre y errores de limpieza

La función opcional de limpieza se declara en la configuración; no exige una
interfaz de Factory en las clases de la app. Se cierran ámbitos hijos antes del
padre y dependientes antes de sus dependencias. Se intentan todas las limpiezas
aunque alguna falle y los errores se comunican al terminar.

Se admiten callbacks síncronos y Future. El cierre explícito permite esperar su
finalización. Desmontar un widget inicia el cierre, sin que Flutter espere; los
errores de ese cierre también deben comunicarse. La API concreta debe hacer
observable el cierre pendiente sin convertirlo en estado de UI del paquete.

## Primera entrega y soporte

Runtime y generador opcional se entregan juntos. Sus mínimos de SDK se eligen y
prueban separadamente; el generador no eleva por sí mismo el mínimo del runtime.
Android, iOS, web, Windows, macOS y Linux son plataformas objetivo; no se declara
soporte sin validación. Las versiones precisas se fijarán con evidencia de pruebas.

La aplicación `example` forma parte del proyecto y de la validación de la API,
no es solo un fragmento en el README.

## Contrato del example

Propuesta de organización para implementar tras revisar la API:

```text
example/
  lib/
    domain/          # cliente, repositorio y contratos sin Factory
    presentation/    # controlador y widgets consumidores de Provider
    composition/     # declaraciones, anotaciones y módulos generados
    main.dart
  test/
  integration_test/  # recorridos que lo justifiquen
```

Escenario: una app con Provider recibe un servicio existente; Factory configura
un cliente HTTP y repositorio en la raíz y un ChangeNotifier en un flujo hijo.
El ejemplo debe poder ejecutarse con datos locales reproducibles, sin credenciales
ni servicios externos. Esta elección de datos es una propuesta de implementación.

## Evidencia requerida antes de declarar estable la API

| Recorrido | Resultado que debe demostrarse |
| --- | --- |
| Adopción gradual | Reutilizar una instancia existente sin apropiarse de su limpieza. |
| Creación | Lazy no crea antes de resolver; eager crea al abrir el ámbito. |
| Identidad | Reutilización por ámbito y unique funcionan sin colisionar factories del mismo tipo. |
| Notificaciones | Los consumidores Provider reaccionan a ChangeNotifier sin modificaciones. |
| Flujo hijo | Sustituciones locales y dependientes elegidos no alteran al padre. |
| Fallos | Una recreación fallida no entrega datos anteriores silenciosamente. |
| Limpieza | Orden correcto, callbacks una vez, limpieza restante aun con fallos y cierre esperable. |
| Generación | Módulo manual y generado tienen comportamiento equivalente; internos no se exponen. |
| Pruebas aisladas | Sustituciones sin widgets ni estado compartido entre casos. |
| Retirada | Sustituir solo composición por Provider conserva negocio, widgets y comportamiento. |
| Compatibilidad | Mínimos declarados y versiones admitidas pasan las verificaciones pertinentes. |

La ruta de retirada del example debe ser ejecutable, no solo descrita. Las pruebas
de generación también deben detectar salidas desactualizadas y metadatos inválidos.
Los diagnósticos concretos y su formato se revisarán con `usage-proposal.md`.

## Documentos relacionados

- `usage-proposal.md`: recorrido integrado y propuestas para revisión final.
- `api-draft.md`: ejemplos iniciales de la entrevista.
- `discovery.md`: respuestas y evolución del diseño.
- `closure.md`: decisiones de los cinco contratos finales.
- `../adr/`: razones y alternativas de las decisiones.
- `../research/`: evidencia externa, que no equivale por sí sola a una decisión.
