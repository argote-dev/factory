# Permitir resolución opcional dentro de notifiers

Para facilitar el acceso a dependencias dentro de un `ChangeNotifier`, se admite
una integración opcional que acople a Factory los notifiers que la adopten. El
usuario eligió esta excepción al [ADR 0001](0001-limitar-acoplamiento-a-configuracion.md)
frente a mantener su prohibición absoluta o cambiar el contrato general: la
inyección por constructor sigue disponible y conserva la retirada desde
configuración, mientras que retirar la nueva integración requiere adaptar sus
consumidores.

El alcance confirmado es solo resolución explícita, sin reacción automática a
reemplazos ni escucha de cambios de estado. Se eligió una clase base que recibe
un resolver por constructor, frente a un mixin que exigiría aportar ese miembro
en cada clase receptora. El acceso usa declaraciones `Factory<T>` y está
disponible al inicializar y desde métodos mientras notifier y ámbito estén
activos; esta opción ocupa la superclase del consumidor.

Q8 confirma `StateError` al resolver después de `dispose` o del inicio del cierre
del ámbito, y el rechazo de lecturas que introduzcan ciclos, incluidas las
realizadas después de la construcción. La limpieza conserva su propietario y
el orden dependientes antes de dependencias. Q9 mantiene `resolve(...)` y deja
`@Inject` y la generación de inicialización de campos para otro alcance.
