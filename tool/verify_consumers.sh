#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
# Each consumer gets a clean temporary package configuration. Source paths are
# explicit here; isolated hosted-package verification lives in verify_release.py.
repo_path="$repo_dir"
if command -v cygpath >/dev/null 2>&1; then
  repo_path="$(cygpath -m "$repo_dir")"
fi
consumer_dir="$(mktemp -d)"
trap 'rm -rf "$consumer_dir"' EXIT

for kind in dart flutter dart_generated; do
  destination="$consumer_dir/$kind"
  mkdir -p "$destination"
  for part in lib bin test; do
    if [[ -d "$repo_dir/tool/consumer_contracts/$kind/$part" ]]; then
      cp -R "$repo_dir/tool/consumer_contracts/$kind/$part" "$destination/"
    fi
  done
  cp "$repo_dir/tool/consumer_contracts/$kind/pubspec.yaml" "$destination/"
  # Paths in these controlled fixture manifests are relative to the checkout.
  cd "$destination"
  REPO_DIR="$repo_path" python3 - <<'PY'
import os
from pathlib import Path
path = Path('pubspec.yaml')
path.write_text(path.read_text().replace('path: ../../..', 'path: ' + os.environ['REPO_DIR']))
PY
  cat > "$destination/pubspec_overrides.yaml" <<YAML
dependency_overrides:
  factory_core:
    path: $repo_path/packages/factory_core
YAML
  cd "$destination"
  command=dart
  [[ "$kind" == flutter ]] && command=flutter
  "$command" pub get
  "$command" analyze
  "$command" test
  if [[ "$kind" != dart ]]; then
    dart run build_runner build
    diff -u "$repo_dir/tool/consumer_contracts/$kind/lib/registry.factory.dart" lib/registry.factory.dart
    "$command" test
  fi
done
