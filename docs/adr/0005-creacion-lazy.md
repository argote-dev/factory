# Crear dependencias al solicitarlas por primera vez

Factory permitirá registrar cómo construir una dependencia sin crear su instancia
en ese momento. La creación ocurrirá cuando se solicite por primera vez, resolviendo
las dependencias que necesite para construirse.

El usuario aclaró que este comportamiento lazy era lo que quería al responder Q12.
La interpretación anterior como requisito de inicialización asíncrona fue un
malentendido y queda corregida. No se exige coordinación asíncrona, reintentos ni
estados de carga a partir de aquella respuesta.

La reutilización se configurará por dependencia, independientemente de que su
creación sea lazy. El usuario propuso una forma ilustrativa como
`LazyInit(Clase, .singleton|.application|.shared|etc)`; los nombres y su semántica
no se adoptaron como conjunto. Posteriormente se aceptaron `unique` y reutilización
por ámbito (ADR 0006). El usuario confirmó lazy por defecto y una opción explícita
para crear la dependencia inmediatamente al abrir su ámbito.
