/// Selects a declaration for a generated module.
class Register {
  /// Creates metadata for a module and optional Provider exposure.
  const Register({required this.module, this.expose = false});

  /// The generated module name, such as `app` or `profile`.
  final String module;

  /// Whether Provider consumers can read this declaration's value.
  final bool expose;
}

/// Marks the composition entrypoint used by the optional generator.
class FactoryRegistry {
  /// Selects package-relative source globs to scan for registrations.
  const FactoryRegistry({this.include = const ['lib/**.dart']});

  /// The package-relative sources to aggregate.
  final List<String> include;
}
