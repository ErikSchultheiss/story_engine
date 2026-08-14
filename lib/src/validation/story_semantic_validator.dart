import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_project.dart';
import '../state/story_value_type.dart';
import '../state/story_variable_definition.dart';
import '../transition/story_transition.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stage 3D type/semantic validation over representable authored data.
///
/// Constructor-owned invariants such as portable numeric ranges, non-negative
/// numeric effect amounts, non-empty Boolean groups, and positive weighted
/// transition weights stay at their existing model boundaries. This validator
/// checks schema-dependent compatibility that cannot be decided by those
/// standalone authored value objects.
final class StorySemanticValidator {
  const StorySemanticValidator();

  List<StoryDiagnostic> validate(StoryProject project) {
    final diagnostics = <StoryDiagnostic>[];
    final variableIndices = <StoryVariableId, int>{};
    for (var index = 0; index < project.stateSchema.variables.length; index++) {
      variableIndices[project.stateSchema.variables[index].id] = index;
    }

    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      final eventPath = _eventPath(eventIndex);

      final availabilityCondition = event.availabilityCondition;
      if (availabilityCondition != null) {
        _validateCondition(
          condition: availabilityCondition,
          project: project,
          variableIndices: variableIndices,
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
          variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
          variableIndices: variableIndices,
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
          variableIndices: variableIndices,
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
    required Map<StoryVariableId, int> variableIndices,
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
            variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
          variableIndices: variableIndices,
          eventId: eventId,
          choiceId: choiceId,
          path: [
            ...path,
            const StoryDiagnosticPathSegment.field('condition'),
          ],
          diagnostics: diagnostics,
        );
      case StoryVariableIsSetCondition():
        // Existence is owned by Stage 3C. These predicates have no scalar
        // literal/operator compatibility to inspect.
        return;
      case StoryVariableIsUnsetCondition():
        // Existence is owned by Stage 3C. These predicates have no scalar
        // literal/operator compatibility to inspect.
        return;
      case StoryVariableComparisonCondition():
        _validateComparisonCondition(
          condition: condition,
          project: project,
          variableIndices: variableIndices,
          eventId: eventId,
          choiceId: choiceId,
          path: path,
          diagnostics: diagnostics,
        );
    }
  }

  void _validateComparisonCondition({
    required StoryVariableComparisonCondition condition,
    required StoryProject project,
    required Map<StoryVariableId, int> variableIndices,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    final definition = project.stateSchema.definitionFor(condition.variableId);
    if (definition == null) {
      // Stage 3C owns the undeclared-reference diagnostic. Without a declared
      // type there is no sound schema-dependent semantic judgment to add.
      return;
    }

    final relatedLocation = _variableTypeLocation(
      project: project,
      definition: definition,
      variableIndex: variableIndices[definition.id]!,
    );

    if (definition.type != condition.value.type) {
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.typeConditionOperandMismatch,
          severity: StoryDiagnosticSeverity.error,
          message: 'Condition value type ${condition.value.type.name} does not '
              'match declared variable type ${definition.type.name} for '
              '${condition.variableId.value}.',
          location: StoryDiagnosticLocation.condition(
            projectId: project.id,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('value'),
            ],
          ),
          references: [
            StoryDiagnosticReference.variable(condition.variableId),
          ],
          relatedLocations: [relatedLocation],
        ),
      );
    }

    if (_isOrderingOperator(condition.operator) &&
        !_supportsOrdering(definition.type)) {
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.typeConditionOperatorNotSupported,
          severity: StoryDiagnosticSeverity.error,
          message: 'Comparison operator ${condition.operator.name} is not '
              'supported for variable type ${definition.type.name}.',
          location: StoryDiagnosticLocation.condition(
            projectId: project.id,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('operator'),
            ],
          ),
          references: [
            StoryDiagnosticReference.variable(condition.variableId),
          ],
          relatedLocations: [relatedLocation],
        ),
      );
    }
  }

  void _validateEffect({
    required StoryEffect effect,
    required StoryProject project,
    required Map<StoryVariableId, int> variableIndices,
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
    final definition = project.stateSchema.definitionFor(variableId);
    if (definition == null) {
      // Stage 3C owns undeclared effect references.
      return;
    }

    final relatedLocation = _variableTypeLocation(
      project: project,
      definition: definition,
      variableIndex: variableIndices[definition.id]!,
    );

    switch (effect) {
      case StorySetVariableEffect(:final value):
        if (definition.type != value.type) {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.typeEffectValueMismatch,
              severity: StoryDiagnosticSeverity.error,
              message: 'Effect value type ${value.type.name} does not match '
                  'declared variable type ${definition.type.name} for '
                  '${variableId.value}.',
              location: StoryDiagnosticLocation.effect(
                projectId: project.id,
                eventId: eventId,
                choiceId: choiceId,
                path: [
                  ...path,
                  const StoryDiagnosticPathSegment.field('value'),
                ],
              ),
              references: [StoryDiagnosticReference.variable(variableId)],
              relatedLocations: [relatedLocation],
            ),
          );
        }
      case StoryUnsetVariableEffect():
        return;
      case StoryIncrementVariableEffect(:final amount):
        _validateNumericEffect(
          amountType: amount.type,
          project: project,
          definition: definition,
          variableId: variableId,
          eventId: eventId,
          choiceId: choiceId,
          path: path,
          relatedLocation: relatedLocation,
          diagnostics: diagnostics,
        );
      case StoryDecrementVariableEffect(:final amount):
        _validateNumericEffect(
          amountType: amount.type,
          project: project,
          definition: definition,
          variableId: variableId,
          eventId: eventId,
          choiceId: choiceId,
          path: path,
          relatedLocation: relatedLocation,
          diagnostics: diagnostics,
        );
    }
  }

  void _validateNumericEffect({
    required StoryValueType amountType,
    required StoryProject project,
    required StoryVariableDefinition definition,
    required StoryVariableId variableId,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required StoryDiagnosticLocation relatedLocation,
    required List<StoryDiagnostic> diagnostics,
  }) {
    if (!_isNumericType(definition.type)) {
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.typeNumericEffectTargetNotNumeric,
          severity: StoryDiagnosticSeverity.error,
          message: 'Increment/decrement target ${variableId.value} is '
              'declared as ${definition.type.name}; a numeric variable is '
              'required.',
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
          relatedLocations: [relatedLocation],
        ),
      );
      return;
    }

    if (definition.type != amountType) {
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.typeNumericEffectAmountMismatch,
          severity: StoryDiagnosticSeverity.error,
          message: 'Numeric effect amount type ${amountType.name} does not '
              'match declared variable type ${definition.type.name} for '
              '${variableId.value}.',
          location: StoryDiagnosticLocation.effect(
            projectId: project.id,
            eventId: eventId,
            choiceId: choiceId,
            path: [
              ...path,
              const StoryDiagnosticPathSegment.field('amount'),
            ],
          ),
          references: [StoryDiagnosticReference.variable(variableId)],
          relatedLocations: [relatedLocation],
        ),
      );
    }
  }

  void _validateTransition({
    required StoryTransition transition,
    required StoryProject project,
    required Map<StoryVariableId, int> variableIndices,
    required StoryEventId eventId,
    required StoryChoiceId? choiceId,
    required List<StoryDiagnosticPathSegment> path,
    required List<StoryDiagnostic> diagnostics,
  }) {
    switch (transition) {
      case StoryEventTransition():
        return;
      case StoryTerminalTransition():
        return;
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
            variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
          variableIndices: variableIndices,
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
            variableIndices: variableIndices,
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
    }
  }
}

StoryDiagnosticLocation _variableTypeLocation({
  required StoryProject project,
  required StoryVariableDefinition definition,
  required int variableIndex,
}) => StoryDiagnosticLocation.variable(
  projectId: project.id,
  variableId: definition.id,
  path: [
    const StoryDiagnosticPathSegment.field('stateSchema'),
    const StoryDiagnosticPathSegment.field('variables'),
    StoryDiagnosticPathSegment.index(variableIndex),
    const StoryDiagnosticPathSegment.field('type'),
  ],
);

bool _isOrderingOperator(StoryComparisonOperator operator) => switch (operator) {
  StoryComparisonOperator.lessThan ||
  StoryComparisonOperator.lessThanOrEqual ||
  StoryComparisonOperator.greaterThan ||
  StoryComparisonOperator.greaterThanOrEqual => true,
  StoryComparisonOperator.equal || StoryComparisonOperator.notEqual => false,
};

bool _supportsOrdering(StoryValueType type) => _isNumericType(type);

bool _isNumericType(StoryValueType type) => switch (type) {
  StoryValueType.integer || StoryValueType.number => true,
  StoryValueType.boolean || StoryValueType.string => false,
};

List<StoryDiagnosticPathSegment> _eventPath(int eventIndex) => [
  const StoryDiagnosticPathSegment.field('events'),
  StoryDiagnosticPathSegment.index(eventIndex),
];

List<StoryDiagnosticPathSegment> _choicePath(
  int eventIndex,
  int choiceIndex,
) => [
  const StoryDiagnosticPathSegment.field('events'),
  StoryDiagnosticPathSegment.index(eventIndex),
  const StoryDiagnosticPathSegment.field('choices'),
  StoryDiagnosticPathSegment.index(choiceIndex),
];
