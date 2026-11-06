import 'story_runtime_capability.dart';

/// Stable category for one target-runtime compatibility problem.
enum StoryRuntimeCompatibilityIssueCode {
  missingFeature,
  featureRevisionBelowMinimum,
  featureRevisionAboveMaximum,
  missingExtension,
  extensionVersionBelowMinimum,
  extensionVersionAboveMaximum,
}

/// One deterministic diagnostic produced by capability negotiation.
final class StoryRuntimeCompatibilityIssue {
  const StoryRuntimeCompatibilityIssue({
    required this.code,
    required this.subject,
    required this.message,
    this.minimumRequired,
    this.maximumAllowed,
    this.actual,
  });

  final StoryRuntimeCompatibilityIssueCode code;
  final String subject;
  final String message;

  /// Required inclusive lower bound when the issue is version/revision based.
  final int? minimumRequired;

  /// Required inclusive upper bound when the profile declares one.
  final int? maximumAllowed;

  /// Runtime-reported revision/version, or null when the capability is missing.
  final int? actual;
}

/// Compatibility result for one project capability profile against one runtime.
final class StoryRuntimeCompatibilityReport {
  StoryRuntimeCompatibilityReport({
    required this.profileId,
    required this.profileVersion,
    required this.runtimeId,
    required this.runtimeVersion,
    Iterable<StoryRuntimeCompatibilityIssue> issues = const [],
  }) : issues = List<StoryRuntimeCompatibilityIssue>.unmodifiable(issues);

  final String profileId;
  final int profileVersion;
  final String runtimeId;
  final String runtimeVersion;
  final List<StoryRuntimeCompatibilityIssue> issues;

  /// True only when every required feature and extension version is supported.
  bool get isCompatible => issues.isEmpty;

  /// Compact deterministic developer-facing rendering of [issues].
  String format() {
    if (issues.isEmpty) {
      return '$profileId@$profileVersion is compatible with '
          '$runtimeId@$runtimeVersion.';
    }
    return issues
        .map(
          (issue) => '${issue.code.name}: ${issue.subject}: ${issue.message}',
        )
        .join('\n');
  }
}

/// Raised when a caller requires compatibility but the target runtime cannot comply.
final class StoryRuntimeCompatibilityException implements Exception {
  const StoryRuntimeCompatibilityException(this.report);

  final StoryRuntimeCompatibilityReport report;

  @override
  String toString() => 'StoryRuntimeCompatibilityException: ${report.format()}';
}

/// Deterministic evaluator for project requirements versus reported capabilities.
abstract final class StoryRuntimeCompatibilityEvaluator {
  /// Evaluates [profile] without modifying either side or inventing fallback behavior.
  static StoryRuntimeCompatibilityReport evaluate({
    required StoryRuntimeCapabilityProfile profile,
    required StoryRuntimeCapabilities capabilities,
  }) {
    final features = <StoryRuntimeFeatureId, StoryRuntimeFeatureCapability>{
      for (final feature in capabilities.features) feature.featureId: feature,
    };
    final extensions = <String, StoryRuntimeExtensionCapability>{
      for (final extension in capabilities.extensions)
        extension.namespace: extension,
    };
    final issues = <StoryRuntimeCompatibilityIssue>[];

    for (final requirement in profile.requiredFeatures) {
      final capability = features[requirement.featureId];
      if (capability == null) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code: StoryRuntimeCompatibilityIssueCode.missingFeature,
            subject: requirement.featureId.value,
            message: 'Required runtime feature is not reported.',
            minimumRequired: requirement.minimumRevision,
            maximumAllowed: requirement.maximumRevision,
          ),
        );
        continue;
      }
      if (capability.revision < requirement.minimumRevision) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code:
                StoryRuntimeCompatibilityIssueCode.featureRevisionBelowMinimum,
            subject: requirement.featureId.value,
            message:
                'Runtime revision ${capability.revision} is below required '
                'minimum ${requirement.minimumRevision}.',
            minimumRequired: requirement.minimumRevision,
            maximumAllowed: requirement.maximumRevision,
            actual: capability.revision,
          ),
        );
        continue;
      }
      final maximum = requirement.maximumRevision;
      if (maximum != null && capability.revision > maximum) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code:
                StoryRuntimeCompatibilityIssueCode.featureRevisionAboveMaximum,
            subject: requirement.featureId.value,
            message:
                'Runtime revision ${capability.revision} is above allowed '
                'maximum $maximum.',
            minimumRequired: requirement.minimumRevision,
            maximumAllowed: maximum,
            actual: capability.revision,
          ),
        );
      }
    }

    for (final requirement in profile.requiredExtensions) {
      final capability = extensions[requirement.namespace];
      if (capability == null) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code: StoryRuntimeCompatibilityIssueCode.missingExtension,
            subject: requirement.namespace,
            message: 'Required extension namespace is not reported.',
            minimumRequired: requirement.minimumSchemaVersion,
            maximumAllowed: requirement.maximumSchemaVersion,
          ),
        );
        continue;
      }
      if (capability.schemaVersion < requirement.minimumSchemaVersion) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code:
                StoryRuntimeCompatibilityIssueCode.extensionVersionBelowMinimum,
            subject: requirement.namespace,
            message:
                'Runtime schema version ${capability.schemaVersion} is '
                'below required minimum ${requirement.minimumSchemaVersion}.',
            minimumRequired: requirement.minimumSchemaVersion,
            maximumAllowed: requirement.maximumSchemaVersion,
            actual: capability.schemaVersion,
          ),
        );
        continue;
      }
      final maximum = requirement.maximumSchemaVersion;
      if (maximum != null && capability.schemaVersion > maximum) {
        issues.add(
          StoryRuntimeCompatibilityIssue(
            code:
                StoryRuntimeCompatibilityIssueCode.extensionVersionAboveMaximum,
            subject: requirement.namespace,
            message:
                'Runtime schema version ${capability.schemaVersion} is '
                'above allowed maximum $maximum.',
            minimumRequired: requirement.minimumSchemaVersion,
            maximumAllowed: maximum,
            actual: capability.schemaVersion,
          ),
        );
      }
    }

    return StoryRuntimeCompatibilityReport(
      profileId: profile.profileId,
      profileVersion: profile.profileVersion,
      runtimeId: capabilities.runtimeId,
      runtimeVersion: capabilities.runtimeVersion,
      issues: issues,
    );
  }

  /// Returns normally only for a compatible target; otherwise throws the report.
  static void requireCompatible({
    required StoryRuntimeCapabilityProfile profile,
    required StoryRuntimeCapabilities capabilities,
  }) {
    final report = evaluate(profile: profile, capabilities: capabilities);
    if (!report.isCompatible) {
      throw StoryRuntimeCompatibilityException(report);
    }
  }
}
