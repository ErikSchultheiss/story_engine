/// Severity assigned to a validation diagnostic.
///
/// Errors identify definitely invalid authored data. Warnings identify
/// potential or path-dependent problems. Information diagnostics are
/// non-blocking authoring/maintainability observations.
enum StoryDiagnosticSeverity {
  /// Definitely invalid authored data.
  error,

  /// A likely or path-dependent problem that is not proven invalid.
  warning,

  /// A non-blocking authoring or maintainability observation.
  information,
}
