# Diseño de Factory: entrevista en curso

## Intención confirmada

Crear un paquete Flutter de inyección de dependencias inspirado en Riverpod,
orientado a aplicaciones existentes y nuevas que usan Provider.

La filosofía solicitada es facilidad de uso, facilidad de retirada, modernidad
y una interfaz simple e intuitiva. Estas cualidades todavía necesitan criterios
observables; no constituyen decisiones sobre una API concreta.

## Estado inicial

La carpeta del proyecto estaba vacía al iniciar la investigación el 20 de
septiembre de 2026. No existe todavía una implementación que evaluar.

## Árbol de decisiones

Primera ronda, resuelta:

1. **Confirmado:** el problema principal de la primera versión es registrar y
   conectar dependencias. Esto no resuelve todavía cómo tratar dependencias que
   cambian ni exige implementar un sistema de estado reactivo.
   - Desbloquea: alcance de la primera versión, comportamiento de dependencias
     cambiantes y funcionalidades inspiradas en Riverpod.
2. **Confirmado:** retirar el paquete debe requerir cambios solo en la
   configuración de dependencias, conservando widgets y clases de negocio.
   - Desbloquea: API pública, acoplamiento de consumidores y clases de negocio,
     necesidad y forma de integración con Provider.
3. **Confirmado:** la prioridad para publicar la primera versión es la integración
   gradual con aplicaciones Provider existentes.
   - Desbloquea: ejemplos de aceptación, matriz de compatibilidad y prioridades
     de publicación y mantenimiento.

Segunda ronda, resuelta:

4. **Confirmado:** Factory debe resolver conexiones y orden a partir de las
   declaraciones de construcción. No basta con acortar la sintaxis de
   `MultiProvider`. El mecanismo concreto todavía está abierto.
5. **Confirmado:** la configuración real debe poder probarse sin montar un árbol
   de widgets, verificando conexiones y sustituciones. La API concreta sigue abierta.
6. **Confirmado:** ante dependencias cambiantes, permitir elegir explícitamente
   actualizar la instancia dependiente o recrearla al registrar su construcción.
   Quedan abiertos el mecanismo de detección, la propagación y el ciclo de vida.
7. **Confirmado:** distinguir instancias del mismo tipo en la configuración.
   Se propusieron identificadores tipados y paso por constructor; la forma concreta
   de la API aún debe diseñarse y evaluarse.

Resolver conexiones no
implica inferir parámetros de constructores ni usar reflexión o generación de
código; esos mecanismos no se han elegido.

Tercera ronda, resuelta:

8. **Confirmado:** reutilizar instancias existentes de Provider mediante enlaces
   explícitos en la configuración, sin exigir migrar primero sus registros a
   Factory. En pruebas se podrán suministrar directamente. La propiedad y las
   señales de cambio se resuelven por separado en Q9 y Q11.
9. **Confirmado:** Factory libera únicamente las instancias que crea y administra.
   Las instancias recibidas siguen siendo responsabilidad de quien las entrega.
10. **Confirmado:** soportar ámbitos globales y ámbitos anidados por pantalla o
    flujo desde la primera versión. Cerrar un ámbito debe liberar sus instancias
    propias sin liberar instancias recibidas ni las pertenecientes al ámbito padre.
11. **Confirmado:** distinguir reemplazos de instancia de notificaciones de estado.
    La escucha de estado debe activarse explícitamente; una notificación no
    propaga cambios por defecto. Ante un cambio observado se aplica la política
    de actualización o recreación elegida. La API de escucha sigue abierta.
12. **Corregido por el usuario:** se requiere creación lazy: registrar cómo
    construir la dependencia y crear su instancia al solicitarla por primera vez.
    La respuesta anterior se dio entendiendo lazy, no inicialización asíncrona.
    La coordinación asíncrona no es un requisito confirmado.

Corrección tras la cuarta ronda:

El usuario aclaró que quería creación lazy, no coordinación asíncrona. Las
preguntas sobre carga, reintentos y resultados asíncronos tardíos se derivaron de
un malentendido y se retiran de esta ronda. No se ha aceptado que Factory gestione
estados de UI. Reformular la conversación con ejemplos de construcción de objetos.

Cuarta ronda, reformulada y resuelta:

13. Retirada: presentación de carga/error.
14. Retirada: política de reintentos de inicialización asíncrona.
15. Retirada: cierre durante inicialización asíncrona.
16. **Confirmado:** indicar explícitamente qué dependientes reconstruir en el hijo
    cuando sustituye una dependencia. No reconstruir automáticamente todos los
    dependientes heredados ni modificar instancias del padre.
17. **Confirmado:** funciones de construcción explícitas y referencias tipadas,
    sin generación de código obligatoria. La sintaxis sigue abierta.
18. **Confirmado:** reutilización por ámbito como política predeterminada;
    creación `unique` solo cuando se configure explícitamente.

Reutilización, aclaración confirmada:

La reutilización debe depender de la configuración de cada dependencia, no de una
regla universal. El usuario propuso como ejemplo conceptual
`LazyInit(Clase, .singleton|.application|.shared|etc)`. Se confirma separar creación
lazy de reutilización; la sintaxis y las diferencias entre esas etiquetas no están
acordadas. No inferir que pasar un tipo permita invocar su constructor automáticamente.

El usuario pidió investigar `hmlongco/Factory` (Swift) antes de elegir estos nombres
y comportamientos. Los hallazgos están en `docs/research/swift-factory.md`;
las características de esa biblioteca no se adoptan automáticamente.

**Confirmado después de la investigación:** comenzar con `unique` (instancia por
resolución) y reutilización por ámbito. Un ámbito raíz cubre la aplicación y los
hijos cubren pantallas o flujos. `shared` débil y `graph` quedan para evaluación
posterior; no se necesita inicialmente un singleton global externo a los ámbitos.
El nombre `scoped` o `cached` y la sintaxis de declaración todavía están abiertos.
La política predeterminada y la forma general de declaración se resolvieron en
Q18 y Q17. Ver ADR 0006 y ADR 0007.

Quinta ronda, resuelta:

19. **Confirmado:** lazy por defecto y opción explícita de creación inmediata al
    abrir el ámbito.
20. **Confirmado:** función opcional de limpieza en el registro de objetos propios,
    sin exigir interfaces de Factory en sus clases.
21. **Confirmado:** conservar las instancias `unique` propias que requieren
    limpieza y liberarlas al cerrar su ámbito, sin liberación individual anticipada
    inicialmente. Un ámbito largo puede acumular esas instancias; para vidas cortas
    se usarán ámbitos cortos.

API, primera revisión:

22. **Confirmado:** usar argumentos nombrados para configurar la declaración,
    en lugar de modificadores encadenados. El usuario eligió `Factory<T>` como
    nombre público en lugar del `Dependency<T>` provisional.
    `docs/design/api-draft.md` refleja esta elección; el resto de sus nombres
    y la integración todavía se están diseñando.

Integración con Provider, confirmada:

23. **Confirmado:** `FactoryScope` como ámbito adaptador para conectar las
    declaraciones con Provider, alrededor de la aplicación o de un flujo.
24. **Confirmado:** exponer solo las dependencias elegidas, sin publicar
    automáticamente todas las transitivas.

El usuario pidió investigar anotaciones para evitar enumerar manualmente cada
provider en el scope y aceptó generación opcional tras la investigación (Q25).
Se conserva la selección explícita y el contrato de retirada. No se ha aceptado
anotar clases de negocio ni hacer obligatoria la generación.
Hallazgos en `docs/research/annotation-registration.md`.

25. **Confirmado:** adoptar un generador opcional que lea anotaciones en declaraciones
    `Factory<T>` de la configuración y produzca listas por módulo, conservando
    instalación manual. El usuario acepta trabajar con `build_runner watch`.
    El nombre y los parámetros exactos de `@Expose(scope: 'app')` siguen siendo
    una propuesta de sintaxis.

Ronda de cierre: Q26–Q32 aceptadas; ver `docs/design/closure.md`. Se confirmaron
adaptación automática de ChangeNotifier, fallo de recreación sin entregar instancia
anterior, módulos con internos/expuestos, orden de limpieza, continuidad ante fallos,
cierre asíncrono esperable y mínimos de SDK separados.

Q33–Q35 aceptadas: todas las plataformas Flutter como objetivo con validación,
runtime y generador en la primera entrega y aplicación `example` dentro del
proyecto, con pruebas de los contratos antes de declarar estable la API.

El diseño acordado se consolida en `specification.md`. Los ejemplos completos de
API en `usage-proposal.md` concretan propuestas de sintaxis y detalles operativos para
revisión; no son una implementación ni evidencia de compatibilidad ya verificada.

Revisión conjunta pendiente: aceptar o ajustar la propuesta de uso integrada,
incluidos módulos, enlaces externos, observación/cierre y las reglas operativas
marcadas explícitamente como propuestas. `api-draft.md` conserva ejemplos iniciales.

## Documentación durante la entrevista

Las investigaciones están en `docs/research/provider-di.md` y
`docs/research/swift-factory.md`. Sus propuestas solo son decisiones cuando el
usuario las acepta y se registran como tales aquí o en `docs/adr/`.
`CONTEXT.md` mantiene el glosario acordado.
