#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
flutter_override="$repo_dir/tool/consumer_contracts/flutter/pubspec_overrides.yaml"

cleanup() {
  rm -f "$flutter_override"
}
trap cleanup EXIT

cd "$repo_dir/tool/consumer_contracts/dart"
dart pub get
dart analyze
dart test

cd "$repo_dir/tool/consumer_contracts/flutter"
printf '%s\n' \
  'dependency_overrides:' \
  '  factory_core:' \
  '    path: ../../../packages/factory_core' > "$flutter_override"
flutter pub get
dart run build_runner build
git diff --exit-code -- lib/registry.factory.dart
flutter analyze
flutter test
