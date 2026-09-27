# Example runtime verification

The profile flow runs unchanged in widget tests and in `integration_test` on a
real browser, emulator, simulator or attached device. The integration entrypoint
uses the integration binding; the production entrypoints need no driver extension.
See the [Flutter integration guide](https://docs.flutter.dev/testing/integration-tests).

## Reproduce

Use a supported current Flutter SDK (the example requires Dart 3.11+), Python 3,
and the native platform toolchain. From the repository root:

```sh
(cd example && flutter pub get)
flutter devices
flutter emulators
```

For Chrome, install a ChromeDriver matching the installed Chrome version and
start `chromedriver --port=4444` in another terminal. For mobile, start an emulator
or simulator, or attach an unlocked device with development enabled. Select the
exact ID from `flutter devices`; never infer physical-device coverage from an
emulator or simulator result.

```sh
python3 tool/verify_example_runtime.py --device chrome --output build/runtime/chrome
python3 tool/verify_example_runtime.py --device emulator-5554 --output build/runtime/android
python3 tool/verify_example_runtime.py --device YOUR_IOS_DEVICE_ID --output build/runtime/ios
```

Each output directory must be new. The runner executes `flutter drive --debug`
with `example/test_driver/integration_test.dart` and
`example/integration_test/profile_flow_test.dart`. Chrome uses `-d web-server
--browser-name=chrome --no-headless`: ChromeDriver actually opens Chrome and runs
the tests; serving or compiling alone is not success. Native targets use their
device IDs. Run targets sequentially to avoid concurrent native build changes.

The evidence directory retains commit, working-tree status/diffs before and after
execution, SDK, device inventory, exact command, timestamps, exit code and output.
Use a committed checkout; untracked source is not captured by Git diffs. Review
the logs before sharing them. Preserve failures in separate directories and mark
unavailable platforms pending. A passing exit code and the structured report of
all three completed compositions in `run.log` are required. The runner rejects
zero-exit interruptions without that report. The fourth reported test is framework teardown.
This workflow is optional, not a mandatory CI gate.

## Observable contract

Each of manual Factory, generated Factory and Provider-only starts at Ada with
zero closed flows. It opens the child, loads **Grace Hopper profile**, returns to
Ada and observes exactly one additional closed flow. The same cycle runs twice,
ending at two closures, so reuse of the parent is exercised after child cleanup.

The closure counter is incremented by the owned `ProfileController.dispose`.
The test also checks that the original parent session and monitor retain identity,
accept listeners after each child closes, and that the parent repository still
loads Ada's profile through its live client. These observations complement the
existing unit ownership tests; they do not change ownership contracts or claim
heap/leak profiling. All three compositions assert the same visible results.

For a manual reproduction, run each entrypoint from the example README on the
selected target. Follow **Open profile → Load local profile → Back** twice and
check Grace in the child, Ada in the parent and closure counts 0 → 1 → 2. Use the
automated run for the additional borrowed-value assertions.

## Limits

Results apply only to the recorded commit, SDK, target and debug mode. The local
client intentionally performs no network I/O. Release builds, physical phones,
other OS/browser versions, background/restore and performance are separate checks.
Rollback consists of removing the integration entrypoint, shared test helper,
driver, evidence runner and its example development dependency, restoring the
standalone widget flow and reverting this documentation and example scaffold
adjustment; the runtime packages have no production changes.
