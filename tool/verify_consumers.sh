#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir/tool/consumer_contracts/dart"
dart pub get
dart analyze
dart test

cd "$repo_dir/tool/consumer_contracts/flutter"
flutter pub get
dart run build_runner build
git diff --exit-code -- lib/registry.factory.dart
flutter analyze
flutter test
