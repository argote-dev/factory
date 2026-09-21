# Empezar con instancias únicas y reutilización por ámbito

Tras investigar Swift Factory, el usuario aceptó comenzar con dos políticas
configurables por dependencia: `unique`, que crea una instancia por resolución,
y reutilización dentro del ámbito propietario. El ámbito raíz puede durar toda
la aplicación y los ámbitos hijos pueden corresponder a pantallas o flujos.

Esto permite expresar duración de aplicación sin necesitar inicialmente un
singleton global externo a los ámbitos. `shared` con referencias débiles y
`graph` se dejan para una evaluación posterior con casos concretos, priorizando
una interfaz sencilla y una liberación predecible de recursos propios.

La creación lazy es independiente de estas políticas. `unique` se refiere a una
resolución de Factory: no promete crear otro objeto en cada lectura de un valor
ya expuesto por Provider.

El usuario confirmó reutilizar por ámbito como política predeterminada; `unique`
debe elegirse explícitamente. Cuando un hijo sustituya una dependencia, se indicarán
explícitamente los dependientes que se deben reconstruir localmente, evitando
duplicar automáticamente servicios con estado heredados.

Las instancias `unique` propias que requieren limpieza se conservarán y liberarán
al cerrar su ámbito (ADR 0008). Quedan abiertos el nombre público `scoped` o
`cached` y la API concreta de declaración local.
