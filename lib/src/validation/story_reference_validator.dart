import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_project.dart';
import '../state/story_state_schema.dart';
import '../transition/story_transition.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stage 3C reference validation over the complete authored declarative tree.
///
/// Traversal is deliberately static: it never asks runtime evaluators,
/// executors, or transition resolvers to interpret authored data.
final class StoryReferenceValidator {
  const StoryReferenceValidator();

  List<StoryDiagnostic> validate(StoryProject project) {
    final diagnostics = <StoryDiagnostic>[];
    final eventIds = project.events.map((event) => event.id).toSet();

    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      final eventPath = _eventPath(eventIndex);

      final availabilityCondition = event.availabilityCondition;
      if (availabilityCondition != null) {
        _validateCondition(
          condition: availabilityCondition,
          project: project,
          eventId: event.id,
          choiceId: null,
          path: [
            ...eventPath,
            const StoryDiagnosticPathSegment.field('availabilityCondition'),
          ],
          diagnostics: diagnostics,
        );
      }

      for (
        var effectIndex = 0;
        effectIndex < event.entryEffects.length;
        effectIndex++
      ) {
        _validateEffect(
          effect: event.entryEffects[effectIndex],
          project: project,
          eventId: event.id,
          choiceId: null,
          path: [
            ...eventPath,
            const StoryDiagnosticPathSegment.field('entryEffects'),
            StoryDiagnosticPathSegment.index(effectIndex),
          ],
          diagnostics: diagnostics,
        );
      }

      for (
        var choiceIndex = 0;
        choiceIndex < event.choices.length;
        choiceIndex++
      ) {
        final choice = event.choices[choiceIndex];
        final choicePath = _choicePath(eventIndex, choiceIndex);
        final choiceCondition = choice.availabilityCondition;
        if (choiceCondition != null) {
          _validateCondition(
            condition: choiceCondition,
            project: project,
            eventId: event.id,
            choiceId: choice.id,
            path: [
              ...choicePath,
              const StoryDiagnosticPathSegment.field('availabilityCondition'),
            ],
            diagnostics: diagnostics,
          );
        }

        for (
          var effectIndex = 0;
          effectIndex < choice.effects.length;
          effectIndex++
        ) {
          _validateEffect(
            effect: choice.effects[effectIndex],
            project: project,
            eventId: event.id,
            choiceId: choice.id,
            path: [
              ...choicePath,
              const StoryDiagnosticPathSegment.field('effects'),
              StoryDiagnosticPathSegment.index(effectIndex),
            ],
            diagnostics: diagnostics,
          );
        }

        final transition = choice.transition;
        if (transition != null) {
          _validateTransition(
            transition: transition,
            project: project,
            eventIds: eventIds,
            eventId: event.id,
            choiceId: choice.id,
            path: [
              ...choicePath,
              const StoryDiagnosticPathSegment.field('transition'),
            ],
            diagnostics: diagnostics,
          );
        }
      }

      final continuationTransition = event.continuationTransition;
      if (continuationTransition != null) {
        _validateTransition(
          transition: continuationTransition,
          project: project,
          eventIds: eventIds,
          eventId: event.id,
          choiceId: null,
          path: [
            ...eventPath,
            const StoryDiagnosticPathSegment.field('continuationTransition'),
          ],
          diagnostics: diagnostics,
        );
      }

      final automaticTransition = event.automaticTransition;
      if (automaticTransition != null) {
        _validateTransition(
          transition: automaticTransition,
          project: project,
          eventIds: eventIds,
          eventId: event.id,
          choiceId: null,
          path: [
            ...eventPath,
            const StoryDiagnosticPathSegment.field('automaticTransition'),
          ],
          diagnostics: diagnostics,
        );
      }
    }

    return diagnostics;
  }

  void _validateCondition({
    required StoryCondition condition,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    switch (condition) {
      case StoryAllCondition(:final conditions):
        for (var index = 0; index < conditions.length; index++) {
          _validateCondition(
            condition: conditions[index],
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('conditions'),
              StoryDiagnosticPathSegment.index(index),
            ],
            diagnostics: diagnostics,
          );
        }
      case StoryAnyCondition(:final conditions):
        for (var index = 0; index < conditions.length; index++) {
          _validateCondition(
            condition: conditions[index],
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('conditions'),
              StoryDiagnosticPathSegment.index(index),
            ],
            diagnostics: diagnostics,
          );
        }
      case StoryNotCondition(:final condition):
        _validateCondition(
          condition: condition,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('condition'),
          ],
          diagnostics: diagnostics,
        );
      case StoryVariableIsSetCondition(:final variableId):
        _validateConditionVariableReference(
          variableId: variableId,
          schema: project.stateSchema,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('variableId'),
          ],
          diagnostics: diagnostics,
        );
      case StoryVariableIsUnsetCondition(:final variableId):
        _validateConditionVariableReference(
          variableId: variableId,
          schema: project.stateSchema,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('variableId'),
          ],
          diagnostics: diagnostics,
        );
      case StoryVariableComparisonCondition(:final variableId):
        _validateConditionVariableReference(
          variableId: variableId,
          schema: project.stateSchema,
          project: project,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('variableId'),
          ],
          diagnostics: diagnostics,
        );
    }
  }

  void _validateConditionVariableReference({
    required StoryVariableId variableId,
    required StoryStateSchema schema,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    if (schema.contains(variableId)) {
      return;
    }

    diagnostics.add(
      StoryDiagnostic(
        code: StoryDiagnosticCode.referenceUndeclaredConditionVariable,
        severity: StoryDiagnosticSeverity.error,
        message: 'Condition references undeclared variable: '
            '${variableId.value}.',
        location: StoryDiagnosticLocation.condition(
          projectId: project.id,
          eventId: eventId,
          choiceId: choiceId,
          path: path,
        ),
        references: [StoryDiagnosticReference.variable(variableId)],
      ),
    );
  }

  void _validateEffect({
    required StoryEffect effect,
    required StoryProject project,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    final variableId = switch (effect) {
      StorySetVariableEffect(:final variableId) => variableId,
      StoryUnsetVariableEffect(:final variableId) => variableId,
      StoryIncrementVariableEffect(:final variableId) => variableId,
      StoryDecrementVariableEffect(:final variableId) => variableId,
    };

    if (project.stateSchema.contains(variableId)) {
      return;
    }

    diagnostics.add(
      StoryDiagnostic(
        code: StoryDiagnosticCode.referenceUndeclaredEffectVariable,
        severity: StoryDiagnosticSeverity.error,
        message: 'Effect references undeclared variable: ${variableId.value}.',
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
      ),
    );
  }

  void _validateTransition({
    required StoryTransition transition,
    required StoryProject project,
    required Set<StoryEventId> eventIds,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    switch (transition) {
      case StoryEventTransition(:final destinationEventId):
        if (!eventIds.contains(destinationEventId)) {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.referenceMissingTransitionDestination,
              severity: StoryDiagnosticSeverity.error,
              message: 'Transition destination does not exist: '
                  '${destinationEventId.value}.',
              location: StoryDiagnosticLocation.transition(
                projectId: project.id,
                eventId: eventId,
                choiceId: choiceId,
                path: [
                  ...path,
                  const StoryDiagnosticPathSegment.field(
                    'destinationEventId',
                  ),
                ],
              ),
              references: [
                StoryDiagnosticReference.event(destinationEventId),
              ],
            ),
          );
        }
      case StoryConditionalTransition(:final branches, :final fallback):
        for (var index = 0; index < branches.length; index++) {
          final branch = branches[index];
          final branchPath = <StoryDiagnosticPathSegment>[
            ...path,
            const StoryDiagnosticPathSegment.field('branches'),
            StoryDiagnosticPathSegment.index(index),
          ];
          _validateCondition(
            condition: branch.condition,
            project: project,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...branchPath,
              const StoryDiagnosticPathSegment.field('condition'),
            ],
            diagnostics: diagnostics,
          );
          _validateTransition(
            transition: branch.transition,
            project: project,
            eventIds: eventIds,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...branchPath,
              const StoryDiagnosticPathSegment.field('transition'),
            ],
            diagnostics: diagnostics,
          );
        }
        _validateTransition(
          transition: fallback,
          project: project,
          eventIds: eventIds,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('fallback'),
          ],
          diagnostics: diagnostics,
        );
      case StoryWeightedTransition(:final options):
        for (var index = 0; index < options.length; index++) {
          _validateTransition(
            transition: options[index].transition,
            project: project,
            eventIds: eventIds,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('options'),
              StoryDiagnosticPathSegment.index(index),
              const StoryDiagnosticPathSegment.field('transition'),
            ],
            diagnostics: diagnostics,
          );
        }
      case StoryTerminalTransition():
        return;
    }
  }
}

List<StoryDiagnosticPathSegment> _eventPath(int eventIndex) =>
    <StoryDiagnosticPathSegment>[
      const StoryDiagnosticPathSegment.field('events'),
      StoryDiagnosticPathSegment.index(eventIndex),
    ];

List<StoryDiagnosticPathSegment> _choicePath(
  int eventIndex,
  int choiceIndex,
) => <StoryDiagnosticPathSegment>[
  const StoryDiagnosticPathSegment.field('events'),
  StoryDiagnosticPathSegment.index(eventIndex),
  const StoryDiagnosticPathSegment.field('choices'),
  StoryDiagnosticPathSegment.index(choiceIndex),
];
