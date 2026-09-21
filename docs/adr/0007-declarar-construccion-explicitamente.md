# Declarar la construcción mediante funciones explícitas

El usuario eligió funciones de construcción explícitas y referencias tipadas entre
dependencias, sin generación de código obligatoria. Factory resolverá conexiones
y orden a partir de esas declaraciones; no se asume inferencia automática de
parámetros de constructores.

Esto mantiene la configuración visible y evita exigir una etapa de generación
para integrar el paquete. El usuario eligió `Factory<T>` como nombre público de
la declaración y argumentos nombrados para configurarla, frente a modificadores
encadenados. Los nombres de las opciones restantes y la posibilidad futura de
herramientas opcionales siguen abiertos.
