# Declarar limpieza en el registro y ejecutarla al cerrar el ámbito

El usuario confirmó declarar una función opcional de limpieza junto a la
construcción de cada dependencia propia, sin exigir interfaces de Factory en las
clases de la aplicación. Las instancias recibidas conservan su propietario externo.

Las instancias propias `unique` que requieren limpieza se conservarán y liberarán
al cerrar el ámbito. Se eligió este comportamiento frente a introducir liberación
individual anticipada desde la primera versión. Esto simplifica el contrato de
propiedad, pero puede acumular recursos en ámbitos largos; las dependencias de
vida corta deben resolverse dentro de ámbitos cortos.

El usuario confirmó cerrar dependientes antes de sus dependencias y ámbitos hijos
antes que el padre. Si un callback falla, se intentarán las demás limpiezas y se
comunicarán los errores al terminar.

Se admitirán callbacks que devuelvan Future y un cierre explícito que pueda
esperarse. Al desmontar un widget se iniciará el cierre, pero Flutter no esperará
su finalización. El modo automático deberá comunicar los errores y permitir
seguir el cierre pendiente; la forma de esa API aún debe concretarse.

La limpieza asíncrona no implica construcción asíncrona. Esta última sigue fuera
de los requisitos confirmados.
