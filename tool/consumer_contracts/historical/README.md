# Immutable historical consumers

`0.3.0/` contains verbatim files from the released `v0.3.0` commit recorded in
`provenance.json`, with SHA-256 hashes. Do not edit them to satisfy a candidate.
The harness copies them to an isolated directory and replaces only dependency
resolution metadata. Historical generated Dart is tested before regeneration;
the original files are never regenerated in place.

The release did not contain an external FactoryRef implementation. The frozen
`0.3.0-interfaces/` consumer is a retrospective compatibility probe, authored now
and executed against that release and the candidate. Its provenance states this
explicitly; it is not a file claimed to have existed in the release.
The pre-resolver interface shape is used only as a controlled 0.2→0.3 break probe,
not as a claim of a break within 1.x.

`1.0.0/` contains the actual Dart manual, Dart generated and Flutter consumers
from `v1.0.0` (`ccbcf3a4be58f89b4c898b52fbd4af3c380134b2`). Its provenance
records every original file and SHA-256. The manual Dart consumer already
implements `FactoryRef`, `FactoryResolver` and `FactoryVisitor`; these are
original release fixtures, not retrospective probes. The verifier checks the
complete file set and compares each file against Git and its recorded hash.

`1.0.0/published_archives.json` separately pins the three **published** pub.dev
archives, with URLs, publication timestamps, package tags, release commit and
SHA-256. These are not archives rebuilt from Git or produced by candidate CI.
`--published-baseline` downloads them into `published-archives/` and checks their
hashes, including when reusing a previous download. A mismatch is a failure;
never update a pin merely to make verification pass.

Run the published baseline, then the candidate, from the repository root:

```sh
python tool/verify_release.py --published-baseline --output build/acceptance/published-1.0.0
python tool/verify_release.py --output build/acceptance/current
```

Install `tool/requirements.txt` first and use the current CI SDK (Flutter 3.47.2 /
Dart 3.13.2). Both runs use isolated hosted caches, without local overrides, and
modify only resolution metadata in disposable copies. Frozen generated output
is analyzed and tested before regeneration, then compared byte-for-byte and
tested again. Candidate runtime-minimum and generator-minimum modes also include
the 1.0 consumers appropriate to those SDKs; the 0.3 baseline remains separate.
Keep both output directories: `evidence.json` records provenance, hashes, SDKs,
commands, exact dependency resolutions and results; numbered logs and downloaded
archives accompany it. CI uploads the two evidence bundles separately even on
failure. No claim of a tested future candidate is made until its own run passes.

When adding a later baseline, copy from its real release commit, record original
file hashes, and obtain the published archive hashes independently from pub.dev.
Put any newly authored retrospective probes in a separate directory with explicit
provenance. Never edit a frozen consumer to accommodate a candidate. The separate
[scheduled dependency canary](../../../docs/dependency-canary.md) reuses these
fixtures with published 1.x dependencies; its results are informational.

`0.3.0-generated/` is a retrospective pure-Dart consumer whose frozen module is
verified by regenerating with the actual 0.3 release generator, then with the
candidate on both Dart 3.11 and the current SDK. Its provenance distinguishes it
from the Flutter module actually present in the release. This avoids pretending
Flutter 3.41's meta pin is compatible with the generator's analyzer dependency.
