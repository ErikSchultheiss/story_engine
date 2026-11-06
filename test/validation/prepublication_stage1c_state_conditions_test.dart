import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    '1C nested ALL guard keeps later ANY scalar reads safe in every mode',
    () {
      final project = _project(
        StoryAllCondition([
          StoryNotCondition(StoryVariableIsUnsetCondition(variableId: _score)),
          StoryAnyCondition([
            _comparison(),
            StoryNotCondition(StoryVariableIsSetCondition(variableId: _score)),
          ]),
        ]),
      );
      for (final context in _contexts()) {
        expect(
          _reads(StoryValidator.validate(project, context: context)),
          isEmpty,
        );
      }
    },
  );

  test('1C nested ANY guard narrows its false branch before a scalar read', () {
    final project = _project(
      StoryAnyCondition([
        StoryNotCondition(StoryVariableIsSetCondition(variableId: _score)),
        _comparison(),
      ]),
    );
    for (final context in _contexts()) {
      expect(
        _reads(StoryValidator.validate(project, context: context)),
        isEmpty,
      );
    }
  });

  test(
    '1C nested unsafe read retains text, location and occurrence identity',
    () {
      final project = _project(
        StoryNotCondition(
          StoryAllCondition([
            StoryVariableIsUnsetCondition(variableId: _score),
            StoryAnyCondition([
              _comparison(),
              StoryVariableIsSetCondition(variableId: _score),
            ]),
          ]),
        ),
      );
      final location = StoryDiagnosticLocation.condition(
        projectId: _projectId,
        eventId: _root,
        path: [
          const StoryDiagnosticPathSegment.field('events'),
          const StoryDiagnosticPathSegment.index(0),
          const StoryDiagnosticPathSegment.field('availabilityCondition'),
          const StoryDiagnosticPathSegment.field('condition'),
          const StoryDiagnosticPathSegment.field('conditions'),
          const StoryDiagnosticPathSegment.index(1),
          const StoryDiagnosticPathSegment.field('conditions'),
          const StoryDiagnosticPathSegment.index(0),
          const StoryDiagnosticPathSegment.field('variableId'),
        ],
      );
      final related = StoryDiagnosticLocation.variable(
        projectId: _projectId,
        variableId: _score,
        path: [
          const StoryDiagnosticPathSegment.field('stateSchema'),
          const StoryDiagnosticPathSegment.field('variables'),
          const StoryDiagnosticPathSegment.index(0),
        ],
      );
      for (final context in _contexts()) {
        final reads = _reads(
          StoryValidator.validate(project, context: context),
        );
        expect(reads, hasLength(1));
        final diagnostic = reads.single;
        expect(diagnostic.severity, StoryDiagnosticSeverity.warning);
        expect(diagnostic.message, _definitelyUnset);
        expect(diagnostic.location, location);
        expect(diagnostic.references, [
          StoryDiagnosticReference.variable(_score),
        ]);
        expect(diagnostic.relatedLocations, [related]);
        expect(
          diagnostic.identity,
          StoryDiagnosticIdentity(
            code: StoryDiagnosticCode.stateReadMayBeUnset,
            location: location,
            references: [StoryDiagnosticReference.variable(_score)],
            relatedLocations: [related],
          ),
        );
        expect(
          StoryValidator.validate(project, context: context).diagnostics,
          StoryValidator.validate(project, context: context).diagnostics,
        );
      }
    },
  );

  for (final context in _contexts()) {
    test('1C ${context.mode.name} retains its state assumptions under NOT', () {
      final reads = _reads(
        StoryValidator.validate(
          _project(StoryNotCondition(_comparison())),
          context: context,
        ),
      );
      expect(reads, hasLength(1));
      expect(
        reads.single.message,
        context.assumesInitialState ? _definitelyUnset : _possiblyUnset,
      );
      expect(
        reads.single.location.pathString,
        'events[0].availabilityCondition.condition.variableId',
      );
    });
  }

  final invalidCases = [
    (
      'operand type',
      StoryVariableComparisonCondition(
        variableId: _score,
        operator: StoryComparisonOperator.equal,
        value: const StoryBooleanValue(true),
      ),
      StoryValueType.integer,
      StoryDiagnosticCode.typeConditionOperandMismatch,
    ),
    (
      'undeclared variable',
      StoryVariableComparisonCondition(
        variableId: StoryVariableId('unknown'),
        operator: StoryComparisonOperator.equal,
        value: StoryIntegerValue(1),
      ),
      StoryValueType.integer,
      StoryDiagnosticCode.referenceUndeclaredConditionVariable,
    ),
  ];
  for (final (name, condition, type, code) in invalidCases) {
    test('1C $name is rejected without an unsound unset-read claim', () {
      final project = _project(condition, type: type);
      for (final context in _contexts()) {
        final report = StoryValidator.validate(project, context: context);
        expect(report.diagnostics.map((d) => d.code), contains(code));
        expect(_reads(report), isEmpty);
      }
    });
  }

  test(
    '1C event and choice comparisons retain separate location ownership',
    () {
      final project = StoryProject(
        id: _projectId,
        entryEventId: _root,
        stateSchema: _schema(StoryValueType.integer),
        events: [
          StoryEvent(
            id: _root,
            availabilityCondition: StoryNotCondition(_comparison()),
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice'),
                availabilityCondition: _comparison(),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final reads = _reads(StoryValidator.validate(project));
      expect(reads.map((d) => d.location.pathString), [
        'events[0].availabilityCondition.condition.variableId',
        'events[0].choices[0].availabilityCondition.variableId',
      ]);
      expect(reads.map((d) => d.location.choiceId?.value), [null, 'choice']);
      expect(reads.map((d) => d.message), [_definitelyUnset, _definitelyUnset]);
    },
  );
}

final _projectId = StoryProjectId('state_conditions_1c');
final _root = StoryEventId('root');
final _score = StoryVariableId('score');
final _definitelyUnset =
    'Comparison reads $_score, which is definitely unset at this reachable '
    'condition. Unset comparisons evaluate to false; use an explicit '
    'is-set/is-unset predicate when that distinction is intentional.';
final _possiblyUnset =
    'Comparison reads $_score, which may be unset on a reachable path. '
    'Unset comparisons evaluate to false; guard the value read explicitly '
    'when needed.';

List<StoryValidationContext> _contexts() => [
  const StoryValidationContext.standalone(),
  StoryValidationContext.orchestration(entryEventIds: [_root]),
  StoryValidationContext.moduleSlice(
    entryEventIds: [_root],
    knownExternalEventIds: const [],
  ),
];

StoryStateSchema _schema(StoryValueType type) => StoryStateSchema(
  variables: [StoryVariableDefinition(id: _score, type: type)],
);

StoryProject _project(
  StoryCondition condition, {
  StoryValueType type = StoryValueType.integer,
}) => StoryProject(
  id: _projectId,
  entryEventId: _root,
  stateSchema: _schema(type),
  events: [
    StoryEvent(
      id: _root,
      availabilityCondition: condition,
      automaticTransition: const StoryTerminalTransition(),
    ),
  ],
);

StoryVariableComparisonCondition _comparison() =>
    StoryVariableComparisonCondition(
      variableId: _score,
      operator: StoryComparisonOperator.equal,
      value: StoryIntegerValue(1),
    );

List<StoryDiagnostic> _reads(StoryValidationReport report) => report.diagnostics
    .where(
      (diagnostic) =>
          diagnostic.code == StoryDiagnosticCode.stateReadMayBeUnset,
    )
    .toList();
