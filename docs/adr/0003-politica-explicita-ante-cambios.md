# Elegir explícitamente actualizar o recrear dependientes

Al registrar un dependiente, se podrá elegir conservar y actualizar su instancia
o recrearla cuando cambie una dependencia. El usuario eligió esta política frente
a recrear siempre o limitar la primera versión a dependencias estables.

La decisión permite conservar estado cuando corresponde y hace visible el costo
de recrear un controlador.

El usuario confirmó distinguir reemplazos de instancia de notificaciones de
estado. Escuchar estado requiere configuración explícita: una notificación no
debe provocar por defecto la actualización o recreación de dependientes.

Si falla una recreación tras cambiar una dependencia, se comunicará el fallo y no
se entregará la instancia anterior como alternativa silenciosa. El usuario eligió
este comportamiento para evitar, por ejemplo, servir datos de una sesión anterior.
Esto no permite retirar referencias que ya estén en manos de consumidores.

Todavía deben definirse la API de escucha, el orden de propagación y la liberación
de instancias reemplazadas. No se ha prometido rollback de actualizaciones in situ.
