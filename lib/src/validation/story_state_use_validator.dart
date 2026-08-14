import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_choice.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../state/story_state_schema.dart';
import '../state/story_value_type.dart';
import '../transition/story_transition.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stage 3E conservative initialization and state-use analysis.
///
/// This validator performs static presence analysis only. It does not execute
/// runtime conditions/transitions or attempt to prove arbitrary authored
/// predicates. Set/unset guards and short-circuit Boolean composition are
/// understood because they directly determine whether a later scalar read can
/// observe an unset value.
final class StoryStateUseValidator {
  const StoryStateUseValidator();

  List<StoryDiagnostic> validate(StoryProject project) {
    final diagnostics = <StoryDiagnostic>[];
    final variableIndices = <StoryVariableId, int>{};
    for (var index = 0; index < project.stateSchema.variables.length; index++) {
      variableIndices[project.stateSchema.variables[index].id] = index;
    }

    final usage = _collectUsage(project);
    _addUsageDiagnostics(
      project: project,
      variableIndices: variableIndices,
      usage: usage,
      diagnostics: diagnostics,
    );

    final incomingStates = _computeIncomingStates(project);
    if (incomingStates != null) {
      _addInitializationDiagnostics(
        project: project,
        variableIndices: variableIndices,
        incomingStates: incomingStates,
        diagnostics: diagnostics,
      );
    }

    return diagnostics;
  }

  Map<StoryVariableId, _VariableUsage> _collectUsage(StoryProject project) {
    final usage = <StoryVariableId, _VariableUsage>{
      for (final definition in project.stateSchema.variables)
        definition.id: _VariableUsage(),
    };

    for (final event in project.events) {
      final availability = event.availabilityCondition;
      if (availability != null) {
        _collectConditionUsage(availability, usage);
      }
      for (final effect in event.entryEffects) {
        _collectEffectUsage(effect, usage);
      }
      for (final choice in event.choices) {
        final availability = choice.availabilityCondition;
        if (availability != null) {
          _collectConditionUsage(availability, usage);
        }
        for (final effect in choice.effects) {
          _collectEffectUsage(effect, usage);
        }
        final transition = choice.transition;
        if (transition != null) {
          _collectTransitionUsage(transition, usage);
        }
      }
      final continuation = event.continuationTransition;
      if (continuation != null) {
        _collectTransitionUsage(continuation, usage);
      }
      final automatic = event.automaticTransition;
      if (automatic != null) {
        _collectTransitionUsage(automatic, usage);
      }
    }

    return usage;
  }

  void _collectConditionUsage(
    StoryCondition condition,
    Map<StoryVariableId, _VariableUsage> usage,
  ) {
    switch (condition) {
      case StoryAllCondition(:final conditions):
        for (final child in conditions) {
          _collectConditionUsage(child, usage);
        }
      case StoryAnyCondition(:final conditions):
        for (final child in conditions) {
          _collectConditionUsage(child, usage);
        }
      case StoryNotCondition(:final condition):
        _collectConditionUsage(condition, usage);
      case StoryVariableIsSetCondition(:final variableId):
        final variableUsage = usage[variableId];
        if (variableUsage != null) {
          variableUsage.references++;
          variableUsage.reads++;
        }
      case StoryVariableIsUnsetCondition(:final variableId):
        final variableUsage = usage[variableId];
        if (variableUsage != null) {
          variableUsage.references++;
          variableUsage.reads++;
        }
      case StoryVariableComparisonCondition(:final variableId):
        final variableUsage = usage[variableId];
        if (variableUsage != null) {
          variableUsage.references++;
          variableUsage.reads++;
        }
    }
  }

  void _collectEffectUsage(
    StoryEffect effect,
    Map<StoryVariableId, _VariableUsage> usage,
  ) {
    final variableId = switch (effect) {
      StorySetVariableEffect(:final variableId) => variableId,
      StoryUnsetVariableEffect(:final variableId) => variableId,
      StoryIncrementVariableEffect(:final variableId) => variableId,
      StoryDecrementVariableEffect(:final variableId) => variableId,
    };
    final variableUsage = usage[variableId];
    if (variableUsage == null) {
      return;
    }
    variableUsage.references++;
    variableUsage.writes++;
  }

  void _collectTransitionUsage(
    StoryTransition transition,
    Map<StoryVariableId, _VariableUsage> usage,
  ) {
    switch (transition) {
      case StoryEventTransition():
        return;
      case StoryTerminalTransition():
        return;
      case StoryConditionalTransition(:final branches, :final fallback):
        for (final branch in branches) {
          _collectConditionUsage(branch.condition, usage);
          _collectTransitionUsage(branch.transition, usage);
        }
        _collectTransitionUsage(fallback, usage);
      case StoryWeightedTransition(:final options):
        for (final option in options) {
          _collectTransitionUsage(option.transition, usage);
        }
    }
  }

  void _addUsageDiagnostics({
    required StoryProject project,
    required Map<StoryVariableId, int> variableIndices,
    required Map<StoryVariableId, _VariableUsage> usage,
    required List<StoryDiagnostic> diagnostics,
  }) {
    for (final definition in project.stateSchema.variables) {
      final variableUsage = usage[definition.id]!;
      final location = _variableLocation(
        project: project,
        variableId: definition.id,
        variableIndices: variableIndices,
      );
      final reference = StoryDiagnosticReference.variable(definition.id);

      if (variableUsage.references == 0) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.stateVariableNeverReferenced,
            severity: StoryDiagnosticSeverity.information,
            message: 'Variable ${definition.id} is declared but never '
                'referenced by authored conditions or effects.',
            location: location,
            references: [reference],
          ),
        );
        continue;
      }

      if (variableUsage.writes > 0 && variableUsage.reads == 0) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.stateVariableWrittenNeverRead,
            severity: StoryDiagnosticSeverity.information,
            message: 'Variable ${definition.id} is written but never read by '
                'an authored condition.',
            location: location,
            references: [reference],
          ),
        );
        continue;
      }

      if (variableUsage.reads > 0 &&
          variableUsage.writes == 0 &&
          definition.initialValue == null) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.stateVariableReadWithoutInitialization,
            severity: StoryDiagnosticSeverity.warning,
            message: 'Variable ${definition.id} is read but has no initial '
                'value and is never assigned by an authored effect.',
            location: location,
            references: [reference],
          ),
        );
      }
    }
  }

  Map<StoryEventId, _PresenceState>? _computeIncomingStates(
    StoryProject project,
  ) {
    final entryEventId = project.entryEventId;
    if (entryEventId == null) {
      return null;
    }

    final indexedEvents = <StoryEventId, _IndexedEvent>{};
    for (var index = 0; index < project.events.length; index++) {
      final event = project.events[index];
      if (indexedEvents.containsKey(event.id)) {
        // Duplicate event identity makes destination interpretation ambiguous.
        // Stage 3B owns that error; Stage 3E avoids unsound path claims.
        return null;
      }
      indexedEvents[event.id] = _IndexedEvent(index: index, event: event);
    }
    if (!indexedEvents.containsKey(entryEventId)) {
      return null;
    }

    final incoming = <StoryEventId, _PresenceState>{};
    incoming[entryEventId] = _PresenceState.initial(project.stateSchema);

    final queue = <StoryEventId>[entryEventId];
    final queued = <StoryEventId>{entryEventId};
    var cursor = 0;

    while (cursor < queue.length) {
      final eventId = queue[cursor++];
      queued.remove(eventId);
      final indexed = indexedEvents[eventId]!;
      final state = incoming[eventId]!;

      _walkEvent(
        project: project,
        eventIndex: indexed.index,
        event: indexed.event,
        incomingState: state,
        variableIndices: const <StoryVariableId, int>{},
        emitDiagnostics: false,
        diagnostics: null,
        onDestination: (destinationEventId, destinationState) {
          if (!destinationState.reachable ||
              !indexedEvents.containsKey(destinationEventId)) {
            return;
          }
          final previous = incoming[destinationEventId];
          final merged = previous == null
              ? destinationState
              : previous.merge(destinationState);
          if (previous == null || merged != previous) {
            incoming[destinationEventId] = merged;
            if (queued.add(destinationEventId)) {
              queue.add(destinationEventId);
            }
          }
        },
      );
    }

    return incoming;
  }

  void _addInitializationDiagnostics({
    required StoryProject project,
    required Map<StoryVariableId, int> variableIndices,
    required Map<StoryEventId, _PresenceState> incomingStates,
    required List<StoryDiagnostic> diagnostics,
  }) {
    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      final incomingState = incomingStates[event.id];
      if (incomingState == null || !incomingState.reachable) {
        continue;
      }

      _walkEvent(
        project: project,
        eventIndex: eventIndex,
        event: event,
        incomingState: incomingState,
        variableIndices: variableIndices,
        emitDiagnostics: true,
        diagnostics: diagnostics,
        onDestination: (_, _) {},
      );
    }
  }

  void _walkEvent({
    required StoryProject project,
    required int eventIndex,
    required StoryEvent event,
    required _PresenceState incomingState,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
    required void Function(
      StoryEventId destinationEventId,
      _PresenceState state,
    ) onDestination,
  }) {
    final flowModeCount =
        (event.choices.isNotEmpty ? 1 : 0) +
        (event.continuationTransition != null ? 1 : 0) +
        (event.automaticTransition != null ? 1 : 0);
    if (flowModeCount != 1) {
      return;
    }

    final eventPath = _eventPath(eventIndex);
    var state = incomingState;
    final eventAvailability = event.availabilityCondition;
    if (eventAvailability != null) {
      final outcome = _analyzeCondition(
        condition: eventAvailability,
        state: state,
        project: project,
        eventId: event.id,
        choiceId: null,
        path: [
          ...eventPath,
          const StoryDiagnosticPathSegment.field('availabilityCondition'),
        ],
        variableIndices: variableIndices,
        emitDiagnostics: emitDiagnostics,
        diagnostics: diagnostics,
      );
      state = outcome.whenTrue;
      if (!state.reachable) {
        return;
      }
    }

    state = _applyEffects(
      effects: event.entryEffects,
      state: state,
      project: project,
      eventId: event.id,
      choiceId: null,
      path: [
        ...eventPath,
        const StoryDiagnosticPathSegment.field('entryEffects'),
      ],
      variableIndices: variableIndices,
      emitDiagnostics: emitDiagnostics,
      diagnostics: diagnostics,
    );
    if (!state.reachable) {
      return;
    }

    if (event.choices.isNotEmpty) {
      for (var choiceIndex = 0; choiceIndex < event.choices.length; choiceIndex++) {
        final choice = event.choices[choiceIndex];
        _walkChoice(
          project: project,
          eventIndex: eventIndex,
          choiceIndex: choiceIndex,
          eventId: event.id,
          choice: choice,
          incomingState: state,
          variableIndices: variableIndices,
          emitDiagnostics: emitDiagnostics,
          diagnostics: diagnostics,
          onDestination: onDestination,
        );
      }
      return;
    }

    final continuation = event.continuationTransition;
    if (continuation != null) {
      _walkTransition(
        transition: continuation,
        state: state,
        project: project,
        eventId: event.id,
        choiceId: null,
        path: [
          ...eventPath,
          const StoryDiagnosticPathSegment.field('continuationTransition'),
        ],
        variableIndices: variableIndices,
        emitDiagnostics: emitDiagnostics,
        diagnostics: diagnostics,
        onDestination: onDestination,
      );
      return;
    }

    final automatic = event.automaticTransition;
    if (automatic != null) {
      _walkTransition(
        transition: automatic,
        state: state,
        project: project,
        eventId: event.id,
        choiceId: null,
        path: [
          ...eventPath,
          const StoryDiagnosticPathSegment.field('automaticTransition'),
        ],
        variableIndices: variableIndices,
        emitDiagnostics: emitDiagnostics,
        diagnostics: diagnostics,
        onDestination: onDestination,
      );
    }
  }

  void _walkChoice({
    required StoryProject project,
    required int eventIndex,
    required int choiceIndex,
    required StoryEventId eventId,
    required StoryChoice choice,
    required _PresenceState incomingState,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
    required void Function(
      StoryEventId destinationEventId,
      _PresenceState state,
    ) onDestination,
  }) {
    final choicePath = _choicePath(eventIndex, choiceIndex);
    var state = incomingState;
    final availability = choice.availabilityCondition;
    if (availability != null) {
      final outcome = _analyzeCondition(
        condition: availability,
        state: state,
        project: project,
        eventId: eventId,
        choiceId: choice.id,
        path: [
          ...choicePath,
          const StoryDiagnosticPathSegment.field('availabilityCondition'),
        ],
        variableIndices: variableIndices,
        emitDiagnostics: emitDiagnostics,
        diagnostics: diagnostics,
      );
      state = outcome.whenTrue;
      if (!state.reachable) {
        return;
      }
    }

    state = _applyEffects(
      effects: choice.effects,
      state: state,
      project: project,
      eventId: eventId,
      choiceId: choice.id,
      path: [
        ...choicePath,
        const StoryDiagnosticPathSegment.field('effects'),
      ],
      variableIndices: variableIndices,
      emitDiagnostics: emitDiagnostics,
      diagnostics: diagnostics,
    );
    if (!state.reachable) {
      return;
    }

    final transition = choice.transition;
    if (transition == null) {
      return;
    }
    _walkTransition(
      transition: transition,
      state: state,
      project: project,
      eventId: eventId,
      choiceId: choice.id,
      path: [
        ...choicePath,
        const StoryDiagnosticPathSegment.field('transition'),
      ],
      variableIndices: variableIndices,
      emitDiagnostics: emitDiagnostics,
      diagnostics: diagnostics,
      onDestination: onDestination,
    );
  }

  _PresenceState _applyEffects({
    required List<StoryEffect> effects,
    required _PresenceState state,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
  }) {
    var current = state;
    for (var index = 0; index < effects.length; index++) {
      if (!current.reachable) {
        break;
      }
      final effect = effects[index];
      final effectPath = [...path, StoryDiagnosticPathSegment.index(index)];
      switch (effect) {
        case StorySetVariableEffect(:final variableId, :final value):
          final definition = project.stateSchema.definitionFor(variableId);
          if (definition == null || definition.type != value.type) {
            current = _PresenceState.unreachable();
          } else {
            current = current.assign(variableId, _PresenceState.set);
          }
        case StoryUnsetVariableEffect(:final variableId):
          if (!project.stateSchema.contains(variableId)) {
            current = _PresenceState.unreachable();
          } else {
            current = current.assign(variableId, _PresenceState.unset);
          }
        case StoryIncrementVariableEffect(:final variableId, :final amount):
          current = _applyNumericEffect(
            variableId: variableId,
            amountType: amount.type,
            current: current,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: effectPath,
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
          );
        case StoryDecrementVariableEffect(:final variableId, :final amount):
          current = _applyNumericEffect(
            variableId: variableId,
            amountType: amount.type,
            current: current,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: effectPath,
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
          );
      }
    }
    return current;
  }

  _PresenceState _applyNumericEffect({
    required StoryVariableId variableId,
    required StoryValueType amountType,
    required _PresenceState current,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
  }) {
    final definition = project.stateSchema.definitionFor(variableId);
    if (definition == null ||
        (definition.type != StoryValueType.integer &&
            definition.type != StoryValueType.number) ||
        definition.type != amountType) {
      // Stage 3C/3D own malformed-reference/type failures. Runtime cannot
      // continue through such an effect, so no downstream presence fact is
      // inferred from it.
      return _PresenceState.unreachable();
    }

    final presence = current.presenceOf(variableId);
    if (emitDiagnostics && (presence & _PresenceState.unset) != 0) {
      final definitelyUnset = (presence & _PresenceState.set) == 0;
      diagnostics!.add(
        StoryDiagnostic(
          code: definitelyUnset
              ? StoryDiagnosticCode.stateNumericEffectTargetUnset
              : StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
          severity: definitelyUnset
              ? StoryDiagnosticSeverity.error
              : StoryDiagnosticSeverity.warning,
          message: definitelyUnset
              ? 'Numeric adjustment targets $variableId, which is definitely '
                  'unset at this reachable effect.'
              : 'Numeric adjustment targets $variableId, which may be unset '
                  'on a reachable path.',
          location: StoryDiagnosticLocation.effect(
            projectId: project.id,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('variableId'),
            ],
          ),
          references: [StoryDiagnosticReference.variable(variableId)],
          relatedLocations: [
            _variableLocation(
              project: project,
              variableId: variableId,
              variableIndices: variableIndices,
            ),
          ],
        ),
      );
    }

    if ((presence & _PresenceState.set) == 0) {
      return _PresenceState.unreachable();
    }
    return current.narrow(variableId, _PresenceState.set);
  }

  _ConditionOutcome _analyzeCondition({
    required StoryCondition condition,
    required _PresenceState state,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
  }) {
    if (!state.reachable) {
      return const _ConditionOutcome.unreachable();
    }

    switch (condition) {
      case StoryAllCondition(:final conditions):
        var whenTrue = state;
        var whenFalse = _PresenceState.unreachable();
        for (var index = 0; index < conditions.length; index++) {
          final child = _analyzeCondition(
            condition: conditions[index],
            state: whenTrue,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('conditions'),
              StoryDiagnosticPathSegment.index(index),
            ],
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
          );
          whenFalse = whenFalse.merge(child.whenFalse);
          whenTrue = child.whenTrue;
          if (!whenTrue.reachable) {
            break;
          }
        }
        return _ConditionOutcome(whenTrue: whenTrue, whenFalse: whenFalse);
      case StoryAnyCondition(:final conditions):
        var whenTrue = _PresenceState.unreachable();
        var whenFalse = state;
        for (var index = 0; index < conditions.length; index++) {
          final child = _analyzeCondition(
            condition: conditions[index],
            state: whenFalse,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('conditions'),
              StoryDiagnosticPathSegment.index(index),
            ],
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
          );
          whenTrue = whenTrue.merge(child.whenTrue);
          whenFalse = child.whenFalse;
          if (!whenFalse.reachable) {
            break;
          }
        }
        return _ConditionOutcome(whenTrue: whenTrue, whenFalse: whenFalse);
      case StoryNotCondition(:final condition):
        final child = _analyzeCondition(
          condition: condition,
          state: state,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('condition'),
          ],
          variableIndices: variableIndices,
          emitDiagnostics: emitDiagnostics,
          diagnostics: diagnostics,
        );
        return _ConditionOutcome(
          whenTrue: child.whenFalse,
          whenFalse: child.whenTrue,
        );
      case StoryVariableIsSetCondition(:final variableId):
        if (!project.stateSchema.contains(variableId)) {
          return const _ConditionOutcome.unreachable();
        }
        return _ConditionOutcome(
          whenTrue: state.narrow(variableId, _PresenceState.set),
          whenFalse: state.narrow(variableId, _PresenceState.unset),
        );
      case StoryVariableIsUnsetCondition(:final variableId):
        if (!project.stateSchema.contains(variableId)) {
          return const _ConditionOutcome.unreachable();
        }
        return _ConditionOutcome(
          whenTrue: state.narrow(variableId, _PresenceState.unset),
          whenFalse: state.narrow(variableId, _PresenceState.set),
        );
      case StoryVariableComparisonCondition(
          :final variableId,
          :final operator,
          :final value,
        ):
        final definition = project.stateSchema.definitionFor(variableId);
        if (definition == null || definition.type != value.type) {
          return const _ConditionOutcome.unreachable();
        }
        final isOrdering = switch (operator) {
          StoryComparisonOperator.lessThan ||
          StoryComparisonOperator.lessThanOrEqual ||
          StoryComparisonOperator.greaterThan ||
          StoryComparisonOperator.greaterThanOrEqual => true,
          StoryComparisonOperator.equal || StoryComparisonOperator.notEqual =>
            false,
        };
        if (isOrdering &&
            definition.type != StoryValueType.integer &&
            definition.type != StoryValueType.number) {
          return const _ConditionOutcome.unreachable();
        }

        final presence = state.presenceOf(variableId);
        if (emitDiagnostics && (presence & _PresenceState.unset) != 0) {
          diagnostics!.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.stateReadMayBeUnset,
              severity: StoryDiagnosticSeverity.warning,
              message: (presence & _PresenceState.set) == 0
                  ? 'Comparison reads $variableId, which is definitely unset '
                      'at this reachable condition. Unset comparisons evaluate '
                      'to false; use an explicit is-set/is-unset predicate when '
                      'that distinction is intentional.'
                  : 'Comparison reads $variableId, which may be unset on a '
                      'reachable path. Unset comparisons evaluate to false; '
                      'guard the value read explicitly when needed.',
              location: StoryDiagnosticLocation.condition(
                projectId: project.id,
                eventId: eventId,
                choiceId: choiceId,
                path: [
                  ...path,
                  const StoryDiagnosticPathSegment.field('variableId'),
                ],
              ),
              references: [StoryDiagnosticReference.variable(variableId)],
              relatedLocations: [
                _variableLocation(
                  project: project,
                  variableId: variableId,
                  variableIndices: variableIndices,
                ),
              ],
            ),
          );
        }

        // Unset is not a scalar value and therefore can never satisfy a scalar
        // comparison. A true comparison proves the variable is set; a false
        // result may still come from either a set value or an unset variable.
        return _ConditionOutcome(
          whenTrue: state.narrow(variableId, _PresenceState.set),
          whenFalse: state,
        );
    }
  }

  void _walkTransition({
    required StoryTransition transition,
    required _PresenceState state,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required Map<StoryVariableId, int> variableIndices,
    required bool emitDiagnostics,
    required List<StoryDiagnostic>? diagnostics,
    required void Function(
      StoryEventId destinationEventId,
      _PresenceState state,
    ) onDestination,
  }) {
    if (!state.reachable) {
      return;
    }

    switch (transition) {
      case StoryEventTransition(:final destinationEventId):
        onDestination(destinationEventId, state);
        return;
      case StoryTerminalTransition():
        return;
      case StoryWeightedTransition(:final options):
        for (var index = 0; index < options.length; index++) {
          _walkTransition(
            transition: options[index].transition,
            state: state,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('options'),
              StoryDiagnosticPathSegment.index(index),
              const StoryDiagnosticPathSegment.field('transition'),
            ],
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
            onDestination: onDestination,
          );
        }
      case StoryConditionalTransition(:final branches, :final fallback):
        var remaining = state;
        for (var index = 0; index < branches.length; index++) {
          if (!remaining.reachable) {
            break;
          }
          final branch = branches[index];
          final branchPath = [
            ...path,
            const StoryDiagnosticPathSegment.field('branches'),
            StoryDiagnosticPathSegment.index(index),
          ];
          final outcome = _analyzeCondition(
            condition: branch.condition,
            state: remaining,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...branchPath,
              const StoryDiagnosticPathSegment.field('condition'),
            ],
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
          );
          _walkTransition(
            transition: branch.transition,
            state: outcome.whenTrue,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...branchPath,
              const StoryDiagnosticPathSegment.field('transition'),
            ],
            variableIndices: variableIndices,
            emitDiagnostics: emitDiagnostics,
            diagnostics: diagnostics,
            onDestination: onDestination,
          );
          remaining = outcome.whenFalse;
        }
        _walkTransition(
          transition: fallback,
          state: remaining,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('fallback'),
          ],
          variableIndices: variableIndices,
          emitDiagnostics: emitDiagnostics,
          diagnostics: diagnostics,
          onDestination: onDestination,
        );
    }
  }

  StoryDiagnosticLocation _variableLocation({
    required StoryProject project,
    required StoryVariableId variableId,
    required Map<StoryVariableId, int> variableIndices,
  }) {
    final index = variableIndices[variableId];
    if (index == null) {
      return StoryDiagnosticLocation.variable(
        projectId: project.id,
        variableId: variableId,
      );
    }
    return StoryDiagnosticLocation.variable(
      projectId: project.id,
      variableId: variableId,
      path: [
        const StoryDiagnosticPathSegment.field('stateSchema'),
        const StoryDiagnosticPathSegment.field('variables'),
        StoryDiagnosticPathSegment.index(index),
      ],
    );
  }
}

final class _VariableUsage {
  int references = 0;
  int reads = 0;
  int writes = 0;
}

final class _IndexedEvent {
  const _IndexedEvent({required this.index, required this.event});

  final int index;
  final StoryEvent event;
}

final class _ConditionOutcome {
  const _ConditionOutcome({required this.whenTrue, required this.whenFalse});

  const _ConditionOutcome.unreachable()
      : whenTrue = const _PresenceState._(reachable: false, presence: {}),
        whenFalse = const _PresenceState._(reachable: false, presence: {});

  final _PresenceState whenTrue;
  final _PresenceState whenFalse;
}

final class _PresenceState {
  const _PresenceState._({required this.reachable, required this.presence});

  factory _PresenceState.initial(StoryStateSchema schema) {
    return _PresenceState._(
      reachable: true,
      presence: Map<StoryVariableId, int>.unmodifiable({
        for (final definition in schema.variables)
          definition.id: definition.initialValue == null ? unset : set,
      }),
    );
  }

  factory _PresenceState.unreachable() =>
      const _PresenceState._(reachable: false, presence: {});

  static const int set = 1;
  static const int unset = 2;

  final bool reachable;
  final Map<StoryVariableId, int> presence;

  int presenceOf(StoryVariableId variableId) => presence[variableId] ?? 0;

  _PresenceState assign(StoryVariableId variableId, int value) {
    if (!reachable) {
      return this;
    }
    if (presence[variableId] == value) {
      return this;
    }
    final updated = Map<StoryVariableId, int>.of(presence);
    updated[variableId] = value;
    return _PresenceState._(
      reachable: true,
      presence: Map<StoryVariableId, int>.unmodifiable(updated),
    );
  }

  _PresenceState narrow(StoryVariableId variableId, int allowed) {
    if (!reachable) {
      return this;
    }
    final current = presenceOf(variableId);
    final narrowed = current & allowed;
    if (narrowed == 0) {
      return _PresenceState.unreachable();
    }
    return assign(variableId, narrowed);
  }

  _PresenceState merge(_PresenceState other) {
    if (!reachable) {
      return other;
    }
    if (!other.reachable) {
      return this;
    }

    var changed = false;
    final merged = Map<StoryVariableId, int>.of(presence);
    for (final entry in other.presence.entries) {
      final next = (merged[entry.key] ?? 0) | entry.value;
      if (next != merged[entry.key]) {
        merged[entry.key] = next;
        changed = true;
      }
    }
    if (!changed) {
      return this;
    }
    return _PresenceState._(
      reachable: true,
      presence: Map<StoryVariableId, int>.unmodifiable(merged),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PresenceState &&
          other.reachable == reachable &&
          _presenceMapsEqual(other.presence, presence);

  @override
  int get hashCode => Object.hash(
        _PresenceState,
        reachable,
        Object.hashAll(
          presence.entries.map((entry) => Object.hash(entry.key, entry.value)),
        ),
      );
}

bool _presenceMapsEqual(
  Map<StoryVariableId, int> left,
  Map<StoryVariableId, int> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

List<StoryDiagnosticPathSegment> _eventPath(int eventIndex) => [
      const StoryDiagnosticPathSegment.field('events'),
      StoryDiagnosticPathSegment.index(eventIndex),
    ];

List<StoryDiagnosticPathSegment> _choicePath(
  int eventIndex,
  int choiceIndex,
) =>
    [
      ..._eventPath(eventIndex),
      const StoryDiagnosticPathSegment.field('choices'),
      StoryDiagnosticPathSegment.index(choiceIndex),
    ];
