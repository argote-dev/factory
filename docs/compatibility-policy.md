# Factory 1.x compatibility policy

This policy governs the 1.0 candidate and future 1.x releases. It does not claim
that 1.0 has been published. The [surface inventory](api-guide.md) identifies the
stable API, extension points and behavioral evidence.

During 1.x, public signatures and documented behavior remain compatible.
Breaking changes require the next major. In particular, adding a required
member to an implementable interface breaks implementers even if every existing
call still compiles. Consumer fixtures must cover both calls and implementations.

A deprecated API retains working behavior for at least one complete minor line
and cannot be removed before the next major. The release introducing a
`@Deprecated` annotation must include a replacement, a before/after migration
recipe in the changelog and API guide, and the earliest possible removal major.
For example, a deprecation in 1.2 must remain through 1.3 and cannot disappear
before 2.0. Security fixes do not silently redefine this compatibility promise.

## SDKs and package combinations

- Runtime: Dart >=3.3.0 and Flutter >=3.19.0 throughout 1.x. The core stays
  independent of Flutter. Neither runtime package depends on the generator.
- Generator: initially Dart >=3.11.0. A later minor may raise this minimum only
  after an advance notice in a **previous released minor's** generator changelog
  and support matrix. The notice names the new minimum and first affected minor.
  The earlier compatible generator remains an option with its supported runtime.
- Package release versions are coordinated across core, adapter and generator.
  The adapter and generator constrain core to the same compatible major/minor
  baseline. Publish core, adapter, then generator.
- The supported candidate combination uses all three coordinated versions.
  Manual consumers need only core or adapter. Historical generated 0.3 output is
  tested against the candidate runtime separately from regeneration using the
  candidate generator. No Cartesian product of every tool/runtime version is
  promised. New supported combinations require recorded consumer evidence.

The [support matrix](support.md) records actual SDK/dependency combinations;
SDK minimums, dependency minimums, consumer provenance and platform validation
are separate dimensions. A configured CI job alone proves none of them.

## Consumer and release gates

Run `./tool/verify_consumers.sh` for current external consumers. Package tests
remain the detailed behavioral evidence linked in the inventory. Historical
consumers must be preserved verbatim with their release/tag/commit provenance;
only their resolution environment changes when testing a candidate. Any required
0.3 migration belongs in a separate fixture, never in the historical baseline.
A real 1.0 release will establish the first immutable 1.x baseline.

Release acceptance additionally requires isolated installation of Pub artifacts,
minimum/current SDK runs, generation drift checks and controlled failing probes
for interface and packaging regressions. Record the candidate commit, commands,
SDKs and results; do not substitute a version label or ticket closure for evidence.
