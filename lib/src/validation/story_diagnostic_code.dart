/// Stable machine-readable identity for one category of validation problem.
///
/// Engine-owned codes use lower-case dot-separated tokens such as
/// `structure.missing_entry_event`. Human-facing diagnostic text is deliberately
/// not part of this identity, so messages may later be localized or clarified
/// without changing integrations that key off the code.
final class StoryDiagnosticCode implements Comparable<StoryDiagnosticCode> {
  /// Creates a machine-readable diagnostic code.
  ///
  /// The engine's own codes follow the documented lower-case dot-separated
  /// convention. This constructor remains public so future integrations can
  /// attach diagnostics from extension domains without depending on engine
  /// internals.
  const StoryDiagnosticCode(this.value) : assert(value != '');

  /// Project has no authored entry event.
  static const structureMissingEntryEvent = StoryDiagnosticCode(
    'structure.missing_entry_event',
  );

  /// Project entry ID does not resolve to an authored event.
  static const structureEntryEventNotFound = StoryDiagnosticCode(
    'structure.entry_event_not_found',
  );

  /// Two or more authored events carry the same machine ID.
  static const identityDuplicateEventId = StoryDiagnosticCode(
    'identity.duplicate_event_id',
  );

  /// Two or more authored choices carry the same machine ID.
  static const identityDuplicateChoiceId = StoryDiagnosticCode(
    'identity.duplicate_choice_id',
  );

  /// An authored choice is incomplete because it has no transition.
  static const structureChoiceMissingTransition = StoryDiagnosticCode(
    'structure.choice_missing_transition',
  );

  /// An authored event defines no runnable flow mode.
  static const structureEventMissingFlow = StoryDiagnosticCode(
    'structure.event_missing_flow',
  );

  /// An authored event defines more than one mutually exclusive flow mode.
  static const structureEventAmbiguousFlow = StoryDiagnosticCode(
    'structure.event_ambiguous_flow',
  );

  /// A direct transition points to an event that is not authored.
  static const referenceMissingTransitionDestination = StoryDiagnosticCode(
    'reference.missing_transition_destination',
  );

  /// A condition references a state variable that is not declared.
  static const referenceUndeclaredConditionVariable = StoryDiagnosticCode(
    'reference.undeclared_condition_variable',
  );

  /// An effect references a state variable that is not declared.
  static const referenceUndeclaredEffectVariable = StoryDiagnosticCode(
    'reference.undeclared_effect_variable',
  );

  /// A comparison literal does not match its declared variable type.
  static const typeConditionOperandMismatch = StoryDiagnosticCode(
    'type.condition_operand_mismatch',
  );

  /// A comparison operator is not valid for the declared variable type.
  static const typeConditionOperatorNotSupported = StoryDiagnosticCode(
    'type.condition_operator_not_supported',
  );

  /// A set effect value does not match its declared variable type.
  static const typeEffectValueMismatch = StoryDiagnosticCode(
    'type.effect_value_mismatch',
  );

  /// Increment/decrement targets a non-numeric declared variable.
  static const typeNumericEffectTargetNotNumeric = StoryDiagnosticCode(
    'type.numeric_effect_target_not_numeric',
  );

  /// A numeric effect amount does not match its numeric variable type.
  static const typeNumericEffectAmountMismatch = StoryDiagnosticCode(
    'type.numeric_effect_amount_mismatch',
  );

  /// A scalar comparison can observe the referenced variable while unset.
  static const stateReadMayBeUnset = StoryDiagnosticCode(
    'state.read_may_be_unset',
  );

  /// A numeric adjustment definitely targets an unset variable.
  static const stateNumericEffectTargetUnset = StoryDiagnosticCode(
    'state.numeric_effect_target_unset',
  );

  /// A numeric adjustment may target an unset variable on a reachable path.
  static const stateNumericEffectTargetMayBeUnset = StoryDiagnosticCode(
    'state.numeric_effect_target_may_be_unset',
  );

  /// A declared variable is never referenced by authored logic.
  static const stateVariableNeverReferenced = StoryDiagnosticCode(
    'state.variable_never_referenced',
  );

  /// A variable is written but never observed by an authored condition.
  static const stateVariableWrittenNeverRead = StoryDiagnosticCode(
    'state.variable_written_never_read',
  );

  /// A read variable has neither an initial value nor any authored write.
  static const stateVariableReadWithoutInitialization = StoryDiagnosticCode(
    'state.variable_read_without_initialization',
  );

  /// An authored event has no structural path from the project entry event.
  static const graphUnreachableEvent = StoryDiagnosticCode(
    'graph.unreachable_event',
  );

  /// A reachable cycle is composed entirely of interactive event flow.
  static const graphInteractiveCycle = StoryDiagnosticCode(
    'graph.interactive_cycle',
  );

  /// A reachable cycle is composed entirely of continuation event flow.
  static const graphContinuationCycle = StoryDiagnosticCode(
    'graph.continuation_cycle',
  );

  /// A reachable cycle is composed entirely of synchronous automatic flow.
  static const graphAutomaticCycle = StoryDiagnosticCode(
    'graph.automatic_cycle',
  );

  /// A reachable cycle crosses more than one event flow mode.
  static const graphMixedCycle = StoryDiagnosticCode(
    'graph.mixed_cycle',
  );

  /// A reachable event or cycle region has no structural path to termination.
  static const graphEventCannotReachTermination = StoryDiagnosticCode(
    'graph.event_cannot_reach_termination',
  );

  /// An interactive choice has no meaningful default presentation text.
  static const presentationChoiceMissingText = StoryDiagnosticCode(
    'presentation.choice_missing_text',
  );

  /// A present event title/body field contains only empty/whitespace text.
  static const presentationEventEmptyText = StoryDiagnosticCode(
    'presentation.event_empty_text',
  );

  /// A valid continuation event would pause without meaningful presentation.
  static const presentationContinuationWithoutMeaningfulPresentation =
      StoryDiagnosticCode(
        'presentation.continuation_without_meaningful_presentation',
      );

  /// A valid automatic event carries presentation that runtime never exposes.
  static const presentationAutomaticEventPresentationNotHostVisible =
      StoryDiagnosticCode(
        'presentation.automatic_event_presentation_not_host_visible',
      );

  /// Stable machine-readable token.
  final String value;

  @override
  int compareTo(StoryDiagnosticCode other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticCode && other.value == value;

  @override
  int get hashCode => Object.hash(StoryDiagnosticCode, value);

  @override
  String toString() => value;
}
