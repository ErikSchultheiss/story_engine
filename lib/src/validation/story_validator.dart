import '../identity/story_event_id.dart';
import '../model/story_project.dart';
import 'story_diagnostic.dart';
import 'story_graph_validator.dart';
import 'story_presentation_validator.dart';
import 'story_reference_validator.dart';
import 'story_semantic_validator.dart';
import 'story_state_use_validator.dart';
import 'story_structural_validator.dart';
import 'story_validation_report.dart';
import 'story_validation_context.dart';
import 'story_project_analysis.dart';

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
  ///
  /// Stage 8G optionally accepts [additionalEntryEventIds] as extra graph roots
  /// for host-driven projects with multiple independent narrative activations.
  /// These roots affect graph reachability/cycle/termination analysis only;
  /// they do not mutate Story Format v1 or replace project structural checks.
  ///
  /// [context] defaults to standalone validation. Orchestration and module
  /// contexts relax the default-entry requirement, validate explicit context
  /// roots, and seed state-use analysis with possibly set/unset shared state.
  /// Module contexts accept explicitly known external event destinations;
  /// graph queries still treat missing local bodies as incomplete boundaries.
  static StoryValidationReport validate(
    StoryProject project, {
    Iterable<StoryEventId> additionalEntryEventIds = const [],
    StoryValidationContext context = const StoryValidationContext.standalone(),
  }) {
    final analysis = StoryProjectAnalysis.analyze(project);
    final diagnostics = <StoryDiagnostic>[
      ...const StoryStructuralValidator().validate(project, context: context),
      ...const StoryReferenceValidator().validate(
        project,
        analysis: analysis,
        knownExternalEventIds: context.knownExternalEventIds,
      ),
      ...const StorySemanticValidator().validate(project),
      ...const StoryStateUseValidator().validate(
        project,
        analysis: analysis,
        context: context,
      ),
      ...const StoryGraphValidator().validate(
        project,
        analysis: analysis,
        entryEventIds: {
          ...context.rootsFor(project),
          ...additionalEntryEventIds,
        },
      ),
      ...const StoryPresentationValidator().validate(project),
    ];
    return StoryValidationReport(
      projectId: project.id,
      diagnostics: diagnostics,
    );
  }
}
