/// Pure-Dart engine for declarative interactive narratives and event systems.
///
/// Import this root library from consumer code:
///
/// ```dart
/// import 'package:story_engine/story_engine.dart';
/// ```
///
/// The public API covers authored projects/events/choices, typed scalar state,
/// conditions/effects/transitions, deterministic runtime traversal, host-driven
/// narrative sessions, serialized multi-session authority, suspendable host-action
/// protocol, modular/indexed loading, deterministic runtime-bundle build,
/// explicit content-version/save-migration contracts, runtime capability/extension
/// compatibility negotiation, stable presentation-unit identity, structured
/// non-authoritative runtime observations and causal explanations, static validation,
/// committed runtime snapshots, Story Format v1, and portable Extension Schema
/// v1 declarations.
///
/// Flutter, UI, filesystem/database policy, and other host concerns deliberately
/// remain outside the package.
///
/// `lib/src/` is implementation detail. The root barrel is symbol-pinned so
/// internal declarations cannot become supported consumer API accidentally.
/// Story Format v1 is a frozen compatibility contract independent from the
/// still-pre-1.0 Dart package API.
library;

export 'src/build/story_content_hash.dart' show StoryContentHash;
export 'src/build/story_runtime_bundle.dart' show StoryRuntimeBundle;
export 'src/build/story_runtime_bundle_builder.dart'
    show StoryRuntimeBundleBuilder, StoryRuntimeBundleBuildException;
export 'src/build/story_runtime_bundle_layout.dart'
    show StoryRuntimeBundleLayout;
export 'src/build/story_runtime_bundle_manifest.dart'
    show
        StoryRuntimeArtifactDescriptor,
        StoryRuntimeModuleArtifactDescriptor,
        StoryRuntimeBundleManifest;
export 'src/build/codec/story_runtime_bundle_manifest_codec.dart'
    show
        StoryRuntimeBundleManifestCodec,
        StoryRuntimeBundleManifestFormatException;
export 'src/content/codec/story_content_contract_codecs.dart'
    show
        StoryContentContractFormatException,
        StoryContentReleaseManifestCodec,
        StoryContentPatchManifestCodec,
        StorySaveContentBindingCodec,
        StoryContentMigrationPlanCodec;
export 'src/content/story_content_migration.dart'
    show
        StoryContentMigrationPlan,
        StorySaveCompatibilityStatus,
        StorySaveCompatibilityResult,
        StorySaveContentCompatibilityEvaluator,
        StoryContentMigrationException,
        StoryRuntimeSnapshotContentMigrator;
export 'src/content/story_content_patch.dart'
    show
        StoryContentPatchOperationKind,
        StoryContentPatchOperation,
        StoryContentPatchManifest,
        StoryContentPatchPlanner;
export 'src/content/story_content_release_manifest.dart'
    show
        StoryModuleRevisionReference,
        StoryContentModuleRevision,
        StoryContentReleaseManifest;
export 'src/content/story_save_content_binding.dart'
    show StorySaveContentBinding;
export 'src/capability/codec/story_runtime_capability_codecs.dart'
    show
        StoryRuntimeCapabilityFormatException,
        StoryRuntimeCapabilityProfileCodec,
        StoryRuntimeCapabilitiesCodec;
export 'src/capability/story_runtime_capability.dart'
    show
        StoryRuntimeFeatureId,
        StoryRuntimeFeatureRequirement,
        StoryExtensionSchemaRequirement,
        StoryRuntimeCapabilityProfile,
        StoryRuntimeFeatureCapability,
        StoryRuntimeExtensionCapability,
        StoryRuntimeCapabilities;
export 'src/capability/story_runtime_compatibility.dart'
    show
        StoryRuntimeCompatibilityIssueCode,
        StoryRuntimeCompatibilityIssue,
        StoryRuntimeCompatibilityReport,
        StoryRuntimeCompatibilityException,
        StoryRuntimeCompatibilityEvaluator;
export 'src/condition/story_condition.dart'
    show
        StoryCondition,
        StoryAllCondition,
        StoryAnyCondition,
        StoryNotCondition,
        StoryVariableIsSetCondition,
        StoryVariableIsUnsetCondition,
        StoryComparisonOperator,
        StoryVariableComparisonCondition;
export 'src/condition/story_condition_context.dart' show StoryConditionContext;
export 'src/condition/story_condition_evaluator.dart'
    show StoryConditionEvaluator, StoryConditionEvaluationException;
export 'src/effect/story_effect.dart'
    show
        StoryEffect,
        StorySetVariableEffect,
        StoryUnsetVariableEffect,
        StoryIncrementVariableEffect,
        StoryDecrementVariableEffect;
export 'src/explainability/story_condition_explanation.dart'
    show
        StoryConditionExplanationKind,
        StoryConditionExplanation,
        StoryAllConditionExplanation,
        StoryAnyConditionExplanation,
        StoryNotConditionExplanation,
        StoryVariableIsSetConditionExplanation,
        StoryVariableIsUnsetConditionExplanation,
        StoryVariableComparisonConditionExplanation;
export 'src/explainability/story_decision_explanation.dart'
    show
        StoryChoiceExplanation,
        StoryHostConditionExplanationStatus,
        StoryHostConditionExplanation,
        StoryEntryPointCandidateStatus,
        StoryEntryPointExplanation,
        StoryEntryPointSelectionMethod,
        StoryEntryPointFinalistExplanation,
        StoryEntryPointResolutionExplanation;
export 'src/explainability/story_effect_explanation.dart'
    show
        StoryEffectOperation,
        StoryEffectOutcome,
        StoryEffectOwnerKind,
        StoryEffectSource,
        StoryEffectExplanation;
export 'src/extension_schema/story_extension_schema.dart'
    show
        StoryExtensionSchema,
        StoryExtensionSchemaMetadata,
        StoryExtensionActionDefinition,
        StoryExtensionConditionDefinition,
        StoryExtensionEnumDefinition,
        StoryExtensionEnumValueDefinition,
        StoryExtensionReferenceTypeDefinition,
        StoryExtensionParameterTypeKind,
        StoryExtensionParameterType,
        StoryExtensionParameterDefinition;
export 'src/extension_schema/story_extension_schema_codec.dart'
    show StoryExtensionSchemaCodec, StoryExtensionSchemaFormatException;
export 'src/format/story_format_bundle.dart' show StoryFormatBundle;
export 'src/format/story_format_bundle_layout.dart'
    show StoryFormatBundleLayout;
export 'src/format/codec/story_format_codec.dart'
    show StoryFormatCodec, StoryFormatCodecException;
export 'src/format/story_format_compatibility.dart'
    show StoryFormatCompatibilityIssue, StoryFormatCompatibilityException;
export 'src/format/story_format_document.dart' show StoryFormatDocument;
export 'src/format/story_format_extension_attachment.dart'
    show StoryFormatExtensionAttachment;
export 'src/format/story_format_extension_namespace.dart'
    show StoryFormatExtensionNamespace;
export 'src/format/story_format_extension_payload.dart'
    show StoryFormatExtensionPayload;
export 'src/format/story_format_extension_target.dart'
    show
        StoryFormatExtensionTarget,
        StoryFormatProjectExtensionTarget,
        StoryFormatEventExtensionTarget,
        StoryFormatChoiceExtensionTarget,
        StoryFormatVariableExtensionTarget,
        StoryFormatGroupExtensionTarget,
        StoryFormatTagExtensionTarget;
export 'src/format/story_format_group.dart' show StoryFormatGroup;
export 'src/format/story_format_group_id.dart' show StoryFormatGroupId;
export 'src/format/story_format_metadata.dart' show StoryFormatMetadata;
export 'src/format/story_format_organization.dart' show StoryFormatOrganization;
export 'src/format/story_format_tag.dart' show StoryFormatTag;
export 'src/format/story_format_tag_id.dart' show StoryFormatTagId;
export 'src/host_action/story_host_action.dart'
    show
        StoryHostActionValueKind,
        StoryHostActionValueType,
        StoryHostActionRequest,
        StoryHostActionOutcome,
        StoryHostActionCompleted,
        StoryHostActionFailed,
        StoryHostActionCancelled;
export 'src/host_action/story_host_action_protocol.dart'
    show
        StoryHostActionProtocolStatus,
        StoryHostActionProtocolSnapshot,
        StoryHostActionProtocol,
        StoryHostActionProtocolException;
export 'src/host_action/story_host_action_protocol_snapshot_codec.dart'
    show
        StoryHostActionProtocolSnapshotCodec,
        StoryHostActionProtocolSnapshotFormatException;
export 'src/identity/story_alias.dart' show StoryAlias;
export 'src/identity/story_choice_id.dart' show StoryChoiceId;
export 'src/identity/story_content_release_id.dart' show StoryContentReleaseId;
export 'src/identity/story_entry_point_id.dart' show StoryEntryPointId;
export 'src/identity/story_event_id.dart' show StoryEventId;
export 'src/identity/story_host_action_request_id.dart'
    show StoryHostActionRequestId;
export 'src/identity/story_module_id.dart' show StoryModuleId;
export 'src/identity/story_module_version.dart' show StoryModuleVersion;
export 'src/identity/story_presentation_unit_id.dart'
    show StoryPresentationUnitId;
export 'src/identity/story_project_id.dart' show StoryProjectId;
export 'src/identity/story_variable_id.dart' show StoryVariableId;
export 'src/model/story_choice.dart' show StoryChoice;
export 'src/model/story_event.dart' show StoryEvent;
export 'src/model/story_project.dart' show StoryProject;
export 'src/modular/story_module_cache.dart' show StoryModuleCache;
export 'src/modular/story_module_loader.dart'
    show StoryModuleLoader, StoryModuleLoadException;
export 'src/modular/story_module_validator.dart'
    show
        StoryModuleValidationCode,
        StoryModuleValidationIssue,
        StoryModuleValidationReport,
        StoryModuleValidator;
export 'src/modular/story_narrative_module.dart' show StoryNarrativeModule;
export 'src/modular/story_project_index.dart'
    show StoryModuleIndexEntry, StoryEventIndexEntry, StoryProjectIndex;
export 'src/orchestration/story_entry_point.dart'
    show
        StoryHostConditionKey,
        StoryHostConditionRequirement,
        StoryHostContext,
        StoryEntryPoint;
export 'src/orchestration/story_narrative_input.dart'
    show
        StoryNarrativeInput,
        StoryNarrativeChoiceInput,
        StoryNarrativeContinueInput,
        StoryNarrativeHostActionCompletedInput,
        StoryNarrativeHostActionFailedInput,
        StoryNarrativeHostActionCancelledInput;
export 'src/observability/story_narrative_observer.dart'
    show
        StoryNarrativeDebugAdapter,
        StoryNarrativeObserver,
        StoryNarrativeObservation,
        StoryNarrativeSessionStarted,
        StoryNarrativeEventEntered,
        StoryNarrativeChoicePresented,
        StoryNarrativeChoiceSelected,
        StoryNarrativeHostActionRequested,
        StoryNarrativeHostActionResolution,
        StoryNarrativeHostActionCompleted,
        StoryNarrativeSessionEnded,
        StoryNarrativeErrorCategory,
        StoryNarrativeError;
export 'src/orchestration/story_narrative_runtime.dart'
    show
        StoryNarrativeRuntime,
        StoryNarrativeSessionStatus,
        StoryNarrativeSession,
        StoryNarrativeSessionHistory,
        StoryNarrativeRuntimeHistory,
        StoryNarrativeRuntimeException,
        StoryNarrativeConfigurationException,
        StoryNarrativeOperationException,
        StoryNarrativeResolutionException,
        StoryNarrativeExecutionException;
export 'src/orchestration/story_narrative_runtime_snapshot.dart'
    show
        StoryNarrativeRuntimeSnapshotMetadata,
        StoryNarrativeRuntimeSnapshot,
        StoryNarrativeSessionSnapshot;
export 'src/persistence/story_narrative_runtime_snapshot_codec.dart'
    show
        StoryNarrativeRuntimeSnapshotFormatException,
        StoryNarrativeRuntimeSnapshotCodec;
export 'src/orchestration/story_narrative_runtime_snapshot_validator.dart'
    show
        StoryNarrativeRuntimeSnapshotCompatibilityIssue,
        StoryNarrativeRuntimeSnapshotCompatibilityException,
        StoryNarrativeRuntimeSnapshotValidator;
export 'src/presentation/story_choice_presentation.dart'
    show StoryChoicePresentation;
export 'src/presentation/story_event_presentation.dart'
    show StoryEventPresentation;
export 'src/presentation/story_text.dart' show StoryText;
export 'src/presentation_identity/codec/story_presentation_identity_catalog_codec.dart'
    show
        StoryPresentationIdentityCatalogCodec,
        StoryPresentationIdentityFormatException;
export 'src/presentation_identity/story_presentation_identity.dart'
    show
        StoryPresentationUnitKind,
        StoryPresentationUnitLocation,
        StoryPresentationUnitRecord,
        StoryPresentationIdentityCatalog;
export 'src/persistence/story_runtime_snapshot_codec.dart'
    show StoryRuntimeSnapshotFormatException, StoryRuntimeSnapshotCodec;
export 'src/runtime/story_engine.dart'
    show
        StoryEngine,
        StoryEngineException,
        StoryEngineConfigurationException,
        StoryEngineOperationException,
        StoryEngineExecutionException;
export 'src/runtime/story_engine_status.dart' show StoryEngineStatus;
export 'src/runtime/story_runtime_history.dart'
    show
        StoryRuntimeStep,
        StoryEventEnteredStep,
        StoryEventContinuedStep,
        StoryChoiceSelectedStep,
        StoryRuntimeHistory;
export 'src/runtime/story_runtime_snapshot.dart'
    show
        StoryRuntimeSnapshotMetadata,
        StoryRuntimeRandomState,
        StoryRuntimeSnapshot;
export 'src/runtime/story_runtime_snapshot_validator.dart'
    show
        StoryRuntimeSnapshotCompatibilityIssue,
        StoryRuntimeSnapshotCompatibilityException,
        StoryRuntimeSnapshotValidator;
export 'src/state/story_state.dart' show StoryState;
export 'src/state/story_state_schema.dart' show StoryStateSchema;
export 'src/state/story_value.dart'
    show
        StoryValue,
        StoryBooleanValue,
        StoryIntegerValue,
        StoryNumberValue,
        StoryStringValue;
export 'src/state/story_value_type.dart' show StoryValueType;
export 'src/state/story_variable_definition.dart' show StoryVariableDefinition;
export 'src/transition/story_transition.dart'
    show
        StoryTransition,
        StoryEventTransition,
        StoryConditionalTransitionBranch,
        StoryConditionalTransition,
        StoryWeightedTransitionOption,
        StoryWeightedTransition,
        StoryTerminalTransition;
export 'src/validation/story_diagnostic.dart'
    show StoryDiagnosticIdentity, StoryDiagnostic;
export 'src/validation/story_diagnostic_code.dart' show StoryDiagnosticCode;
export 'src/validation/story_diagnostic_location.dart'
    show
        StoryDiagnosticLocationKind,
        StoryDiagnosticPathSegment,
        StoryDiagnosticFieldPathSegment,
        StoryDiagnosticIndexPathSegment,
        StoryDiagnosticLocation;
export 'src/validation/story_diagnostic_reference.dart'
    show StoryDiagnosticReferenceKind, StoryDiagnosticReference;
export 'src/validation/story_diagnostic_severity.dart'
    show StoryDiagnosticSeverity;
export 'src/validation/story_validation_report.dart' show StoryValidationReport;
export 'src/validation/story_validator.dart' show StoryValidator;

export 'src/explainability/story_runtime_execution_explanation.dart'
    show
        StoryRuntimeExecutionOutcome,
        StoryRuntimeEventFlow,
        StoryRuntimeExplanationStep,
        StoryEventAvailabilityExplanation,
        StoryEventTraversalExplanation,
        StoryRuntimeChoiceExplanation,
        StoryRuntimeEffectExplanation,
        StoryAutomaticTraversalExplanation,
        StoryTransitionBranchExplanation,
        StoryConditionalTransitionExplanation,
        StoryWeightedTransitionExplanation,
        StoryEventTransitionExplanation,
        StoryTerminalTransitionExplanation,
        StoryRuntimeExecutionExplanation,
        StoryPersistentVariableChange,
        StoryPersistentStateCommitExplanation;

export 'src/validation/story_project_analysis.dart'
    show
        StoryProjectAnalysis,
        StoryEventReference,
        StoryAnalysisFlowKind,
        StoryVariableUse,
        StoryVariableUseKind,
        StoryGraphAnalysis,
        StoryGraphCycle;
export 'src/validation/story_validation_context.dart'
    show StoryValidationContext, StoryValidationMode;
