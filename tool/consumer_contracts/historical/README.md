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

After a real 1.0 release, archive its actual public consumers under `1.0.0/`,
record its immutable release commit and file hashes, and add that baseline to the
same harness. Do not label this unpublished candidate as a historical release.
