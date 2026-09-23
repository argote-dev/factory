# Factory

Paquete de inyección de dependencias para aplicaciones Flutter que usan Provider.

## Lenguaje

**Declaración Factory**:
Definición tipada de cómo construir una dependencia y de sus opciones de creación,
reutilización y limpieza; se denomina `Factory<T>` y no es la instancia construida.
_Evitar_: Dependency como nombre público de esta declaración.

**Retirada de Factory**:
Eliminación de Factory de una aplicación modificando únicamente su configuración
de dependencias y conservando sus widgets y clases de negocio, siempre que estos
no hayan adoptado la resolución interna opcional.
_Evitar_: Migración de toda la aplicación.

**Resolución interna opcional**:
Obtención de dependencias desde un notifier mediante Factory, elegida
explícitamente por su autor; estos consumidores dependen de Factory y quedan
fuera de la garantía de retirada limitada a configuración.
_Evitar_: Inyección por constructor, acceso obligatorio para todos los notifiers.

**Instancia propia de Factory**:
Instancia creada y administrada por Factory, cuya liberación le corresponde.
_Evitar_: Toda instancia accesible desde Factory.

**Instancia recibida**:
Instancia entregada a Factory cuya liberación sigue siendo responsabilidad de
quien la entrega.
_Evitar_: Instancia adquirida por Factory.

**Ámbito de Factory**:
Contexto de dependencias correspondiente a toda la aplicación, una pantalla o
un flujo, que puede estar anidado dentro de otro ámbito.
_Evitar_: Contenedor global como sinónimo de cualquier ámbito.

**Creación lazy en Factory**:
Creación de una instancia al solicitar su dependencia por primera vez; registrar
la dependencia solo declara cómo construirla.
_Evitar_: Registro diferido, inicialización asíncrona como sinónimos de lazy.

**Dependencia unique**:
Dependencia para la que cada resolución de Factory produce una instancia nueva.
_Evitar_: Nueva instancia por cada lectura de Provider.

**Dependencia reutilizada por ámbito**:
Dependencia cuya instancia se conserva y reutiliza dentro de su ámbito propietario;
el nombre público de esta política sigue pendiente.
_Evitar_: Singleton global, shared débil.

**Módulo de Factory**:
Agrupación de declaraciones de dependencias que distingue las internas de las
expuestas a Provider y se instala en un ámbito.
_Evitar_: Ámbito como sinónimo de módulo.

**Dependencia expuesta**:
Dependencia seleccionada para que los consumidores descendientes puedan obtenerla
mediante Provider.
_Evitar_: Toda dependencia resuelta por Factory.

**Dependencia interna**:
Dependencia disponible para la composición dentro de Factory que no se publica
a los consumidores de Provider.
_Evitar_: Dependencia no registrada.
