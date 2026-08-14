/// Pure-Dart engine for declarative interactive narratives and event systems.
///
/// Import this root library from consumer code:
///
/// ```dart
/// import 'package:story_engine/story_engine.dart';
/// ```
///
/// The public API covers authored projects/events/choices, typed scalar state,
/// conditions/effects/transitions, deterministic runtime traversal, static
/// validation, committed runtime snapshots, and Story Format v1. Flutter, UI,
/// filesystem/database policy, and other host concerns deliberately remain
/// outside the package.
///
/// `lib/src/` is implementation detail. The root barrel is symbol-pinned so
/// internal declarations cannot become supported consumer API accidentally.
/// Story Format v1 is a frozen compatibility contract independent from the
/// still-pre-1.0 Dart package API.
library;

export 'src/condition/story_condition.dart' show StoryCondition, StoryAllCondition, StoryAnyCondition, StoryNotCondition, StoryVariableIsSetCondition, StoryVariableIsUnsetCondition, StoryComparisonOperator, StoryVariableComparisonCondition;
export 'src/condition/story_condition_context.dart' show StoryConditionContext;
export 'src/condition/story_condition_evaluator.dart' show StoryConditionEvaluator, StoryConditionEvaluationException;
export 'src/effect/story_effect.dart' show StoryEffect, StorySetVariableEffect, StoryUnsetVariableEffect, StoryIncrementVariableEffect, StoryDecrementVariableEffect;
export 'src/format/story_format_bundle.dart' show StoryFormatBundle;
export 'src/format/story_format_bundle_layout.dart' show StoryFormatBundleLayout;
export 'src/format/codec/story_format_codec.dart' show StoryFormatCodec, StoryFormatCodecException;
export 'src/format/story_format_compatibility.dart' show StoryFormatCompatibilityIssue, StoryFormatCompatibilityException;
export 'src/format/story_format_document.dart' show StoryFormatDocument;
export 'src/format/story_format_extension_attachment.dart' show StoryFormatExtensionAttachment;
export 'src/format/story_format_extension_namespace.dart' show StoryFormatExtensionNamespace;
export 'src/format/story_format_extension_payload.dart' show StoryFormatExtensionPayload;
export 'src/format/story_format_extension_target.dart' show StoryFormatExtensionTarget, StoryFormatProjectExtensionTarget, StoryFormatEventExtensionTarget, StoryFormatChoiceExtensionTarget, StoryFormatVariableExtensionTarget, StoryFormatGroupExtensionTarget, StoryFormatTagExtensionTarget;
export 'src/format/story_format_group.dart' show StoryFormatGroup;
export 'src/format/story_format_group_id.dart' show StoryFormatGroupId;
export 'src/format/story_format_metadata.dart' show StoryFormatMetadata;
export 'src/format/story_format_organization.dart' show StoryFormatOrganization;
export 'src/format/story_format_tag.dart' show StoryFormatTag;
export 'src/format/story_format_tag_id.dart' show StoryFormatTagId;
export 'src/identity/story_alias.dart' show StoryAlias;
export 'src/identity/story_choice_id.dart' show StoryChoiceId;
export 'src/identity/story_event_id.dart' show StoryEventId;
export 'src/identity/story_project_id.dart' show StoryProjectId;
export 'src/identity/story_variable_id.dart' show StoryVariableId;
export 'src/model/story_choice.dart' show StoryChoice;
export 'src/model/story_event.dart' show StoryEvent;
export 'src/model/story_project.dart' show StoryProject;
export 'src/presentation/story_choice_presentation.dart' show StoryChoicePresentation;
export 'src/presentation/story_event_presentation.dart' show StoryEventPresentation;
export 'src/presentation/story_text.dart' show StoryText;
export 'src/persistence/story_runtime_snapshot_codec.dart' show StoryRuntimeSnapshotFormatException, StoryRuntimeSnapshotCodec;
export 'src/runtime/story_engine.dart' show StoryEngine, StoryEngineException, StoryEngineConfigurationException, StoryEngineOperationException, StoryEngineExecutionException;
export 'src/runtime/story_engine_status.dart' show StoryEngineStatus;
export 'src/runtime/story_runtime_history.dart' show StoryRuntimeStep, StoryEventEnteredStep, StoryEventContinuedStep, StoryChoiceSelectedStep, StoryRuntimeHistory;
export 'src/runtime/story_runtime_snapshot.dart' show StoryRuntimeSnapshotMetadata, StoryRuntimeRandomState, StoryRuntimeSnapshot;
export 'src/runtime/story_runtime_snapshot_validator.dart' show StoryRuntimeSnapshotCompatibilityIssue, StoryRuntimeSnapshotCompatibilityException, StoryRuntimeSnapshotValidator;
export 'src/state/story_state.dart' show StoryState;
export 'src/state/story_state_schema.dart' show StoryStateSchema;
export 'src/state/story_value.dart' show StoryValue, StoryBooleanValue, StoryIntegerValue, StoryNumberValue, StoryStringValue;
export 'src/state/story_value_type.dart' show StoryValueType;
export 'src/state/story_variable_definition.dart' show StoryVariableDefinition;
export 'src/transition/story_transition.dart' show StoryTransition, StoryEventTransition, StoryConditionalTransitionBranch, StoryConditionalTransition, StoryWeightedTransitionOption, StoryWeightedTransition, StoryTerminalTransition;
export 'src/validation/story_diagnostic.dart' show StoryDiagnosticIdentity, StoryDiagnostic;
export 'src/validation/story_diagnostic_code.dart' show StoryDiagnosticCode;
export 'src/validation/story_diagnostic_location.dart' show StoryDiagnosticLocationKind, StoryDiagnosticPathSegment, StoryDiagnosticFieldPathSegment, StoryDiagnosticIndexPathSegment, StoryDiagnosticLocation;
export 'src/validation/story_diagnostic_reference.dart' show StoryDiagnosticReferenceKind, StoryDiagnosticReference;
export 'src/validation/story_diagnostic_severity.dart' show StoryDiagnosticSeverity;
export 'src/validation/story_validation_report.dart' show StoryValidationReport;
export 'src/validation/story_validator.dart' show StoryValidator;
