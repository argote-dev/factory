# Resolución de dependencias dentro de ChangeNotifier

Estado: entrevista cerrada. Q1–Q9 confirmadas; entendimiento conjunto aceptado.

## Intención

Facilitar que un `ChangeNotifier` obtenga las dependencias que necesita. La
entrevista partió de mixin o clase base; en Q6 se eligió clase base.

## Restricciones existentes

- [ADR 0001](../adr/0001-limitar-acoplamiento-a-configuracion.md) y el término
  «Retirada de Factory» en [CONTEXT.md](../../CONTEXT.md) exigen retirar Factory
  cambiando únicamente la configuración. Usar su API dentro de un notifier
  queda permitido por la excepción opcional confirmada en ADR 0012.
- [ADR 0003](../adr/0003-politica-explicita-ante-cambios.md) distingue reemplazar
  una dependencia de recibir sus notificaciones de estado; observar cambios es
  explícito.
- [ADR 0004](../adr/0004-propiedad-y-ambitos.md) y
  [ADR 0008](../adr/0008-limpieza-en-registro-y-cierre-de-ambito.md) asignan la
  limpieza al propietario de la instancia. Resolver una dependencia no basta
  para transferir su propiedad al notifier.

## Ronda 1: confirmada

1. **Acoplamiento:** ¿se acepta una integración opcional que acople los notifiers
   que la adopten a Factory, se conserva la retirada exclusivamente desde
   configuración, o se cambia el contrato general?
   **Confirmado:** integración opcional y excepción documentada en
   [ADR 0012](../adr/0012-resolucion-opcional-en-notifiers.md).
2. **Comportamiento:** ¿solo resolución, también reacción a reemplazos, o además
   escucha de cambios de estado?
   **Confirmado:** solo resolución explícita, sin reacción automática a reemplazos
   ni escucha de cambios de estado.

## Ronda 2: confirmada

3. **Identificación:** declaración `Factory<T>`, solo tipo `T`, o ambas.
   **Confirmado:** declaración `Factory<T>`, conservando la identidad del core.
4. **Procedencia:** resolver pasado por constructor o conexión automática al
   crear el notifier con Factory. **Confirmado:** constructor explícito.
5. **Disponibilidad:** inicialización y métodos posteriores, o solo
   inicialización. **Confirmado:** ambos mientras notifier y ámbito estén activos.

## Ronda 3: confirmada

6. **Forma pública:** clase base, mixin que permita conservar otra superclase,
   o ambos. **Confirmado:** clase base para reducir código al recibir el resolver
   por constructor y centralizar el control de vigencia del notifier.
7. **Lecturas repetidas:** respetar `scoped`/`unique` sin caché adicional o
   conservar automáticamente el primer resultado por notifier.
   **Confirmado:** respetar las políticas existentes; el consumidor puede guardar
   explícitamente una dependencia en un campo cuando lo necesite.

## Revisión del conjunto

**Q8 confirmada:** el usuario acepta el diseño conjunto, incluyendo `StateError`
al resolver después de `dispose` o del inicio del cierre del ámbito, y rechazar
lecturas que introduzcan ciclos después de la construcción. Q1–Q9 quedan
confirmadas en la [especificación consolidada](change-notifier-proposal.md).

## Exploración posterior: campos anotados

Antes de confirmar el conjunto, el usuario preguntó si podría declarar una
dependencia con `@Inject final repository: Repository;`. Es una consulta de
viabilidad, no una aceptación de generación de código ni de resolución por tipo.

En Dart, el tipo precede al nombre. Un campo `final Repository repository` debe
inicializarse en su declaración o construcción; para asignarlo posteriormente
se necesita `late final`. Una anotación propia solo aporta metadatos: habría que
añadir generación e invocar la inicialización producida. El generador actual
solo agrupa declaraciones de composición.

Alternativa compatible con la base propuesta, sin generación de código:

```dart
late final Repository repository = resolve(repositoryFactory);
```

Ese campo conserva explícitamente el primer resultado; `resolve` conserva su
contrato sin caché adicional.

**Q9 confirmada:** el usuario decidió dejar `@Inject` para otro alcance y
mantener `resolve(...)`. No se agrega generación de código para campos en esta
entrega. Q8 se confirmó después de esta decisión.

## Árbol de decisiones cerrado

- Acoplamiento opcional → clase base `FactoryChangeNotifier`.
- Resolución → `Factory<T>`, resolver por constructor y ámbito dueño.
- Duración → construcción y métodos; `scoped`/`unique`; guardas de vigencia.
- Reactividad → no incluida; se conservan las APIs explícitas existentes.
- Anotaciones → fuera de alcance.
- Contrato consolidado → Q8 aceptada; ADR, glosario y criterios registrados.

La [investigación técnica](../research/change-notifier-dependency-resolution.md)
registra hechos y alternativas. Retener el `FactoryRef` actual no tiene un
contrato público para acceso tardío; un resolver nuevo debe preservar también
el orden de limpieza de las dependencias adquiridas después de la construcción.
