# Cierre de los cinco contratos pendientes

Estado: Q26–Q35 aceptadas. Los cinco contratos tienen dirección acordada; resta
revisar la propuesta completa de API y validar los detalles técnicos al implementar.

La consolidación está en `specification.md`; el recorrido integrado para revisión
final está en `usage-proposal.md`. No se ha creado aún la aplicación `example`.

## 1. Integración con Provider

Acordado: FactoryScope, exposición explícita, importación explícita de instancias
existentes y liberación solo de instancias propias.

Confirmado: adaptar automáticamente notificaciones cuando el tipo declarado sea
`ChangeNotifier`, sin asumir doble propiedad. La importación de instancias tendrá
un ejemplo completo en el borrador; no se reabre su propiedad.

## 2. Sustituciones y cambios

Acordado: sustituciones locales, dependientes locales elegidos explícitamente,
escucha de estado optativa y política explícita actualizar/recrear.

Confirmado: si falla la recreación de un dependiente, comunicar el error y no
seguir entregando la instancia anterior. Falta concretar el ejemplo de API.
El fallo al actualizar in situ puede dejar mutaciones parciales; no prometer
rollback automático.

## 3. Generación por módulos

Acordado: anotaciones en composición, generación opcional, build_runner watch,
exposición explícita y alternativa manual.

Confirmado: separar instalación de exposición para permitir dependencias internas
eager. Un módulo generado contiene todas sus declaraciones marcadas y
la selección de cuáles se exponen a Provider; instalar el módulo una vez en un
ámbito. La etiqueta de módulo no crea instancias ni ámbitos de ejecución.

## 4. Limpieza

Acordado: callbacks en configuración; recursos propios unique conservados hasta
el cierre del ámbito; instancias prestadas conservan propietario externo.

Confirmado:

- Orden: dependientes antes que sus dependencias, hijos antes que padre.
- Fallos: intentar toda la limpieza y comunicar los errores al terminar.
- Asincronía: admitir callbacks Future y cierre explícito esperable; el desmontaje
  de widgets solo inicia el cierre. No habilita construcción asíncrona ni estados de UI.

## 5. Soporte inicial

Acordado: priorizar adopción gradual de apps Provider existentes y retirada
limitada a configuración; conservar uso sin generador.

Confirmado: mínimos de SDK separados y verificados para runtime y generador.
Confirmado: Android, iOS, web, Windows, macOS y Linux como objetivos, con soporte
declarado solo tras validación; runtime y generador opcional en la primera entrega;
aplicación `example` en el proyecto y pruebas como condición de API estable.
Los rangos concretos de SDK se validarán con la implementación.

Se consultan fuentes primarias para basar las decisiones de integración y soporte.

## Ronda de cierre 1: aceptada por el usuario

26. Adaptación automática de notificaciones para tipo declarado ChangeNotifier.
27. Error de recreación: comunicar fallo sin entregar la instancia anterior.
28. Módulo único con declaraciones internas y exposición seleccionada.
29. Limpiar dependientes antes que dependencias e hijos antes que padre.
30. Intentar todas las limpiezas y comunicar los errores al terminar.
31. Admitir cierre asíncrono explícito esperable; desmontar widgets lo inicia sin esperar.
32. Mínimos de SDK separados para runtime y generador, con matrices verificadas.

## Ronda de cierre 2: aceptada por el usuario

33. Todas las plataformas Flutter como objetivo; soporte condicionado a validación.
34. Runtime manual y generador opcional en la misma primera entrega.
35. Aplicación `example` dentro del proyecto y pruebas de adopción gradual,
    notificaciones, ámbitos, sustituciones, generación y retirada cambiando solo
    configuración, antes de declarar estable la API.

Hechos contrastados para esta ronda:

- `ChangeNotifierProvider.value` expone una instancia existente sin asumir su
  liberación. Factory conservaría la responsabilidad de sus instancias propias.
  [API Provider](https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html).
- El cierre de un widget usa `void dispose()`: no espera un Future.
  [State.dispose](https://api.flutter.dev/flutter/widgets/State/dispose.html).
- Se observaron build_runner 2.16.1 y source_gen 4.3.0 con requisito Dart `^3.11.0`.
  No son aún versiones fijadas para Factory.
  [build_runner](https://pub.dev/api/packages/build_runner),
  [source_gen](https://pub.dev/api/packages/source_gen).
