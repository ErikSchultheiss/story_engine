import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stable identity of one diagnostic occurrence.
///
/// Human-readable message text and severity are intentionally excluded. A
/// message may be reworded/localized and a problem may be reclassified without
/// changing the machine identity used by Studio/CLI integrations.
final class StoryDiagnosticIdentity {
  factory StoryDiagnosticIdentity({
    required StoryDiagnosticCode code,
    required StoryDiagnosticLocation location,
    Iterable<StoryDiagnosticReference> references = const [],
    Iterable<StoryDiagnosticLocation> relatedLocations = const [],
  }) {
    final orderedReferences = List<StoryDiagnosticReference>.of(references)
      ..sort();
    final orderedRelated = List<StoryDiagnosticLocation>.of(relatedLocations)
      ..sort();
    return StoryDiagnosticIdentity._(
      code: code,
      location: location,
      references: List<StoryDiagnosticReference>.unmodifiable(
        orderedReferences,
      ),
      relatedLocations: List<StoryDiagnosticLocation>.unmodifiable(
        orderedRelated,
      ),
    );
  }

  StoryDiagnosticIdentity._({
    required this.code,
    required this.location,
    required this.references,
    required this.relatedLocations,
  });

  /// Stable category of problem.
  final StoryDiagnosticCode code;

  /// Primary authored location of the problem.
  final StoryDiagnosticLocation location;

  /// Relevant entity IDs, including IDs that do not resolve to an entity.
  final List<StoryDiagnosticReference> references;

  /// Additional authored locations that participate in this problem.
  final List<StoryDiagnosticLocation> relatedLocations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticIdentity &&
          other.code == code &&
          other.location == location &&
          _orderedReferencesEqual(other.references, references) &&
          _orderedLocationsEqual(other.relatedLocations, relatedLocations);

  @override
  int get hashCode => Object.hash(
    StoryDiagnosticIdentity,
    code,
    location,
    Object.hashAll(references),
    Object.hashAll(relatedLocations),
  );

  @override
  String toString() =>
      'StoryDiagnosticIdentity($code @ $location, references: $references, '
      'related: $relatedLocations)';
}

/// One structured validation finding produced from authored project data.
final class StoryDiagnostic {
  factory StoryDiagnostic({
    required StoryDiagnosticCode code,
    required StoryDiagnosticSeverity severity,
    required String message,
    required StoryDiagnosticLocation location,
    Iterable<StoryDiagnosticReference> references = const [],
    Iterable<StoryDiagnosticLocation> relatedLocations = const [],
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'Diagnostic messages must not be empty.',
      );
    }

    final orderedReferences = List<StoryDiagnosticReference>.of(references)
      ..sort();
    final orderedRelated = List<StoryDiagnosticLocation>.of(relatedLocations)
      ..sort();

    return StoryDiagnostic._(
      code: code,
      severity: severity,
      message: message,
      location: location,
      references: List<StoryDiagnosticReference>.unmodifiable(
        orderedReferences,
      ),
      relatedLocations: List<StoryDiagnosticLocation>.unmodifiable(
        orderedRelated,
      ),
    );
  }

  StoryDiagnostic._({
    required this.code,
    required this.severity,
    required this.message,
    required this.location,
    required this.references,
    required this.relatedLocations,
  });

  /// Stable machine-readable problem code.
  final StoryDiagnosticCode code;

  /// Classification of the finding.
  final StoryDiagnosticSeverity severity;

  /// Concise human-readable explanation.
  ///
  /// Consumers must not use this text as machine identity.
  final String message;

  /// Primary authored location of the finding.
  final StoryDiagnosticLocation location;

  /// Relevant entity IDs, including unresolved/missing referenced IDs.
  final List<StoryDiagnosticReference> references;

  /// Other authored locations that help explain the finding.
  final List<StoryDiagnosticLocation> relatedLocations;

  /// Stable occurrence identity independent of [message] and [severity].
  StoryDiagnosticIdentity get identity => StoryDiagnosticIdentity(
    code: code,
    location: location,
    references: references,
    relatedLocations: relatedLocations,
  );


  /// Actionable engine-owned repair guidance when one is known.
  ///
  /// Suggestions are human-facing convenience text, not machine identity. They
  /// may be clarified or localized independently from [code]. Extension-owned
  /// diagnostic codes naturally return null until their host supplies its own
  /// guidance.
  String? get suggestion => _suggestionFor(code);

  /// Concise single-line developer rendering of this diagnostic.
  ///
  /// Tooling that needs stable identity or navigation must use the structured
  /// fields directly. This method exists for logs, CLIs, test output, and quick
  /// developer feedback without requiring every consumer to invent formatting.
  String format({bool includeSuggestion = true}) {
    final buffer = StringBuffer()
      ..write(severity.name.toUpperCase())
      ..write(' [')
      ..write(code.value)
      ..write('] ')
      ..write(location.displayString)
      ..write(': ')
      ..write(message);
    final suggestion = this.suggestion;
    if (includeSuggestion && suggestion != null) {
      buffer
        ..write(' Suggested fix: ')
        ..write(suggestion);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnostic &&
          other.code == code &&
          other.severity == severity &&
          other.message == message &&
          other.location == location &&
          _orderedReferencesEqual(other.references, references) &&
          _orderedLocationsEqual(other.relatedLocations, relatedLocations);

  @override
  int get hashCode => Object.hash(
    StoryDiagnostic,
    code,
    severity,
    message,
    location,
    Object.hashAll(references),
    Object.hashAll(relatedLocations),
  );

  @override
  String toString() =>
      'StoryDiagnostic(${severity.name}, $code, $location, $message)';
}

String? _suggestionFor(StoryDiagnosticCode code) {
  if (code == StoryDiagnosticCode.structureMissingEntryEvent) {
    return 'Set StoryProject.entryEventId to the ID of an authored event.';
  }
  if (code == StoryDiagnosticCode.structureEntryEventNotFound) {
    return 'Point entryEventId at an existing event, or add the referenced '
        'event.';
  }
  if (code == StoryDiagnosticCode.identityDuplicateEventId) {
    return 'Give every event a unique stable ID and update references to the '
        'renamed event.';
  }
  if (code == StoryDiagnosticCode.identityDuplicateChoiceId) {
    return 'Give every choice a unique stable ID across the project.';
  }
  if (code == StoryDiagnosticCode.structureChoiceMissingTransition) {
    return 'Add a terminal, event, conditional, or weighted transition to the '
        'choice.';
  }
  if (code == StoryDiagnosticCode.structureEventMissingFlow) {
    return 'Define exactly one event flow: choices, a continuation transition, '
        'or an automatic transition.';
  }
  if (code == StoryDiagnosticCode.structureEventAmbiguousFlow) {
    return 'Keep exactly one event flow mode and remove the competing flow '
        'definitions.';
  }
  if (code == StoryDiagnosticCode.referenceMissingTransitionDestination) {
    return 'Add the destination event or change the transition to an existing '
        'event ID.';
  }
  if (code == StoryDiagnosticCode.referenceUndeclaredConditionVariable ||
      code == StoryDiagnosticCode.referenceUndeclaredEffectVariable) {
    return 'Declare the referenced variable in StoryStateSchema or update the '
        'authored reference.';
  }
  if (code == StoryDiagnosticCode.typeConditionOperandMismatch) {
    return 'Use a comparison value with the same StoryValueType as the '
        'declared variable.';
  }
  if (code == StoryDiagnosticCode.typeConditionOperatorNotSupported) {
    return 'Use an operator supported by the variable type; ordering operators '
        'require integer or number values.';
  }
  if (code == StoryDiagnosticCode.typeEffectValueMismatch) {
    return 'Set the variable with a value matching its declared StoryValueType.';
  }
  if (code == StoryDiagnosticCode.typeNumericEffectTargetNotNumeric) {
    return 'Target an integer/number variable, or use a set/unset effect '
        'instead.';
  }
  if (code == StoryDiagnosticCode.typeNumericEffectAmountMismatch) {
    return 'Use an increment/decrement amount with the same numeric type as '
        'the target variable.';
  }
  if (code == StoryDiagnosticCode.stateReadMayBeUnset) {
    return 'Initialize or write the variable before this read, or guard the '
        'read with an explicit is-set/is-unset condition.';
  }
  if (code == StoryDiagnosticCode.stateNumericEffectTargetUnset) {
    return 'Initialize or set the numeric variable before applying this '
        'increment/decrement.';
  }
  if (code == StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset) {
    return 'Ensure every reachable path sets the numeric variable first, or '
        'guard the adjustment with an is-set condition.';
  }
  if (code == StoryDiagnosticCode.stateVariableNeverReferenced) {
    return 'Remove the unused declaration or reference it from authored logic.';
  }
  if (code == StoryDiagnosticCode.stateVariableWrittenNeverRead) {
    return 'Read the variable from a condition, or remove writes that have no '
        'observable effect.';
  }
  if (code == StoryDiagnosticCode.stateVariableReadWithoutInitialization) {
    return 'Provide an initial value or add an authored write before any '
        'reachable read.';
  }
  if (code == StoryDiagnosticCode.graphUnreachableEvent) {
    return 'Connect the event from reachable flow or remove it if it is no '
        'longer used.';
  }
  if (code == StoryDiagnosticCode.graphAutomaticCycle) {
    return 'Break the synchronous automatic cycle with a terminal, interactive, '
        'or continuation path.';
  }
  if (code == StoryDiagnosticCode.graphContinuationCycle) {
    return 'Add a route out of the continuation cycle if indefinite host-driven '
        'looping is not intentional.';
  }
  if (code == StoryDiagnosticCode.graphInteractiveCycle ||
      code == StoryDiagnosticCode.graphMixedCycle) {
    return 'Review the cycle and keep it only if repeated traversal is '
        'intentional.';
  }
  if (code == StoryDiagnosticCode.graphEventCannotReachTermination) {
    return 'Add a structurally reachable terminal transition from this region '
        'if the story is expected to finish.';
  }
  if (code == StoryDiagnosticCode.presentationChoiceMissingText) {
    return 'Add meaningful default presentation text for the interactive '
        'choice.';
  }
  if (code == StoryDiagnosticCode.presentationEventEmptyText) {
    return 'Remove the empty field or provide non-whitespace presentation text.';
  }
  if (code ==
      StoryDiagnosticCode.presentationContinuationWithoutMeaningfulPresentation) {
    return 'Give the continuation event meaningful title/body content so the '
        'host has something to present while paused.';
  }
  if (code ==
      StoryDiagnosticCode.presentationAutomaticEventPresentationNotHostVisible) {
    return 'Move user-visible content to a host-visible event, or remove the '
        'unused automatic-event presentation.';
  }
  return null;
}

bool _orderedReferencesEqual(
  List<StoryDiagnosticReference> left,
  List<StoryDiagnosticReference> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _orderedLocationsEqual(
  List<StoryDiagnosticLocation> left,
  List<StoryDiagnosticLocation> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
