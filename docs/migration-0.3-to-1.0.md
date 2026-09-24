# Updating from 0.3 to the 1.0 candidate

The runtime surface and documented behavior are retained. Keep declarations,
constructor injection, Provider consumers, modules, overrides and disposal
callbacks unchanged. Update the package constraints together to the candidate
version; keep `factory_generator` a development dependency only if you use it.
There are no renamed policies, replacement adapters or business-code rewrites.

The baseline comes from [release v0.3.0](https://github.com/argote-dev/factory/releases/tag/v0.3.0),
commit `71fe8a4dd6a6d62cae4a072354c5852c89151ff2`. The immutable
[fixtures and hashes](../tool/consumer_contracts/historical/0.3.0/provenance.json)
contain Dart and Flutter consumers and the original generated module. Their
original path dependencies are resolution metadata: the verification harness
copies them outside the checkout and points package constraints at the hosted
test candidate. It never edits consumer Dart to obtain a passing result.

Run `python tool/verify_release.py` in the verification Python environment (see
[publishing](publishing.md)). It tests historical generated output before running
the candidate generator, compares regenerated output, and tests again. The frozen retrospective
`0.3.0-interfaces` consumer covers externally implemented interfaces against both
the actual released runtime and the candidate. The 0.3 release
itself did not ship that implementer fixture; it must not be presented as code
that existed in the release.

In 0.3, `FactoryRef.resolver` was added. An implementation written against the
older interface must implement that getter. This is a real pre-1.0 source break,
not a 1.x compatibility claim. The controlled regression probe verifies that an
incomplete external implementation fails compilation. During 1.x, adding such
a required member is prohibited by the [compatibility policy](compatibility-policy.md).

Candidate execution results belong in the acceptance report, identified by
commit and SDK. Creating this guide or a fixture does not itself prove that an
upgrade passed. After an actual 1.0 release, preserve its consumers as the first
1.x baseline rather than relabeling a candidate as a published release.
