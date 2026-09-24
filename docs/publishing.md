# Publishing to pub.dev

Factory publishes three packages from this repository:

| Package | Directory | Release tag |
| --- | --- | --- |
| `factory_core` | `packages/factory_core` | `factory_core-v{{version}}` |
| `factory_provider` | repository root | `factory_provider-v{{version}}` |
| `factory_generator` | `packages/factory_generator` | `factory_generator-v{{version}}` |

The versions move together. Publish in the table order because the Provider
adapter and generator depend on `factory_core`.

## First publication

Pub.dev requires the first version of each package to be published manually.
From a clean, verified commit, run:

```sh
(cd packages/factory_core && dart pub publish)
flutter pub publish
(cd packages/factory_generator && dart pub publish)
```

Wait for each dependency to become available on pub.dev before publishing the
next package. The local `pubspec_overrides.yaml` files are excluded from package
archives; pub may report an informational override hint during this bootstrap.

The root `factory_provider` archive intentionally includes the nested package
sources. A root `.pubignore` rule for `packages/` is also inherited when running
`dart pub publish` from those nested package directories, which would make
`factory_core` and `factory_generator` unpublishable. The small duplication keeps
all three package publication commands consistent in this monorepo layout.

## Enable GitHub Actions

After the first version exists, open the package's **Admin** tab on pub.dev and
enable automated publishing with:

- repository: `argote-dev/factory`
- the package-specific tag pattern from the table above
- required GitHub Actions environment: `pub.dev`

Create the `pub.dev` environment in the GitHub repository and protect it with a
required reviewer. The committed publish workflows use GitHub OIDC, so no
long-lived pub.dev credential belongs in repository secrets.

## Subsequent releases

Before tagging, verify that all three manifests and changelogs contain the same
version and that CI passes. The first automated version must be newer than the
manually published bootstrap version; after publishing `0.2.0` manually, for
example, push the `0.3.0` package tags in dependency order:

```sh
git tag factory_core-v0.3.0
git push origin factory_core-v0.3.0

git tag factory_provider-v0.3.0
git push origin factory_provider-v0.3.0

git tag factory_generator-v0.3.0
git push origin factory_generator-v0.3.0
```

Each tag must point to the same verified release commit. Never reuse or move a
published tag; increment the package version and create a new tag instead.

## Candidate acceptance without publication

Prepare an isolated Python environment and run the hosted-artifact checks:

```sh
python3 -m venv /tmp/factory-verification
/tmp/factory-verification/bin/pip install -r tool/requirements.txt
/tmp/factory-verification/bin/python tool/verify_release.py --output build/acceptance/current
```

The verifier checks coordinated versions/changelogs/core constraints, then uses
Pub's `publish --skip-validation --to-archive` to create the exact Pub file set.
It validates the extracted contents with `pub publish --dry-run` separately,
installs the archives via a read-only loopback package server, and runs public
consumers with an independent cache and no overrides. Skipping validation during
archive creation does not skip the subsequent mandatory dry-run. `--to-archive`
is a hidden Pub option; its implementation is in
[Pub's publishing command](https://github.com/dart-lang/pub/blob/master/lib/src/command/lish.dart).
The server follows the [hosted repository protocol](https://github.com/dart-lang/pub/blob/master/doc/repository-spec-v2.md).
It accepts no upload requests. This is not pub.dev publication.

Use the same archives under the other SDKs (put that SDK first on PATH):

```sh
python tool/verify_release.py --archives build/acceptance/current/archives --runtime-only --lower-dependencies --output build/acceptance/runtime-minimum
python tool/verify_release.py --archives build/acceptance/current/archives --generator-only --output build/acceptance/generator-minimum
```

The runtime job uses Flutter 3.19.0 / Dart 3.3.0 and installs no generator;
`--lower-dependencies` fixes Provider to its declared lower bound 6.1.5+1.
The generator job uses Dart 3.11.0 without Flutter and regenerates frozen output
previously verified with the 0.3 generator. Historical Flutter output regenerates
in the compatible current Flutter job; see the explicit combinations in support.md. Current CI pins Flutter
3.47.2 / Dart 3.13.2. Each output includes logs, resolved package versions,
archive SHA-256 hashes, commit, SDK versions and expected failures. A dirty
worktree run is diagnostic, not the final acceptance of a commit.

The current run deliberately removes an interface member from an implementer,
breaks immediate closure rejection in a disposable cache, and omits the core
entrypoint from a served archive. Each must fail for the expected reason;
restored consumers must pass. The checkout is never mutated by these probes.
CI uploads the reports even on failure. Do not publish, tag or close the parent
spec as part of candidate acceptance.
