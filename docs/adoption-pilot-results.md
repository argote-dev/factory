# Provider adoption pilot results

**Pending — no real-app pilots have been executed.** This is the report template
for [issue #50](https://github.com/argote-dev/factory/issues/50), using the
[pilot protocol](adoption-pilots.md). Empty measurements mean not recorded, not
zero. Do not infer adoption effort from the repository example. The user requested
the example and a newly created lab as technical rehearsals; their evidence below
does not replace the two existing-app pilots.

## Technical rehearsals — 2026-09-27

Both rehearsals used Flutter 3.47.2, Dart 3.13.2, Provider 6.1.5+1 and the local
Factory 1.0.0 checkout at `30536bd`. The operator was a coding agent with source
access, not an independent adopting developer. No generator was required for the
lab. Verification used widget tests, not Maestro or a physical device.

| Rehearsal | Execution and result | Limits |
| --- | --- | --- |
| Repository example | `cd example && flutter test test/example_flow_test.dart`: 3 passed, covering manual Factory, annotated Factory and Provider-only profile flows. | Already-wired variants; no first-integration or removal timing was measured and no new migration was performed. |
| New cart lab | `flutter analyze` and `flutter test`: no analysis issues and 1 test passed at each of baseline, connected and removed states. Two visits each checked local product, quantity updates/reset, unchanged parent catalog, and one cart/client cleanup per exit. | Newly created synthetic app, synchronous cleanup, no real network or independent adopter. |

The separate local `factory-lab` repository preserves these branches and commits:

| State | Branch | Commit |
| --- | --- | --- |
| Original Provider composition | `provider-baseline` | `cb4d2d0` |
| Manual Factory composition | `factory-connected` | `e03e349` |
| Provider composition restored | `provider-removed` | `1e2cf3d` |

These are local evidence references, not downloadable public artifacts. The lab
was created at the user's requested location and remains on `provider-removed`.
Switch to a recorded branch, run `flutter pub get`, then `flutter analyze` and
`flutter test` to repeat. The connected branch needs the sibling Factory checkout.

Integration changed only `lib/composition.dart`, `pubspec.yaml`, and
`pubspec.lock`, adding one `factory_provider` import. Removal reversed these
changes and removed the Factory package dependencies and import. At both
transitions, `git diff --exit-code provider-baseline -- lib/domain.dart
lib/pages.dart lib/main.dart test/cart_flow_test.dart` was empty. Constructor
injection and Provider widget APIs stayed unchanged; no optional resolver or
notifier base class was used.

The lab borrowed the root catalog and audit object, exposed only the cart from
its child Factory module, locally installed the client with `local`, and
overrode the child catalog. The cart and client had explicit cleanup callbacks.
Borrowed objects had no disposable resources, so their survival was exercised
but original-owner disposal was not. Reactive dependency replacement, async
cleanup, and internal-type inaccessibility were not tested in this lab.

Observed wall-clock intervals (UTC) were **19.4 seconds** for integration
(20:35:41.497–20:36:00.879) and **6.7 seconds** for removal
(20:36:00.938–20:36:07.638). Integration ended when the agent collected the passing
test result; removal ended after the passing test command. These intervals include
command overhead, dependency resolution and analysis, and exclude lab creation,
prior documentation/source reading, and planning. Active time was not tracked.
Removal used `git restore --source=provider-baseline` for the three composition
and package files; it was a rollback rehearsal, not a fresh Provider rewrite.
These automated intervals are not estimates of human adoption or removal effort.

Instructions used: the current manual setup, replacement and removal README
sections, example compositions, and this draft protocol. No human assistance was
needed beyond the user's selection of the two rehearsals. No repeated adoption
friction was established, so no pilot-derived documentation improvement or
validated documentation rerun is claimed. The glossary correction and protocol
remain preparation based on the issue and source contracts.

## Selection and baseline

| Field | App A | App B |
| --- | --- | --- |
| Selection and owner agreement status | Pending | Pending |
| Sanitized app context and bounded flow | Pending | Pending |
| Authorized access, edits, execution and publication confirmed | Pending | Pending |
| SDK, Provider, Factory and baseline revisions | Pending | Pending |
| Participant experience with Provider and Factory | Pending | Pending |
| Initial composition, ownership and expected behavior | Pending | Pending |
| Baseline checks and sanitized evidence | Pending | Pending |

Store identifying details and private evidence with the responsible owners.
Publish only sanitized references and the agreed context here.

## Integration and removal observations

| Observation | App A | App B |
| --- | --- | --- |
| Time to first functional integration; elapsed/active time | Not recorded | Not recorded |
| Time to equivalent Provider removal; elapsed/active time | Not recorded | Not recorded |
| Interruptions, downloads and assistance | Not recorded | Not recorded |
| Instructions consulted and their revisions | Not recorded | Not recorded |
| Changed files/imports for each transition | Not recorded | Not recorded |
| Widget/business file set and baseline diff for each transition | Not recorded | Not recorded |
| Optional resolver/notifier coupling and separate removal edits | Not assessed | Not assessed |
| Optional generation used and separate findings | Not assessed | Not assessed |
| Questions, failures and unresolved differences | Not recorded | Not recorded |

## Behavioral evidence

For each app and each row, record the baseline, connected and removed results,
commands or interaction steps, and sanitized evidence. Use “not exercised” with
a reason for uncovered cases.

| Check | App A: baseline / connected / removed | App B: baseline / connected / removed |
| --- | --- | --- |
| Agreed visible flow outcome | Pending | Pending |
| Owned resource cleanup, including completion | Pending | Pending |
| Borrowed values survive child exit; original owner cleans up | Pending | Pending |
| Exposure and consumer resolution | Pending | Pending |
| Child replacement, local dependents and unchanged parent | Pending | Pending |
| Overrides and their owners | Pending | Pending |
| Observed updates and identity, where used | Pending | Pending |

## Findings, documentation changes and reruns

No pilot findings are available yet. Add one row per observed problem; distinguish
repeated problems from those seen in only one app.

| Observation and affected app(s) | Documentation change and revision | Repeat steps, assistance and result | Remaining limit |
| --- | --- | --- | --- |
| Pending | Pending | Pending | Pending |

Preparation corrected the active `Lifetime.scoped` glossary entry in
[CONTEXT.md](../CONTEXT.md) and added this protocol and README links. These changes
are based on the issue and current contracts, not observed pilot friction.
Historical ADRs remain unchanged.

## Completion and limits

- [ ] Two real apps selected with responsible-owner agreement.
- [ ] Baseline, connect and remove evidence recorded for each flow.
- [ ] Timings, assistance, file/import changes and questions recorded.
- [ ] Constructor-injected consumers verified unchanged; optional coupling separated.
- [ ] Coverage and any omissions explained.
- [ ] Observed documentation improvements validated by repeating the affected steps.
- [ ] Sanitized publication agreed with owners; results and limitations recorded.

Issue #50 remains pending. No conclusion about real-app adoption effort, broader
demand, or ease of use is supported yet. Even after completion, conclusions must
remain limited to these two apps, participants and flows.
