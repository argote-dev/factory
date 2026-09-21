# Respetar la propiedad de instancias en ámbitos anidados

Factory administrará ámbitos globales y ámbitos por pantalla o flujo desde la
primera versión. Liberará únicamente las instancias que crea y administra; las
recibidas de la aplicación seguirán bajo responsabilidad de quien las entrega.

El usuario eligió esta regla frente a permitir transferir la propiedad de valores
recibidos y eligió ámbitos anidados frente a limitarse a uno global. Así se permite
adopción gradual sin duplicar la responsabilidad de liberación, y se ajusta la vida
de las dependencias a la del flujo que las necesita.

El orden de liberación y el cierre asíncrono se concretaron en ADR 0008. Las
sustituciones locales requieren elegir explícitamente los dependientes que se
reconstruyen, según ADR 0006. La sintaxis se revisará en el ejemplo completo de API.
