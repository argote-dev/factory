# Probar la configuración de dependencias sin widgets

El usuario requiere probar las conexiones y sustituciones de la configuración
real sin montar un árbol de widgets. Factory deberá ofrecer resolución usable
sin un `BuildContext`, además de su integración con Provider.

Una abstracción que solo acorte `MultiProvider` no satisface este requisito ni
el objetivo confirmado de resolver conexiones y orden. Esto introduce la
responsabilidad de mantener coherencia entre la resolución y su exposición a
Provider. La API y la separación física en paquetes siguen abiertas.
