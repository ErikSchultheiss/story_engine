import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

final _projectId = StoryProjectId('context_project');
final _a = StoryEventId('a');
final _b = StoryEventId('b');
final _external = StoryEventId('external');
final _score = StoryVariableId('score');
Set<StoryDiagnosticCode> _codes(StoryValidationReport r) =>
    r.diagnostics.map((d) => d.code).toSet();
StoryProject _single({
  StoryEventId? entry,
  StoryTransition transition = const StoryTerminalTransition(),
}) => StoryProject(
  id: _projectId,
  entryEventId: entry,
  events: [StoryEvent(id: _a, continuationTransition: transition)],
);
void main() {
  test(
    'standalone stays the default and still requires a valid default entry',
    () {
      final project = _single();
      final defaultReport = StoryValidator.validate(project);
      final explicit = StoryValidator.validate(
        project,
        context: const StoryValidationContext.standalone(),
      );
      expect(defaultReport.diagnostics, explicit.diagnostics);
      expect(
        _codes(defaultReport),
        contains(StoryDiagnosticCode.structureMissingEntryEvent),
      );
      expect(
        _codes(StoryValidator.validate(_single(entry: _b))),
        contains(StoryDiagnosticCode.structureEntryEventNotFound),
      );
    },
  );

  test(
    'orchestration accepts independent activations without a default entry',
    () {
      final project = StoryProject(
        id: _projectId,
        events: [
          StoryEvent(
            id: _a,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: _b,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final report = StoryValidator.validate(
        project,
        context: StoryValidationContext.orchestration(entryEventIds: [_a, _b]),
      );
      expect(report.errors, isEmpty);
      expect(
        _codes(report),
        isNot(contains(StoryDiagnosticCode.graphUnreachableEvent)),
      );
      final oneRoot = StoryValidator.validate(
        project,
        context: StoryValidationContext.orchestration(entryEventIds: [_a]),
      );
      final unreachable = oneRoot.diagnostics.singleWhere(
        (d) => d.code == StoryDiagnosticCode.graphUnreachableEvent,
      );
      expect(unreachable.location.eventId, _b);
    },
  );

  test('unknown context roots receive a precise stable diagnostic', () {
    final report = StoryValidator.validate(
      _single(),
      context: StoryValidationContext.orchestration(entryEventIds: [_b, _b]),
    );
    expect(report.errors, hasLength(1));
    expect(
      report.errors.single.code,
      StoryDiagnosticCode.structureValidationEntryNotFound,
    );
    expect(report.errors.single.references, [
      StoryDiagnosticReference.event(_b),
    ]);
    expect(
      StoryDiagnosticCode.structureValidationEntryNotFound.value,
      'structure.validation_entry_not_found',
    );
  });

  test('optional declared default still must resolve in orchestration', () {
    final report = StoryValidator.validate(
      _single(entry: _b),
      context: StoryValidationContext.orchestration(entryEventIds: [_a]),
    );
    expect(
      _codes(report),
      contains(StoryDiagnosticCode.structureEntryEventNotFound),
    );
    expect(
      _codes(report),
      isNot(contains(StoryDiagnosticCode.structureMissingEntryEvent)),
    );
  });

  test('module slices accept only explicitly known external destinations', () {
    final project = _single(
      transition: StoryEventTransition(destinationEventId: _external),
    );
    final valid = StoryValidator.validate(
      project,
      context: StoryValidationContext.moduleSlice(
        entryEventIds: [_a],
        knownExternalEventIds: [_external],
      ),
    );
    expect(valid.errors, isEmpty);
    expect(
      _codes(valid),
      isNot(contains(StoryDiagnosticCode.graphEventCannotReachTermination)),
    );
    final missing = StoryValidator.validate(
      project,
      context: StoryValidationContext.moduleSlice(
        entryEventIds: [_a],
        knownExternalEventIds: [],
      ),
    );
    expect(
      _codes(missing),
      contains(StoryDiagnosticCode.referenceMissingTransitionDestination),
    );
    final whole = StoryValidator.validate(
      project,
      context: StoryValidationContext.orchestration(entryEventIds: [_a]),
    );
    expect(
      _codes(whole),
      contains(StoryDiagnosticCode.referenceMissingTransitionDestination),
    );
  });

  test(
    'global defaults and roots outside a module are accepted only when indexed externally',
    () {
      final project = _single(entry: _external);
      final report = StoryValidator.validate(
        project,
        context: StoryValidationContext.moduleSlice(
          entryEventIds: [_b],
          knownExternalEventIds: [_external, _b],
        ),
      );
      expect(report.errors, isEmpty);
      expect(
        _codes(report),
        isNot(contains(StoryDiagnosticCode.graphUnreachableEvent)),
      );
      final rejected = StoryValidator.validate(
        project,
        context: StoryValidationContext.moduleSlice(
          entryEventIds: [_b],
          knownExternalEventIds: [],
        ),
      );
      expect(
        _codes(rejected),
        containsAll([
          StoryDiagnosticCode.structureEntryEventNotFound,
          StoryDiagnosticCode.structureValidationEntryNotFound,
        ]),
      );
    },
  );

  test('all contexts retain flow, identity, reference and semantic errors', () {
    final project = StoryProject(
      id: _projectId,
      entryEventId: _a,
      stateSchema: StoryStateSchema(
        variables: [
          StoryVariableDefinition(id: _score, type: StoryValueType.integer),
        ],
      ),
      events: [
        StoryEvent(
          id: _a,
          entryEffects: [
            StorySetVariableEffect(
              variableId: _score,
              value: const StoryStringValue('bad'),
            ),
          ],
        ),
        StoryEvent(
          id: _a,
          automaticTransition: const StoryTerminalTransition(),
          availabilityCondition: StoryVariableIsSetCondition(
            variableId: StoryVariableId('missing'),
          ),
        ),
      ],
    );
    for (final context in [
      const StoryValidationContext.standalone(),
      StoryValidationContext.orchestration(entryEventIds: [_a]),
      StoryValidationContext.moduleSlice(
        entryEventIds: [_a],
        knownExternalEventIds: [],
      ),
    ]) {
      expect(
        _codes(StoryValidator.validate(project, context: context)),
        containsAll([
          StoryDiagnosticCode.structureEventMissingFlow,
          StoryDiagnosticCode.identityDuplicateEventId,
          StoryDiagnosticCode.typeEffectValueMismatch,
          StoryDiagnosticCode.referenceUndeclaredConditionVariable,
        ]),
      );
    }
  });

  test(
    'shared-state entry analysis does not assume schema initial values remain set',
    () {
      final project = StoryProject(
        id: _projectId,
        entryEventId: _a,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: _score,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(1),
            ),
          ],
        ),
        events: [
          StoryEvent(
            id: _a,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: _score,
                amount: StoryIntegerValue(1),
              ),
            ],
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      expect(
        _codes(StoryValidator.validate(project)),
        isNot(contains(StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset)),
      );
      final shared = StoryValidator.validate(
        project,
        context: StoryValidationContext.orchestration(entryEventIds: [_a]),
      );
      expect(
        _codes(shared),
        contains(StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset),
      );
      expect(
        _codes(shared),
        isNot(contains(StoryDiagnosticCode.stateNumericEffectTargetUnset)),
      );
    },
  );

  test(
    'every host root is seeded for state-use analysis, preserving presence guards',
    () {
      final project = StoryProject(
        id: _projectId,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(id: _score, type: StoryValueType.integer),
          ],
        ),
        events: [
          StoryEvent(
            id: _a,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: _b,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: _score,
                amount: StoryIntegerValue(1),
              ),
            ],
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final report = StoryValidator.validate(
        project,
        context: StoryValidationContext.orchestration(entryEventIds: [_a, _b]),
      );
      final warning = report.diagnostics.singleWhere(
        (d) => d.code == StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
      );
      expect(warning.location.eventId, _b);
      final guarded = StoryProject(
        id: _projectId,
        stateSchema: project.stateSchema,
        events: [
          StoryEvent(
            id: _b,
            availabilityCondition: StoryVariableIsSetCondition(
              variableId: _score,
            ),
            entryEffects: project.events[1].entryEffects,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      expect(
        _codes(
          StoryValidator.validate(
            guarded,
            context: StoryValidationContext.orchestration(entryEventIds: [_b]),
          ),
        ),
        isNot(contains(StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset)),
      );
    },
  );

  test(
    'external initialization is not misdiagnosed as having no possible initializer',
    () {
      final project = StoryProject(
        id: _projectId,
        entryEventId: _a,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(id: _score, type: StoryValueType.integer),
          ],
        ),
        events: [
          StoryEvent(
            id: _a,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: _score,
              operator: StoryComparisonOperator.equal,
              value: StoryIntegerValue(1),
            ),
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      expect(
        _codes(StoryValidator.validate(project)),
        contains(StoryDiagnosticCode.stateVariableReadWithoutInitialization),
      );
      final shared = StoryValidator.validate(
        project,
        context: StoryValidationContext.orchestration(entryEventIds: [_a]),
      );
      expect(
        _codes(shared),
        isNot(
          contains(StoryDiagnosticCode.stateVariableReadWithoutInitialization),
        ),
      );
      expect(_codes(shared), contains(StoryDiagnosticCode.stateReadMayBeUnset));
    },
  );

  test('context owns roots and external IDs and validation is repeatable', () {
    final roots = [_a];
    final external = [_external];
    final context = StoryValidationContext.moduleSlice(
      entryEventIds: roots,
      knownExternalEventIds: external,
    );
    roots.clear();
    external.clear();
    expect(context.entryEventIds, [_a]);
    expect(context.knownExternalEventIds, {_external});
    expect(() => context.entryEventIds.clear(), throwsUnsupportedError);
    expect(() => context.knownExternalEventIds.clear(), throwsUnsupportedError);
    final project = _single(
      transition: StoryEventTransition(destinationEventId: _external),
    );
    expect(
      StoryValidator.validate(project, context: context).diagnostics,
      StoryValidator.validate(project, context: context).diagnostics,
    );
  });

  test('legacy extra roots retain their graph-only behavior', () {
    final project = StoryProject(
      id: _projectId,
      entryEventId: _a,
      stateSchema: StoryStateSchema(
        variables: [
          StoryVariableDefinition(id: _score, type: StoryValueType.integer),
        ],
      ),
      events: [
        StoryEvent(
          id: _a,
          continuationTransition: const StoryTerminalTransition(),
        ),
        StoryEvent(
          id: _b,
          entryEffects: [
            StoryIncrementVariableEffect(
              variableId: _score,
              amount: StoryIntegerValue(1),
            ),
          ],
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    );
    final legacy = StoryValidator.validate(
      project,
      additionalEntryEventIds: [_b],
    );
    expect(
      _codes(legacy),
      isNot(contains(StoryDiagnosticCode.graphUnreachableEvent)),
    );
    expect(
      _codes(legacy),
      isNot(contains(StoryDiagnosticCode.stateNumericEffectTargetUnset)),
    );
  });
}
