# Publicar runtime y generador con un example verificable

El usuario aceptó que la primera entrega incluya el paquete base y el generador
opcional, con Android, iOS, web, Windows, macOS y Linux como plataformas objetivo.
Solo se declarará soporte donde el comportamiento haya sido validado.

Habrá una aplicación `example` dentro del proyecto. Antes de declarar estable la
API, el ejemplo y las pruebas deberán demostrar adopción gradual con Provider,
notificaciones, ámbitos, sustituciones, limpieza, generación y retirada cambiando
solo la configuración, sin modificar negocio ni consumidores.

Runtime y generador conservarán mínimos de SDK separados, elegidos y comprobados
con la implementación. Se prioriza validar la experiencia completa frente a
publicar primero un runtime sin la generación que simplifica el registro.
