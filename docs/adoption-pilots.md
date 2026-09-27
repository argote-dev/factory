# Evaluate adoption and removal in two Provider apps

Use this protocol for [issue #50](https://github.com/argote-dev/factory/issues/50).
Choose one bounded flow in each of two existing Provider apps, integrate Factory,
and then remove it into equivalent Provider composition. Record observed effort
and friction; there is no target duration or assumed ease of adoption.

**Status: preparation only.** Neither app nor its responsible owner has been
selected. No pilot timings or real-app results are available. The
[results template](adoption-pilot-results.md) must remain pending until both
pilots and the documentation reruns have evidence. The user selected the existing
example and a new local lab for technical rehearsals, recorded separately in the
results document; neither meets the existing-app selection criterion.
Do not close #50 with pilots
pending or substitute the repository example or packaged consumers for them.

## Agree on the two pilots

For each app, agree with its responsible owner on the flow, permitted repository
access, allowed edits and execution, test data, and what can be published. Opening
the issue does not authorize contacting third parties. Keep app identities,
access details, private paths, code, logs, and screenshots outside the public
report. Use aliases A and B and sanitized descriptions instead.

Record the initial Provider composition, Flutter/Dart/Provider versions, Factory
revision or version, participant experience, and existing checks. Select a
repeatable flow with a visible outcome and a clear exit. Capture its behavior
before editing, including ownership and cleanup. Preserve a baseline revision so
the final diff can establish which widgets and business classes stayed intact.

## Run the same bounded flow three times

1. **Baseline:** run the original Provider app and record the agreed checks.
2. **Connect:** follow [manual setup](../README.md#connect--manual-usage), moving
   construction into stable declarations and modules. Expose only the types
   consumed by widgets. Keep constructor-injected collaborators and ordinary
   Provider widget APIs. Run the same checks, including leaving the flow.
3. **Remove:** replace the selected Factory composition with Provider composition,
   following the [Provider-only example](../example/lib/main_provider.dart).
   Remove Factory imports and dependencies when no remaining flow needs them.
   Repeat the checks and compare with the baseline and connected revision.

Generation is optional. Use manual modules for the primary trial; record any
voluntary generator use separately. Isolate generator failures in independent
reproductions rather than making generation a prerequisite for adoption.

Use app tests and, where useful, an authorized device walkthrough with Maestro.
Record the command or interaction steps, expected result, observed result, and
evidence reference for each of the three states. A successful build alone does
not establish equivalent behavior or cleanup.

## Preserve the composition contract

Use this checklist to choose and verify the flow. Record an explicit reason for
anything the chosen flow does not exercise; do not report untested coverage.

| Concern | Factory integration | Equivalent Provider removal check |
| --- | --- | --- |
| Owned resources | Supply cleanup for constructed values, including notifiers. | Re-establish one owner with `create` and the appropriate cleanup; verify release on exit. |
| Borrowed resources | Use an external declaration and `overrideWithValue`; the original owner retains cleanup. | Retain the upstream owner; use `.value` when re-exposing its instance. Verify it survives child exit. |
| Exposure | Only module `expose` entries cross the Provider bridge. | Check that consumers still resolve the intended types; review any newly visible internal values. |
| Child scope | Inherited scoped values belong to their owning scope; `local` reconnects selected dependents. | Rebuild the corresponding dependents below local Provider replacements; verify the parent remains unchanged. |
| Overrides | Distinguish borrowed value overrides from owned constructor overrides and their cleanup. | Place replacements at the same flow boundary with equivalent ownership. |
| Observation | Record any `watch`/`select`, recreation, or in-place update used by the selected flow. | Preserve its update behavior explicitly, including identity where relied on; test a change, not just initial rendering. |

For asynchronous cleanup, record when it completes, not merely when the route
disappears. See [cleanup semantics](../README.md#test--cleanup-and-tests-without-widgets)
and the [async startup recipe](async-startup.md). Provider removal must retain
any explicit shutdown coordination the application needs.

Compare widgets and business classes against the baseline after both transitions.
Record the checked file set and diff result, including any unexpected changes.
Separate composition edits from business/widget edits even when they share a file.
Do not claim composition-only removal if a constructor-injected consumer changed.

Record `FactoryResolver` or `FactoryChangeNotifier` adoption separately. These
optional APIs couple consumers to Factory; removal requires constructor-injected
collaborators and, for the notifier base class, direct `ChangeNotifier` inheritance.
Their edits are an explicit exception, not evidence for composition-only removal.
Keep [ADR 0012](adr/0012-resolucion-opcional-en-notifiers.md) as historical context.

## Capture effort and friction as it happens

Start the integration clock when the participant begins the documented setup and
stop at the first successful execution of the agreed flow checks. Start the removal
clock when replacement work begins and stop when the equivalent Provider flow
passes those checks. Record elapsed time, active time if tracked, interruptions,
dependency downloads, and facilitator interventions separately. Do not estimate
missing measurements afterwards; mark them not recorded.

For each transition, record changed files and imports (sanitized for publication),
commands, instructions and versions consulted, questions, errors, help received,
and unresolved differences. Keep first-attempt timings distinct from later reruns.

## Improve instructions and repeat

Compare A and B for repeated confusion and retain case-specific problems too.
For each finding, link the observation to a concrete README, example, or recipe
change. Avoid changing APIs without a demonstrated need and separate design.
Repeat the affected connect/remove steps from a known baseline using the revised
instructions; record the documentation revision, assistance, and result. A rerun
by the same participant has learning effects and is not a new first-use measure.

Publish only the sanitized report agreed with the responsible owners. State
failures, uncovered cases, and the two-case limit explicitly. Neither two successful
pilots nor repository tests establish broader demand or ease of adoption.
