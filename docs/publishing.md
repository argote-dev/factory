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
version and that CI passes. Push package tags in dependency order:

```sh
git tag factory_core-v0.2.0
git push origin factory_core-v0.2.0

git tag factory_provider-v0.2.0
git push origin factory_provider-v0.2.0

git tag factory_generator-v0.2.0
git push origin factory_generator-v0.2.0
```

Each tag must point to the same verified release commit. Never reuse or move a
published tag; increment the package version and create a new tag instead.
