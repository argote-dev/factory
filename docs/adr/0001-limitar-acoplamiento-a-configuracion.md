# Limitar el acoplamiento a la configuración de dependencias

Factory debe poder retirarse cambiando únicamente la configuración de
dependencias, sin modificar los widgets ni las clases de negocio de la aplicación.
El usuario eligió este contrato frente a permitir cambios en consumidores o
clases de negocio porque la facilidad de retirada es una prioridad del proyecto.

Esto limita las futuras APIs: los consumidores y las clases de negocio no pueden
necesitar APIs de Factory para funcionar. La forma concreta de cumplir este
contrato todavía está pendiente de diseño.
