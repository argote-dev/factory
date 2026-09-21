# Conectar Factory con Provider mediante un ámbito y exposición explícita

El usuario aceptó un `FactoryScope` que conecta declaraciones Factory con Provider
alrededor de una aplicación o flujo. Solo se expondrán las dependencias elegidas;
resolver una dependencia interna no la publica automáticamente en el árbol.

Esto conserva los consumidores existentes y controla las colisiones entre tipos
expuestos. Se eligió este punto de integración frente a conectar individualmente
cada factory dentro de un `MultiProvider`.

El usuario aceptó generación opcional para evitar mantener la lista de exposición
a mano (ADR 0010). La selección explícita se expresa mediante metadatos; no exige
una lista escrita manualmente. La sintaxis exacta sigue abierta.

Cuando el tipo declarado sea `ChangeNotifier`, la exposición adaptará sus
notificaciones automáticamente, conservando el consumo existente con Provider.
La adaptación no cambia la propiedad: Factory libera sus instancias propias,
y las recibidas siguen perteneciendo a quien las entrega.
