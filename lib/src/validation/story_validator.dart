import '../model/story_project.dart';
import 'story_diagnostic.dart';
import 'story_graph_validator.dart';
import 'story_presentation_validator.dart';
import 'story_reference_validator.dart';
import 'story_semantic_validator.dart';
import 'story_state_use_validator.dart';
import 'story_structural_validator.dart';
import 'story_validation_report.dart';

/// Public, read-only validator for authored [StoryProject] data.
///
/// Validation is deliberately independent of `StoryEngine` execution and does
/// not mutate authored data or runtime state. Rule families are layered behind
/// this facade while preserving one stable validation entry point.
final class StoryValidator {
  const StoryValidator._();

  /// Inspects [project] and returns structured deterministic diagnostics.
  ///
  /// Stage 3B installs structural/identity validation, Stage 3C adds full
  /// authored-tree reference validation, Stage 3D adds schema-dependent
  /// type/semantic checks, Stage 3E adds conservative initialization/state-use
  /// analysis, Stage 3F adds conservative authored graph/reachability checks,
  /// and Stage 3G adds non-blocking presentation/authoring-quality diagnostics.
  /// Stages 3H-3J harden this same API with malformed generation, scale
  /// pressure, and architecture-review contracts rather than new rule families.
  static StoryValidationReport validate(StoryProject project) {
    final diagnostics = <StoryDiagnostic>[
      ...const StoryStructuralValidator().validate(project),
      ...const StoryReferenceValidator().validate(project),
      ...const StorySemanticValidator().validate(project),
      ...const StoryStateUseValidator().validate(project),
      ...const StoryGraphValidator().validate(project),
      ...const StoryPresentationValidator().validate(project),
    ];
    return StoryValidationReport(
      projectId: project.id,
      diagnostics: diagnostics,
    );
  }
}
