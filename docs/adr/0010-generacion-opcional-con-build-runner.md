# Generar listas opcionalmente desde declaraciones Factory anotadas

El usuario aceptó un generador opcional que reúne declaraciones `Factory<T>`
anotadas en archivos de configuración y produce listas por módulo para
`FactoryScope`. Se usará `dart run build_runner watch` durante el desarrollo;
la configuración manual seguirá disponible.

Se eligió anotar las declaraciones de composición frente a las clases de negocio
para conservar la retirada limitada a configuración. El generador emitirá
referencias a las declaraciones seleccionadas, sin ejecutar sus funciones de
construcción ni publicar automáticamente dependencias internas.

Esto elimina la enumeración manual por dependencia a cambio de mantener una
etapa de generación para quienes la utilicen. La selección explícita para Provider
y la creación lazy siguen vigentes.

El usuario confirmó que cada módulo agrupa declaraciones internas y expuestas,
indicando cuáles se publican a Provider. Así se pueden instalar dependencias
internas eager sin exponerlas ni mantener una segunda lista manual.

Los nombres de anotaciones, la agrupación entre archivos y los límites entre
paquetes siguen por concretar. Runtime y generador tendrán mínimos de SDK separados
y verificados, sin imponer automáticamente el mínimo del generador al uso manual.
