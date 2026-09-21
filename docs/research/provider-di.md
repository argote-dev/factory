# Investigación: soporte para `factory` sobre Provider

Fecha: 20 de septiembre de 2026. Informe de hechos y alternativas; no decide
una API. Prioridades confirmadas: registrar/conectar dependencias automáticamente
en apps Provider existentes, probar el wiring fuera de widgets, y permitir retirar
`factory` cambiando sólo composición, nunca widgets ni clases de negocio.

## Fuentes consultadas

- [API de provider 6.1.5+1](https://pub.dev/documentation/provider/latest/provider/)
- [Repositorio oficial de provider](https://github.com/rrousselGit/provider)
- [Documentación oficial de Riverpod](https://riverpod.dev/docs/)
- [Flutter: gestión simple de estado](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [Dart: dependencias de paquetes](https://dart.dev/tools/pub/dependencies)
- [Dart: publicación de paquetes](https://dart.dev/tools/pub/publishing)

Las APIs pueden evolucionar; los hechos se limitan a las fuentes y fecha indicadas.

## Hechos verificados

Provider ofrece `Provider`, `ChangeNotifierProvider`, `FutureProvider`,
`StreamProvider` y `ProxyProvider`. `ChangeNotifierProvider` expone un
notificador a descendientes y reconstruye dependientes después de
`notifyListeners`. Flutter documenta que el valor creado con `create` se elimina
cuando deja de ser necesario. [Flutter](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
[API](https://pub.dev/documentation/provider/latest/provider/).

`BuildContext.read<T>()` obtiene sin suscripción; `watch<T>()` y `select<T,R>()`
registran dependencias de reconstrucción. La búsqueda es por el proveedor ancestro
más cercano del tipo solicitado. [API de las extensiones](https://pub.dev/documentation/provider/latest/provider/)
[README: lectura de valores](https://pub.dev/packages/provider#reading-a-value).
Dos implementaciones no se distinguen por una clave propia de DI en el consumo
normal: para un mismo tipo gana el ancestro más cercano. Desde Provider 6.0 la
nulabilidad tampoco las distingue. [changelog](https://pub.dev/packages/provider/changelog).

`ProxyProvider` crea o sincroniza un resultado desde otros providers. `update`
recibe el resultado anterior; existen `create`, `dispose` y `lazy`, y `update` es
obligatorio. [API de `ProxyProvider`](https://pub.dev/documentation/provider/latest/provider/ProxyProvider-class.html).
Esto permite reactividad de Provider, aunque hoy la composición vive en widgets.

En Provider, `create` es una fábrica y `dispose` es un callback de liberación.
[API de `Create`](https://pub.dev/documentation/provider/latest/provider/Create.html).
La guía oficial diferencia una instancia nueva (constructor normal) de una ya
existente (`.value`); reutilizar una existente con `create` puede hacer que se
elimine mientras sigue en uso. También confirma que `create` y `update` son
perezosos salvo `lazy: false`. [README oficial](https://github.com/rrousselGit/provider#exposing-a-value).
Por tanto, el adaptador no puede asumir que toda instancia que recibe pertenece
a `factory` ni disponer automáticamente un `ChangeNotifier` existente.

Riverpod guarda estado en `ProviderContainer`, integrado por `ProviderScope`, y
ofrece `read`, `listen`, dispose y `overrides`. [contenedores](https://riverpod.dev/docs/concepts2/containers)
[overrides](https://riverpod.dev/docs/concepts2/overrides). Para pruebas recomienda
un contenedor nuevo por caso mediante `ProviderContainer.test`, con disposición
automática y overrides para tests unitarios o widget. [testing](https://riverpod.dev/docs/how_to/testing).
Como antecedente histórico, la documentación de Riverpod 2 describe creación al
leer/escuchar/observar y `autoDispose`; no se debe usar esa página para prometer
semántica exacta de Riverpod 3.
[lifecycle de Riverpod 2](https://docs-v2.riverpod.dev/docs/concepts/provider_lifecycles).
Pero su propia documentación describe el scoping como complejo y potencialmente
replanteable. [scoping](https://riverpod.dev/docs/concepts2/scoping).

## Alternativas de alcance (propuestas, no decisiones)

| Alternativa | Resultado | Riesgo |
| --- | --- | --- |
| Registro y puente Provider | Registro de fábricas con resolución automática, orden, ownership y un puente que expone valores a Provider | Hay que definir materialización y lifecycle con precisión |
| Registro Dart con adaptador optativo | Resolver y probar grafo sin Flutter; publicar valores puntualmente con Provider | La reactividad queda en Provider/`ProxyProvider` |
| Contenedor reactivo propio | Scopes, invalidez, async y familias | Duplica Provider, hace la retirada más difícil y amplía mucho la superficie |

La primera es la hipótesis mejor alineada con las prioridades actuales, pero
la API y la organización interna siguen sin decidirse. Un wrapper que dependa
exclusivamente del árbol de widgets ya no satisface las decisiones confirmadas. El registro debe
resolver y ordenar dependencias; no basta un azúcar sintáctico sobre `MultiProvider`.

## Contratos candidatos

- Distinguir explícitamente fábricas **poseídas** de valores **prestados**. Sólo
  las poseídas se eliminan, una vez y en orden inverso a su creación.
- Mantener dominio, repositorios, servicios y widgets libres de imports,
  anotaciones o bases de `factory`. Retirarlo equivale a sustituir wiring.
- Resolver el grafo sin árbol de widgets para probar resolución, orden, ciclos,
  overrides y dispose sin `pumpWidget`. Separarlo en un paquete Dart sin Flutter
  sería una decisión adicional todavía no tomada.
- Hacer overrides visibles en el registro/scope de arranque o test, nunca un
  global mutable.
- Exigir clave/token al registrar varias implementaciones del mismo contrato, o
  limitar la exposición Provider a una por tipo y scope. No esconder la ambigüedad
  de lookup por tipo.
- En la primera versión, no crear otro sistema reactivo: los cambios dinámicos
  deben declarar una política explícita (estable; actualizar; recrear) y, cuando
  sea adecuado, delegar a `ProxyProvider`.

## Escenarios de aceptación

| Escenario | Resultado esperado |
| --- | --- |
| App existente | `Consumer`, `read`, `watch` y `select` siguen consumiendo el mismo contrato; ningún widget importa `factory`. |
| Grafo normal | Dependencias se resuelven automáticamente en orden válido, perezoso o eager según declaración. |
| Test Dart | Cada caso usa registro nuevo; reemplaza una dependencia y no comparte estado o recursos. |
| Notificador nuevo | `notifyListeners` conserva reconstrucciones y el valor se dispone sólo al cerrar su scope. |
| Valor existente | Es prestado por defecto y no se dispone al desmontar el puente. |
| Cambio dinámico | La política configurada actualiza o recrea de forma observable; no cambia silenciosamente una instancia estable. |
| Retirada | Se reemplaza el punto de composición por Providers normales; la UI y el negocio compilan sin cambios. |

## Soporte, pruebas y publicación

Declarar sólo rangos Dart/Flutter/Provider realmente probados. Dart recomienda
validar las dependencias mínimas con `dart pub downgrade`, `dart analyze` y
`dart test`. [dependencias](https://dart.dev/tools/pub/dependencies). La CI debe
cubrir pruebas Dart del contenedor y widget del puente, además de una app ejemplo
de adopción gradual. Flutter distingue pruebas unitarias, widget e integración
por confianza y coste. [testing de Flutter](https://docs.flutter.dev/testing/overview).

La documentación pública necesita incorporación, retirada, ownership, claves,
overrides, compatibilidad y errores de dependencia ausente/ciclo/duplicado. Pub
requiere `LICENSE` y usa `README.md`, `CHANGELOG.md` y `pubspec.yaml`; validar
con `dart pub publish --dry-run` y `dart doc`. [publicación](https://dart.dev/tools/pub/publishing)
[creación de packages](https://dart.dev/tools/pub/create-packages). El contrato
público debe seguir versionado semántico. [versionado](https://dart.dev/tools/pub/versioning).

## Preguntas abiertas

1. ¿Qué API de resolución independiente del árbol y qué puente con Provider
   satisfacen las pruebas sin widgets y la retirada limitada a configuración?
2. ¿Overrides locales sólo para test/arranque o también sesión/pantalla?
3. ¿Qué recursos puede poseer y eliminar `factory`? ¿Hace falta dispose asíncrono?
4. ¿Qué forma de clave mantiene simples las implementaciones múltiples?
5. Para dependencias dinámicas, ¿la política por defecto será estable, actualizar
   la misma instancia o recrearla? ¿Cómo se valida cada promesa?
