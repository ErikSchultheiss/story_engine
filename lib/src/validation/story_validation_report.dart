import '../identity/story_project_id.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Immutable, canonically ordered result of validating one authored project.
final class StoryValidationReport {
  factory StoryValidationReport({
    required StoryProjectId projectId,
    Iterable<StoryDiagnostic> diagnostics = const [],
  }) {
    final copied = List<StoryDiagnostic>.of(diagnostics);

    for (final diagnostic in copied) {
      if (diagnostic.location.projectId != projectId) {
        throw ArgumentError.value(
          diagnostic,
          'diagnostics',
          'Diagnostic location belongs to a different project.',
        );
      }
      for (final relatedLocation in diagnostic.relatedLocations) {
        if (relatedLocation.projectId != projectId) {
          throw ArgumentError.value(
            diagnostic,
            'diagnostics',
            'Related diagnostic location belongs to a different project.',
          );
        }
      }
    }

    final identities = <StoryDiagnosticIdentity>{};
    for (final diagnostic in copied) {
      if (!identities.add(diagnostic.identity)) {
        throw ArgumentError.value(
          diagnostic,
          'diagnostics',
          'A validation report cannot contain duplicate diagnostic identity.',
        );
      }
    }

    copied.sort(_compareDiagnostics);

    final ordered = List<StoryDiagnostic>.unmodifiable(copied);
    return StoryValidationReport._(
      projectId: projectId,
      diagnostics: ordered,
      errors: List<StoryDiagnostic>.unmodifiable(
        ordered.where(
          (diagnostic) =>
              diagnostic.severity == StoryDiagnosticSeverity.error,
        ),
      ),
      warnings: List<StoryDiagnostic>.unmodifiable(
        ordered.where(
          (diagnostic) =>
              diagnostic.severity == StoryDiagnosticSeverity.warning,
        ),
      ),
      information: List<StoryDiagnostic>.unmodifiable(
        ordered.where(
          (diagnostic) =>
              diagnostic.severity == StoryDiagnosticSeverity.information,
        ),
      ),
    );
  }

  StoryValidationReport._({
    required this.projectId,
    required this.diagnostics,
    required this.errors,
    required this.warnings,
    required this.information,
  });

  /// Project that was validated.
  final StoryProjectId projectId;

  /// All diagnostics in canonical deterministic order.
  final List<StoryDiagnostic> diagnostics;

  /// Error diagnostics in the same relative canonical order.
  final List<StoryDiagnostic> errors;

  /// Warning diagnostics in the same relative canonical order.
  final List<StoryDiagnostic> warnings;

  /// Information diagnostics in the same relative canonical order.
  final List<StoryDiagnostic> information;

  /// Whether validation found at least one definitely invalid condition.
  bool get hasErrors => errors.isNotEmpty;

  /// Whether validation found at least one warning.
  bool get hasWarnings => warnings.isNotEmpty;

  /// Whether validation found at least one informational finding.
  bool get hasInformation => information.isNotEmpty;

  /// Number of error diagnostics.
  int get errorCount => errors.length;

  /// Number of warning diagnostics.
  int get warningCount => warnings.length;

  /// Number of informational diagnostics.
  int get informationCount => information.length;

  /// Whether validation found no errors.
  ///
  /// Warnings and information do not make a project invalid.
  bool get isValid => !hasErrors;

  /// Concise deterministic count summary for logs and developer UIs.
  String get summary => '${_countLabel(errorCount, 'error')}, '
      '${_countLabel(warningCount, 'warning')}, '
      '${_countLabel(informationCount, 'information')}';

  /// Diagnostics matching one stable machine-readable [code].
  List<StoryDiagnostic> diagnosticsFor(StoryDiagnosticCode code) =>
      List<StoryDiagnostic>.unmodifiable(
        diagnostics.where((diagnostic) => diagnostic.code == code),
      );

  /// Multi-line developer rendering of this report.
  ///
  /// The first line is [summary], followed by one formatted diagnostic per
  /// line. Structured consumers should use [diagnostics] directly.
  String format({
    bool includeInformation = true,
    bool includeSuggestions = true,
  }) {
    final selected = includeInformation
        ? diagnostics
        : diagnostics
              .where(
                (diagnostic) =>
                    diagnostic.severity != StoryDiagnosticSeverity.information,
              )
              .toList(growable: false);
    if (selected.isEmpty) {
      return summary;
    }

    final buffer = StringBuffer(summary);
    for (final diagnostic in selected) {
      buffer
        ..writeln()
        ..write(
          diagnostic.format(includeSuggestion: includeSuggestions),
        );
    }
    return buffer.toString();
  }
}

String _countLabel(int count, String singular) {
  if (singular == 'information') {
    return '$count information';
  }
  return '$count $singular${count == 1 ? '' : 's'}';
}

int _compareDiagnostics(StoryDiagnostic left, StoryDiagnostic right) {
  var comparison = left.location.compareTo(right.location);
  if (comparison != 0) {
    return comparison;
  }

  comparison = left.code.compareTo(right.code);
  if (comparison != 0) {
    return comparison;
  }

  comparison = _compareReferenceLists(left.references, right.references);
  if (comparison != 0) {
    return comparison;
  }

  comparison = _compareLocationLists(
    left.relatedLocations,
    right.relatedLocations,
  );
  if (comparison != 0) {
    return comparison;
  }

  comparison = _severityPriority(left.severity).compareTo(
    _severityPriority(right.severity),
  );
  if (comparison != 0) {
    return comparison;
  }

  // Equal here means equal machine identity. StoryValidationReport rejects
  // duplicate identities, so human-readable message text is deliberately never
  // used as an ordering key.
  return 0;
}

int _compareReferenceLists(
  List<StoryDiagnosticReference> left,
  List<StoryDiagnosticReference> right,
) {
  final sharedLength = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < sharedLength; index++) {
    final comparison = left[index].compareTo(right[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return left.length.compareTo(right.length);
}

int _compareLocationLists(
  List<StoryDiagnosticLocation> left,
  List<StoryDiagnosticLocation> right,
) {
  final sharedLength = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < sharedLength; index++) {
    final comparison = left[index].compareTo(right[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return left.length.compareTo(right.length);
}

int _severityPriority(StoryDiagnosticSeverity severity) => switch (severity) {
  StoryDiagnosticSeverity.error => 0,
  StoryDiagnosticSeverity.warning => 1,
  StoryDiagnosticSeverity.information => 2,
};
