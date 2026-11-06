import 'package:story_engine/story_engine.dart';

/// Stable synthetic scale profiles used by Stage 2F regression tests.
enum SyntheticStoryProfile { small, medium, large }

/// Configuration for one stable structured synthetic story profile.
final class SyntheticStoryProfileConfig {
  const SyntheticStoryProfileConfig({
    required this.name,
    required this.eventCount,
    required this.choicesPerInteractiveEvent,
    required this.variableCount,
  });

  final String name;
  final int eventCount;
  final int choicesPerInteractiveEvent;
  final int variableCount;
}

extension SyntheticStoryProfileConfiguration on SyntheticStoryProfile {
  SyntheticStoryProfileConfig get config => switch (this) {
    SyntheticStoryProfile.small => const SyntheticStoryProfileConfig(
      name: 'small',
      eventCount: 100,
      choicesPerInteractiveEvent: 4,
      variableCount: 25,
    ),
    SyntheticStoryProfile.medium => const SyntheticStoryProfileConfig(
      name: 'medium',
      eventCount: 500,
      choicesPerInteractiveEvent: 4,
      variableCount: 100,
    ),
    SyntheticStoryProfile.large => const SyntheticStoryProfileConfig(
      name: 'large',
      eventCount: 1000,
      choicesPerInteractiveEvent: 5,
      variableCount: 250,
    ),
  };
}

/// A generated project plus structural metrics useful to scale tests.
final class SyntheticStoryProjectFixture {
  const SyntheticStoryProjectFixture({
    required this.project,
    required this.metrics,
    required this.signature,
  });

  final StoryProject project;
  final SyntheticStoryMetrics metrics;

  /// Deterministic structural signature generated only from public model data.
  final String signature;
}

/// Structural measurements for a generated project.
final class SyntheticStoryMetrics {
  const SyntheticStoryMetrics({
    required this.eventCount,
    required this.choiceCount,
    required this.variableCount,
    required this.automaticEventCount,
    required this.directTransitionCount,
    required this.conditionalTransitionCount,
    required this.weightedTransitionCount,
    required this.terminalTransitionCount,
    required this.conditionNodeCount,
    required this.maxConditionDepth,
    required this.effectCount,
    required this.backwardDestinationCount,
    required this.missingDestinationCount,
    required this.invalidVariableReferenceCount,
  });

  final int eventCount;
  final int choiceCount;
  final int variableCount;
  final int automaticEventCount;
  final int directTransitionCount;
  final int conditionalTransitionCount;
  final int weightedTransitionCount;
  final int terminalTransitionCount;
  final int conditionNodeCount;
  final int maxConditionDepth;
  final int effectCount;
  final int backwardDestinationCount;
  final int missingDestinationCount;
  final int invalidVariableReferenceCount;
}

/// Representable malformed-project defects supported by Stage 3H fault injection.
///
/// Constructor-owned invalidity such as malformed IDs, duplicate state-schema
/// identities, invalid initial-value types, empty Boolean groups, and invalid
/// weighted-transition weights is intentionally absent. Those values cannot be
/// represented as a [StoryProject] without weakening earlier invariants.
enum SyntheticStoryFault {
  missingDestination,
  duplicateEventId,
  duplicateChoiceId,
  undeclaredVariableReference,
  wrongConditionValueType,
  wrongEffectValueType,
  missingEntryEvent,
  ambiguousEventFlow,
  incompleteChoice,
  automaticCycle,
  unreachableEvent,
  potentiallyUninitializedVariable,
}

extension SyntheticStoryFaultContract on SyntheticStoryFault {
  /// Stable metadata token used by deterministic malformed-fixture tests.
  String get token => switch (this) {
    SyntheticStoryFault.missingDestination => 'missing_destination',
    SyntheticStoryFault.duplicateEventId => 'duplicate_event_id',
    SyntheticStoryFault.duplicateChoiceId => 'duplicate_choice_id',
    SyntheticStoryFault.undeclaredVariableReference =>
      'undeclared_variable_reference',
    SyntheticStoryFault.wrongConditionValueType => 'wrong_condition_value_type',
    SyntheticStoryFault.wrongEffectValueType => 'wrong_effect_value_type',
    SyntheticStoryFault.missingEntryEvent => 'missing_entry_event',
    SyntheticStoryFault.ambiguousEventFlow => 'ambiguous_event_flow',
    SyntheticStoryFault.incompleteChoice => 'incomplete_choice',
    SyntheticStoryFault.automaticCycle => 'automatic_cycle',
    SyntheticStoryFault.unreachableEvent => 'unreachable_event',
    SyntheticStoryFault.potentiallyUninitializedVariable =>
      'potentially_uninitialized_variable',
  };

  /// Diagnostic that must be present after this defect is injected in
  /// isolation or in a compatible multi-fault fixture.
  StoryDiagnosticCode get expectedDiagnosticCode => switch (this) {
    SyntheticStoryFault.missingDestination =>
      StoryDiagnosticCode.referenceMissingTransitionDestination,
    SyntheticStoryFault.duplicateEventId =>
      StoryDiagnosticCode.identityDuplicateEventId,
    SyntheticStoryFault.duplicateChoiceId =>
      StoryDiagnosticCode.identityDuplicateChoiceId,
    SyntheticStoryFault.undeclaredVariableReference =>
      StoryDiagnosticCode.referenceUndeclaredConditionVariable,
    SyntheticStoryFault.wrongConditionValueType =>
      StoryDiagnosticCode.typeConditionOperandMismatch,
    SyntheticStoryFault.wrongEffectValueType =>
      StoryDiagnosticCode.typeEffectValueMismatch,
    SyntheticStoryFault.missingEntryEvent =>
      StoryDiagnosticCode.structureMissingEntryEvent,
    SyntheticStoryFault.ambiguousEventFlow =>
      StoryDiagnosticCode.structureEventAmbiguousFlow,
    SyntheticStoryFault.incompleteChoice =>
      StoryDiagnosticCode.structureChoiceMissingTransition,
    SyntheticStoryFault.automaticCycle =>
      StoryDiagnosticCode.graphAutomaticCycle,
    SyntheticStoryFault.unreachableEvent =>
      StoryDiagnosticCode.graphUnreachableEvent,
    SyntheticStoryFault.potentiallyUninitializedVariable =>
      StoryDiagnosticCode.stateVariableReadWithoutInitialization,
  };

  StoryDiagnosticSeverity get expectedSeverity => switch (this) {
    SyntheticStoryFault.unreachableEvent ||
    SyntheticStoryFault.potentiallyUninitializedVariable =>
      StoryDiagnosticSeverity.warning,
    SyntheticStoryFault.missingDestination ||
    SyntheticStoryFault.duplicateEventId ||
    SyntheticStoryFault.duplicateChoiceId ||
    SyntheticStoryFault.undeclaredVariableReference ||
    SyntheticStoryFault.wrongConditionValueType ||
    SyntheticStoryFault.wrongEffectValueType ||
    SyntheticStoryFault.missingEntryEvent ||
    SyntheticStoryFault.ambiguousEventFlow ||
    SyntheticStoryFault.incompleteChoice ||
    SyntheticStoryFault.automaticCycle => StoryDiagnosticSeverity.error,
  };
}

/// Metadata describing one deliberate Stage 3H defect.
final class SyntheticStoryInjectedFault {
  const SyntheticStoryInjectedFault({
    required this.fault,
    required this.expectedDiagnosticCode,
    required this.expectedSeverity,
    required this.targetPath,
    required this.description,
  });

  final SyntheticStoryFault fault;
  final StoryDiagnosticCode expectedDiagnosticCode;
  final StoryDiagnosticSeverity expectedSeverity;

  /// Stable structural hint identifying where the generator injected the
  /// defect. This is test metadata, not a replacement for validator locations.
  final String targetPath;

  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyntheticStoryInjectedFault &&
          other.fault == fault &&
          other.expectedDiagnosticCode == expectedDiagnosticCode &&
          other.expectedSeverity == expectedSeverity &&
          other.targetPath == targetPath &&
          other.description == description;

  @override
  int get hashCode => Object.hash(
    fault,
    expectedDiagnosticCode,
    expectedSeverity,
    targetPath,
    description,
  );
}

/// A deterministic malformed project plus the exact faults injected into it.
final class SyntheticInvalidStoryProjectFixture {
  const SyntheticInvalidStoryProjectFixture({
    required this.project,
    required this.metrics,
    required this.signature,
    required this.baseSignature,
    required this.seed,
    required this.faults,
  });

  final StoryProject project;
  final SyntheticStoryMetrics metrics;
  final String signature;

  /// Signature of the known-valid randomized project before fault injection.
  final String baseSignature;

  final int seed;
  final List<SyntheticStoryInjectedFault> faults;
}

/// Deterministic generator for synthetic public-API story projects.
///
/// This is test infrastructure, not production package API. Structured
/// profiles provide stable known coverage. [randomized] produces valid but
/// more varied topologies, while [invalid] starts from that valid base and
/// injects deterministic representable faults for Stage 3H validator pressure.
final class SyntheticStoryProjectGenerator {
  const SyntheticStoryProjectGenerator._();

  /// Builds one stable structured profile without random topology changes.
  static SyntheticStoryProjectFixture structured(
    SyntheticStoryProfile profile,
  ) {
    final config = profile.config;
    final schema = _buildSchema(config.variableCount, prefix: config.name);
    final events = <StoryEvent>[];

    for (var eventIndex = 0; eventIndex < config.eventCount; eventIndex++) {
      events.add(
        _buildStructuredEvent(
          profileName: config.name,
          eventIndex: eventIndex,
          eventCount: config.eventCount,
          choicesPerInteractiveEvent: config.choicesPerInteractiveEvent,
          schema: schema,
        ),
      );
    }

    final project = StoryProject(
      id: StoryProjectId('synthetic_${config.name}_project'),
      alias: StoryAlias('synthetic_${config.name}'),
      stateSchema: schema,
      events: events,
      entryEventId: _eventId(config.name, 0),
    );

    return _fixture(project);
  }

  /// Builds a deterministic valid randomized project.
  ///
  /// The first available choice of every interactive non-terminal event always
  /// advances to a higher event index. Therefore black-box scale tests can
  /// safely traverse randomized projects to termination without understanding
  /// their additional noisy branches.
  static SyntheticStoryProjectFixture randomized({
    required int seed,
    int eventCount = 120,
    int variableCount = 40,
  }) {
    if (seed < 0 || seed > 0xffffffff) {
      throw ArgumentError.value(
        seed,
        'seed',
        'Synthetic randomized seeds must fit unsigned 32-bit range.',
      );
    }
    if (eventCount < 8) {
      throw ArgumentError.value(
        eventCount,
        'eventCount',
        'Randomized fixtures require at least 8 events.',
      );
    }
    if (variableCount < 8) {
      throw ArgumentError.value(
        variableCount,
        'variableCount',
        'Randomized fixtures require at least 8 variables.',
      );
    }

    final random = _SyntheticRandom(seed);
    final prefix = 'random_${seed.toRadixString(16)}';
    final schema = _buildSchema(variableCount, prefix: prefix);
    final events = <StoryEvent>[];

    for (var eventIndex = 0; eventIndex < eventCount; eventIndex++) {
      events.add(
        _buildRandomizedEvent(
          prefix: prefix,
          eventIndex: eventIndex,
          eventCount: eventCount,
          schema: schema,
          random: random,
        ),
      );
    }

    final project = StoryProject(
      id: StoryProjectId('synthetic_random_project_$seed'),
      alias: StoryAlias('synthetic_random_$seed'),
      stateSchema: schema,
      events: events,
      entryEventId: _eventId(prefix, 0),
    );

    return _fixture(project);
  }

  /// Builds a deterministic malformed project by first generating a known-
  /// valid randomized fixture and then injecting controlled defects.
  ///
  /// When [faults] is omitted, exactly one fault is selected by
  /// `seed % SyntheticStoryFault.values.length`. Explicit fault collections are
  /// canonicalized by enum order so equivalent sets produce identical output
  /// regardless of caller iteration order.
  static SyntheticInvalidStoryProjectFixture invalid({
    required int seed,
    Iterable<SyntheticStoryFault>? faults,
    int eventCount = 120,
    int variableCount = 40,
  }) {
    final base = randomized(
      seed: seed,
      eventCount: eventCount,
      variableCount: variableCount,
    );
    final requested = faults == null
        ? <SyntheticStoryFault>[
            SyntheticStoryFault.values[seed %
                SyntheticStoryFault.values.length],
          ]
        : faults.toList(growable: false);
    if (requested.isEmpty) {
      throw ArgumentError.value(
        faults,
        'faults',
        'Malformed synthetic fixtures require at least one injected fault.',
      );
    }

    final unique = <SyntheticStoryFault>{...requested};
    if (unique.length != requested.length) {
      throw ArgumentError.value(
        faults,
        'faults',
        'Each synthetic fault may be injected at most once per fixture.',
      );
    }
    final orderedFaults = unique.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    _validateSyntheticFaultCombination(orderedFaults);

    var project = base.project;
    final injected = <SyntheticStoryInjectedFault>[];
    for (final fault in orderedFaults) {
      final result = _injectSyntheticFault(
        project: project,
        fault: fault,
        seed: seed,
      );
      project = result.project;
      injected.add(result.metadata);
    }

    return SyntheticInvalidStoryProjectFixture(
      project: project,
      metrics: analyzeSyntheticProject(project),
      signature: syntheticProjectSignature(project),
      baseSignature: base.signature,
      seed: seed,
      faults: List<SyntheticStoryInjectedFault>.unmodifiable(injected),
    );
  }
}

final class _SyntheticFaultInjectionResult {
  const _SyntheticFaultInjectionResult({
    required this.project,
    required this.metadata,
  });

  final StoryProject project;
  final SyntheticStoryInjectedFault metadata;
}

void _validateSyntheticFaultCombination(List<SyntheticStoryFault> faults) {
  final blocksGraphAnalysis =
      faults.contains(SyntheticStoryFault.missingEntryEvent) ||
      faults.contains(SyntheticStoryFault.duplicateEventId);
  final expectsGraphDiagnostic =
      faults.contains(SyntheticStoryFault.automaticCycle) ||
      faults.contains(SyntheticStoryFault.unreachableEvent);
  if (blocksGraphAnalysis && expectsGraphDiagnostic) {
    throw ArgumentError.value(
      faults,
      'faults',
      'Missing entry identity and duplicate event identity intentionally stop '
          'Stage 3F graph analysis, so they cannot be combined with faults '
          'whose expected diagnostic is graph-owned.',
    );
  }
}

_SyntheticFaultInjectionResult _injectSyntheticFault({
  required StoryProject project,
  required SyntheticStoryFault fault,
  required int seed,
}) {
  final token = 'fault_${seed}_${fault.token}';
  final eventIndex = project.events.length;
  final eventId = StoryEventId('evt_$token');
  final choiceId = StoryChoiceId('ch_$token');
  final presentation = StoryEventPresentation(
    title: StoryText('Injected ${fault.token} fault'),
    body: StoryText('Deterministic Stage 3H fault for generator seed $seed.'),
  );

  SyntheticStoryInjectedFault metadata(String targetPath, String description) =>
      SyntheticStoryInjectedFault(
        fault: fault,
        expectedDiagnosticCode: fault.expectedDiagnosticCode,
        expectedSeverity: fault.expectedSeverity,
        targetPath: targetPath,
        description: description,
      );

  switch (fault) {
    case SyntheticStoryFault.missingDestination:
      final missingId = StoryEventId('evt_${token}_missing');
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        continuationTransition: StoryEventTransition(
          destinationEventId: missingId,
        ),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].continuationTransition.destinationEventId',
          'Continuation transition points to absent event ${missingId.value}.',
        ),
      );

    case SyntheticStoryFault.duplicateEventId:
      final duplicateId = project.events.first.id;
      final injectedEvent = StoryEvent(
        id: duplicateId,
        presentation: presentation,
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex]',
          'Appended event duplicates existing event ID ${duplicateId.value}.',
        ),
      );

    case SyntheticStoryFault.duplicateChoiceId:
      final existingChoice = project.events
          .firstWhere((event) => event.choices.isNotEmpty)
          .choices
          .first;
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        choices: [
          StoryChoice(
            id: existingChoice.id,
            presentation: const StoryChoicePresentation(
              text: StoryText('Injected duplicate choice identity'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].choices[0]',
          'Appended choice duplicates existing choice ID '
              '${existingChoice.id.value}.',
        ),
      );

    case SyntheticStoryFault.undeclaredVariableReference:
      final missingVariableId = StoryVariableId('var_${token}_missing');
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        availabilityCondition: StoryVariableIsSetCondition(
          variableId: missingVariableId,
        ),
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].availabilityCondition.variableId',
          'Condition references undeclared variable '
              '${missingVariableId.value}.',
        ),
      );

    case SyntheticStoryFault.wrongConditionValueType:
      final booleanVariable = project.stateSchema.variables.firstWhere(
        (definition) => definition.type == StoryValueType.boolean,
      );
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        availabilityCondition: StoryVariableComparisonCondition(
          variableId: booleanVariable.id,
          operator: StoryComparisonOperator.equal,
          value: StoryIntegerValue(1),
        ),
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].availabilityCondition.value',
          'Boolean variable ${booleanVariable.id.value} is compared with an '
              'Integer literal.',
        ),
      );

    case SyntheticStoryFault.wrongEffectValueType:
      final booleanVariable = project.stateSchema.variables.firstWhere(
        (definition) => definition.type == StoryValueType.boolean,
      );
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        entryEffects: [
          StorySetVariableEffect(
            variableId: booleanVariable.id,
            value: StoryIntegerValue(1),
          ),
        ],
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].entryEffects[0].value',
          'Boolean variable ${booleanVariable.id.value} is assigned an '
              'Integer value.',
        ),
      );

    case SyntheticStoryFault.missingEntryEvent:
      return _SyntheticFaultInjectionResult(
        project: StoryProject(
          id: project.id,
          alias: project.alias,
          stateSchema: project.stateSchema,
          events: project.events,
        ),
        metadata: metadata(
          'entryEventId',
          'Project entry event is deliberately removed.',
        ),
      );

    case SyntheticStoryFault.ambiguousEventFlow:
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        choices: [
          StoryChoice(
            id: choiceId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Injected ambiguous-flow choice'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex]',
          'Event has both interactive choices and a continuation transition.',
        ),
      );

    case SyntheticStoryFault.incompleteChoice:
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        choices: [
          StoryChoice(
            id: choiceId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Injected incomplete choice'),
            ),
          ),
        ],
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex].choices[0].transition',
          'Interactive choice deliberately has no transition.',
        ),
      );

    case SyntheticStoryFault.automaticCycle:
      final cycleEvent = StoryEvent(
        id: eventId,
        automaticTransition: StoryEventTransition(destinationEventId: eventId),
      );
      final entryId = project.entryEventId!;
      final entryIndex = project.events.indexWhere(
        (event) => event.id == entryId,
      );
      final entryEvent = project.events[entryIndex];
      final faultChoice = StoryChoice(
        id: choiceId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Enter injected automatic cycle'),
        ),
        transition: StoryEventTransition(destinationEventId: eventId),
      );
      final modifiedEntry = StoryEvent(
        id: entryEvent.id,
        alias: entryEvent.alias,
        presentation: entryEvent.presentation,
        availabilityCondition: entryEvent.availabilityCondition,
        entryEffects: entryEvent.entryEffects,
        choices: [...entryEvent.choices, faultChoice],
        continuationTransition: entryEvent.continuationTransition,
        automaticTransition: entryEvent.automaticTransition,
      );
      final events = project.events.toList();
      events[entryIndex] = modifiedEntry;
      events.add(cycleEvent);
      return _SyntheticFaultInjectionResult(
        project: _replaceProjectEvents(project, events),
        metadata: metadata(
          'events[$eventIndex]',
          'Reachable automatic event transitions directly to itself.',
        ),
      );

    case SyntheticStoryFault.unreachableEvent:
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        continuationTransition: const StoryTerminalTransition(),
      );
      return _SyntheticFaultInjectionResult(
        project: _appendEvent(project, injectedEvent),
        metadata: metadata(
          'events[$eventIndex]',
          'Appended event has no incoming authored transition.',
        ),
      );

    case SyntheticStoryFault.potentiallyUninitializedVariable:
      final variableId = StoryVariableId('var_${token}_unset');
      final definition = StoryVariableDefinition(
        id: variableId,
        type: StoryValueType.boolean,
      );
      final schema = StoryStateSchema(
        variables: [...project.stateSchema.variables, definition],
      );
      final injectedEvent = StoryEvent(
        id: eventId,
        presentation: presentation,
        availabilityCondition: StoryVariableComparisonCondition(
          variableId: variableId,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        ),
        continuationTransition: const StoryTerminalTransition(),
      );
      final events = [...project.events, injectedEvent];
      final malformed = StoryProject(
        id: project.id,
        alias: project.alias,
        stateSchema: schema,
        events: events,
        entryEventId: project.entryEventId,
      );
      return _SyntheticFaultInjectionResult(
        project: malformed,
        metadata: metadata(
          'stateSchema.variables[${schema.variables.length - 1}]',
          'Variable ${variableId.value} has no initial value or authored write '
              'but is read by a condition.',
        ),
      );
  }
}

StoryProject _appendEvent(StoryProject project, StoryEvent event) =>
    _replaceProjectEvents(project, [...project.events, event]);

StoryProject _replaceProjectEvents(
  StoryProject project,
  Iterable<StoryEvent> events,
) => StoryProject(
  id: project.id,
  alias: project.alias,
  stateSchema: project.stateSchema,
  events: events,
  entryEventId: project.entryEventId,
);

SyntheticStoryProjectFixture _fixture(StoryProject project) =>
    SyntheticStoryProjectFixture(
      project: project,
      metrics: analyzeSyntheticProject(project),
      signature: syntheticProjectSignature(project),
    );

StoryStateSchema _buildSchema(int variableCount, {required String prefix}) {
  final variables = <StoryVariableDefinition>[];
  for (var index = 0; index < variableCount; index++) {
    final id = _variableId(prefix, index);
    final alias = StoryAlias(
      'synthetic_${_safeAliasToken(prefix)}_var_${_pad(index)}',
    );
    final kind = index % 4;
    variables.add(switch (kind) {
      0 => StoryVariableDefinition(
        id: id,
        alias: alias,
        type: StoryValueType.boolean,
        initialValue: const StoryBooleanValue(false),
      ),
      1 => StoryVariableDefinition(
        id: id,
        alias: alias,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(index + 1),
      ),
      2 => StoryVariableDefinition(
        id: id,
        alias: alias,
        type: StoryValueType.number,
        initialValue: StoryNumberValue(index + 0.5),
      ),
      _ => StoryVariableDefinition(
        id: id,
        alias: alias,
        type: StoryValueType.string,
        initialValue: StoryStringValue('value_$index'),
      ),
    });
  }
  return StoryStateSchema(variables: variables);
}

StoryEvent _buildStructuredEvent({
  required String profileName,
  required int eventIndex,
  required int eventCount,
  required int choicesPerInteractiveEvent,
  required StoryStateSchema schema,
}) {
  final lastIndex = eventCount - 1;
  final eventId = _eventId(profileName, eventIndex);

  if (eventIndex == lastIndex) {
    return StoryEvent(
      id: eventId,
      alias: StoryAlias('synthetic_${profileName}_event_${_pad(eventIndex)}'),
      presentation: _eventPresentation(profileName, eventIndex),
      choices: [
        StoryChoice(
          id: _choiceId(profileName, eventIndex, 0),
          alias: StoryAlias(
            'synthetic_${profileName}_choice_${_pad(eventIndex)}_0',
          ),
          presentation: const StoryChoicePresentation(
            text: StoryText('Finish synthetic story'),
          ),
          transition: const StoryTerminalTransition(),
        ),
      ],
    );
  }

  final isAutomatic = eventIndex > 0 && eventIndex % 40 == 0;
  final entryEffects = <StoryEffect>[
    if (eventIndex > 0 && eventIndex % 10 == 0)
      _safeEffect(schema, eventIndex, eventIndex),
  ];
  final availabilityCondition = eventIndex > 0 && eventIndex % 30 == 0
      ? _alwaysTrueIntegerCondition(schema)
      : null;

  if (isAutomatic) {
    final transition = eventIndex % 200 == 0
        ? _forwardWeightedTransition(profileName, eventIndex, lastIndex)
        : StoryEventTransition(
            destinationEventId: _eventId(profileName, eventIndex + 1),
          );
    return StoryEvent(
      id: eventId,
      alias: StoryAlias('synthetic_${profileName}_event_${_pad(eventIndex)}'),
      presentation: _eventPresentation(profileName, eventIndex),
      availabilityCondition: availabilityCondition,
      entryEffects: entryEffects,
      automaticTransition: transition,
    );
  }

  final choices = <StoryChoice>[];
  for (
    var choiceIndex = 0;
    choiceIndex < choicesPerInteractiveEvent;
    choiceIndex++
  ) {
    choices.add(
      _buildStructuredChoice(
        profileName: profileName,
        eventIndex: eventIndex,
        choiceIndex: choiceIndex,
        choicesPerInteractiveEvent: choicesPerInteractiveEvent,
        lastEventIndex: lastIndex,
        schema: schema,
      ),
    );
  }

  return StoryEvent(
    id: eventId,
    alias: StoryAlias('synthetic_${profileName}_event_${_pad(eventIndex)}'),
    presentation: _eventPresentation(profileName, eventIndex),
    availabilityCondition: availabilityCondition,
    entryEffects: entryEffects,
    choices: choices,
  );
}

StoryChoice _buildStructuredChoice({
  required String profileName,
  required int eventIndex,
  required int choiceIndex,
  required int choicesPerInteractiveEvent,
  required int lastEventIndex,
  required StoryStateSchema schema,
}) {
  final isPrimary = choiceIndex == 0;
  final availabilityCondition = isPrimary
      ? null
      : _structuredNoiseCondition(schema, eventIndex, choiceIndex);
  final effects = <StoryEffect>[
    if ((eventIndex + choiceIndex) % 7 == 0)
      _safeEffect(schema, eventIndex + choiceIndex, eventIndex),
    if (!isPrimary &&
        choiceIndex == choicesPerInteractiveEvent - 1 &&
        eventIndex % 22 == 0)
      StoryUnsetVariableEffect(
        variableId: schema.variables[4 % schema.variables.length].id,
      ),
  ];

  final StoryTransition transition;
  if (isPrimary) {
    if (eventIndex > 0 && eventIndex % 50 == 0) {
      transition = _forwardWeightedTransition(
        profileName,
        eventIndex,
        lastEventIndex,
      );
    } else if (eventIndex > 0 && eventIndex % 15 == 0) {
      transition = StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: _alwaysTrueIntegerCondition(schema),
            transition: StoryEventTransition(
              destinationEventId: _eventId(
                profileName,
                _forwardIndex(eventIndex, 1, lastEventIndex),
              ),
            ),
          ),
        ],
        fallback: StoryEventTransition(
          destinationEventId: _eventId(
            profileName,
            _forwardIndex(eventIndex, 2, lastEventIndex),
          ),
        ),
      );
    } else {
      transition = StoryEventTransition(
        destinationEventId: _eventId(
          profileName,
          _forwardIndex(eventIndex, 1, lastEventIndex),
        ),
      );
    }
  } else if (choiceIndex == choicesPerInteractiveEvent - 1 &&
      eventIndex >= 10 &&
      eventIndex % 100 == 0) {
    transition = StoryEventTransition(
      destinationEventId: _eventId(profileName, eventIndex - 5),
    );
  } else {
    final pattern = (eventIndex + choiceIndex) % 3;
    transition = switch (pattern) {
      0 => StoryEventTransition(
        destinationEventId: _eventId(
          profileName,
          _forwardIndex(eventIndex, choiceIndex + 1, lastEventIndex),
        ),
      ),
      1 => StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: _structuredNoiseCondition(
              schema,
              eventIndex,
              choiceIndex,
            ),
            transition: StoryEventTransition(
              destinationEventId: _eventId(
                profileName,
                _forwardIndex(eventIndex, choiceIndex + 1, lastEventIndex),
              ),
            ),
          ),
        ],
        fallback: StoryEventTransition(
          destinationEventId: _eventId(
            profileName,
            _forwardIndex(eventIndex, choiceIndex + 2, lastEventIndex),
          ),
        ),
      ),
      _ => StoryWeightedTransition(
        options: [
          StoryWeightedTransitionOption(
            weight: 3,
            transition: StoryEventTransition(
              destinationEventId: _eventId(
                profileName,
                _forwardIndex(eventIndex, choiceIndex + 1, lastEventIndex),
              ),
            ),
          ),
          StoryWeightedTransitionOption(
            weight: 1,
            transition: StoryEventTransition(
              destinationEventId: _eventId(
                profileName,
                _forwardIndex(eventIndex, choiceIndex + 2, lastEventIndex),
              ),
            ),
          ),
        ],
      ),
    };
  }

  return StoryChoice(
    id: _choiceId(profileName, eventIndex, choiceIndex),
    alias: StoryAlias(
      'synthetic_${profileName}_choice_${_pad(eventIndex)}_$choiceIndex',
    ),
    presentation: StoryChoicePresentation(
      text: StoryText('Synthetic choice $choiceIndex at event $eventIndex'),
    ),
    availabilityCondition: availabilityCondition,
    effects: effects,
    transition: transition,
  );
}

StoryEvent _buildRandomizedEvent({
  required String prefix,
  required int eventIndex,
  required int eventCount,
  required StoryStateSchema schema,
  required _SyntheticRandom random,
}) {
  final lastIndex = eventCount - 1;
  final id = _eventId(prefix, eventIndex);

  if (eventIndex == lastIndex) {
    return StoryEvent(
      id: id,
      alias: StoryAlias(
        'synthetic_${_safeAliasToken(prefix)}_event_${_pad(eventIndex)}',
      ),
      presentation: _eventPresentation(prefix, eventIndex),
      choices: [
        StoryChoice(
          id: _choiceId(prefix, eventIndex, 0),
          alias: StoryAlias(
            'synthetic_${_safeAliasToken(prefix)}_choice_${_pad(eventIndex)}_0',
          ),
          presentation: const StoryChoicePresentation(
            text: StoryText('Finish randomized story'),
          ),
          transition: const StoryTerminalTransition(),
        ),
      ],
    );
  }

  final entryEffects = <StoryEffect>[];
  final entryEffectCount = random.nextInt(3);
  for (var index = 0; index < entryEffectCount; index++) {
    entryEffects.add(_safeRandomEffect(schema, random, eventIndex + index));
  }

  final isAutomatic = eventIndex > 0 && random.nextInt(10) == 0;
  if (isAutomatic) {
    return StoryEvent(
      id: id,
      alias: StoryAlias(
        'synthetic_${_safeAliasToken(prefix)}_event_${_pad(eventIndex)}',
      ),
      presentation: _eventPresentation(prefix, eventIndex),
      entryEffects: entryEffects,
      automaticTransition: random.nextBool()
          ? StoryEventTransition(
              destinationEventId: _eventId(
                prefix,
                _forwardIndex(eventIndex, 1, lastIndex),
              ),
            )
          : _forwardWeightedTransition(prefix, eventIndex, lastIndex),
    );
  }

  final choiceCount = 2 + random.nextInt(4);
  final choices = <StoryChoice>[];
  for (var choiceIndex = 0; choiceIndex < choiceCount; choiceIndex++) {
    final isPrimary = choiceIndex == 0;
    final effects = <StoryEffect>[];
    final effectCount = random.nextInt(3);
    for (var effectIndex = 0; effectIndex < effectCount; effectIndex++) {
      effects.add(
        isPrimary
            ? _safeMainEffect(schema)
            : _safeRandomEffect(schema, random, eventIndex + effectIndex),
      );
    }

    final transition = isPrimary
        ? _randomForwardTransition(
            prefix: prefix,
            eventIndex: eventIndex,
            lastEventIndex: lastIndex,
            schema: schema,
            random: random,
          )
        : _randomNoiseTransition(
            prefix: prefix,
            eventIndex: eventIndex,
            lastEventIndex: lastIndex,
            schema: schema,
            random: random,
          );

    choices.add(
      StoryChoice(
        id: _choiceId(prefix, eventIndex, choiceIndex),
        alias: StoryAlias(
          'synthetic_${_safeAliasToken(prefix)}_choice_'
          '${_pad(eventIndex)}_$choiceIndex',
        ),
        presentation: StoryChoicePresentation(
          text: StoryText(
            'Randomized choice $choiceIndex at event $eventIndex',
          ),
        ),
        availabilityCondition: isPrimary
            ? null
            : _randomCondition(schema, random, depth: 0),
        effects: effects,
        transition: transition,
      ),
    );
  }

  return StoryEvent(
    id: id,
    alias: StoryAlias(
      'synthetic_${_safeAliasToken(prefix)}_event_${_pad(eventIndex)}',
    ),
    presentation: _eventPresentation(prefix, eventIndex),
    entryEffects: entryEffects,
    choices: choices,
  );
}

StoryTransition _randomForwardTransition({
  required String prefix,
  required int eventIndex,
  required int lastEventIndex,
  required StoryStateSchema schema,
  required _SyntheticRandom random,
}) {
  final pattern = random.nextInt(3);
  return switch (pattern) {
    0 => StoryEventTransition(
      destinationEventId: _eventId(
        prefix,
        _forwardIndex(eventIndex, 1 + random.nextInt(2), lastEventIndex),
      ),
    ),
    1 => StoryConditionalTransition(
      branches: [
        StoryConditionalTransitionBranch(
          condition: _alwaysTrueIntegerCondition(schema),
          transition: StoryEventTransition(
            destinationEventId: _eventId(
              prefix,
              _forwardIndex(eventIndex, 1, lastEventIndex),
            ),
          ),
        ),
      ],
      fallback: StoryEventTransition(
        destinationEventId: _eventId(
          prefix,
          _forwardIndex(eventIndex, 2, lastEventIndex),
        ),
      ),
    ),
    _ => _forwardWeightedTransition(prefix, eventIndex, lastEventIndex),
  };
}

StoryTransition _randomNoiseTransition({
  required String prefix,
  required int eventIndex,
  required int lastEventIndex,
  required StoryStateSchema schema,
  required _SyntheticRandom random,
}) {
  if (eventIndex >= 4 && random.nextInt(8) == 0) {
    return StoryEventTransition(
      destinationEventId: _eventId(
        prefix,
        eventIndex - (1 + random.nextInt(4)),
      ),
    );
  }

  final pattern = random.nextInt(3);
  return switch (pattern) {
    0 => StoryEventTransition(
      destinationEventId: _eventId(
        prefix,
        _forwardIndex(eventIndex, 1 + random.nextInt(4), lastEventIndex),
      ),
    ),
    1 => StoryConditionalTransition(
      branches: [
        StoryConditionalTransitionBranch(
          condition: _randomCondition(schema, random, depth: 0),
          transition: StoryEventTransition(
            destinationEventId: _eventId(
              prefix,
              _forwardIndex(eventIndex, 1 + random.nextInt(3), lastEventIndex),
            ),
          ),
        ),
      ],
      fallback: StoryEventTransition(
        destinationEventId: _eventId(
          prefix,
          _forwardIndex(eventIndex, 1 + random.nextInt(4), lastEventIndex),
        ),
      ),
    ),
    _ => _forwardWeightedTransition(prefix, eventIndex, lastEventIndex),
  };
}

StoryCondition _structuredNoiseCondition(
  StoryStateSchema schema,
  int eventIndex,
  int choiceIndex,
) {
  if ((eventIndex + choiceIndex) % 5 == 0) {
    return StoryAllCondition([
      _alwaysTrueIntegerCondition(schema),
      StoryAnyCondition([
        StoryVariableComparisonCondition(
          variableId: schema.variables[0].id,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(false),
        ),
        StoryVariableComparisonCondition(
          variableId: schema.variables[3].id,
          operator: StoryComparisonOperator.equal,
          value: const StoryStringValue('value_3'),
        ),
      ]),
      StoryNotCondition(
        StoryVariableComparisonCondition(
          variableId: schema.variables[0].id,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        ),
      ),
    ]);
  }

  return switch ((eventIndex + choiceIndex) % 4) {
    0 => StoryVariableComparisonCondition(
      variableId: schema.variables[0].id,
      operator: StoryComparisonOperator.equal,
      value: const StoryBooleanValue(false),
    ),
    1 => _alwaysTrueIntegerCondition(schema),
    2 => StoryVariableComparisonCondition(
      variableId: schema.variables[2].id,
      operator: StoryComparisonOperator.greaterThanOrEqual,
      value: StoryNumberValue(0.0),
    ),
    _ => StoryVariableComparisonCondition(
      variableId: schema.variables[3].id,
      operator: StoryComparisonOperator.equal,
      value: const StoryStringValue('value_3'),
    ),
  };
}

StoryCondition _randomCondition(
  StoryStateSchema schema,
  _SyntheticRandom random, {
  required int depth,
}) {
  if (depth < 2 && random.nextInt(4) == 0) {
    return switch (random.nextInt(3)) {
      0 => StoryAllCondition([
        _randomCondition(schema, random, depth: depth + 1),
        _randomCondition(schema, random, depth: depth + 1),
      ]),
      1 => StoryAnyCondition([
        _randomCondition(schema, random, depth: depth + 1),
        _randomCondition(schema, random, depth: depth + 1),
      ]),
      _ => StoryNotCondition(
        _randomCondition(schema, random, depth: depth + 1),
      ),
    };
  }

  final definition = schema.variables[random.nextInt(schema.variables.length)];
  final initialValue = definition.initialValue!;
  return switch (definition.type) {
    StoryValueType.boolean => StoryVariableComparisonCondition(
      variableId: definition.id,
      operator: random.nextBool()
          ? StoryComparisonOperator.equal
          : StoryComparisonOperator.notEqual,
      value: initialValue,
    ),
    StoryValueType.string => StoryVariableComparisonCondition(
      variableId: definition.id,
      operator: random.nextBool()
          ? StoryComparisonOperator.equal
          : StoryComparisonOperator.notEqual,
      value: initialValue,
    ),
    StoryValueType.integer => StoryVariableComparisonCondition(
      variableId: definition.id,
      operator: _orderingOperator(random.nextInt(6)),
      value: initialValue,
    ),
    StoryValueType.number => StoryVariableComparisonCondition(
      variableId: definition.id,
      operator: _orderingOperator(random.nextInt(6)),
      value: initialValue,
    ),
  };
}

StoryComparisonOperator _orderingOperator(int value) => switch (value) {
  0 => StoryComparisonOperator.equal,
  1 => StoryComparisonOperator.notEqual,
  2 => StoryComparisonOperator.lessThan,
  3 => StoryComparisonOperator.lessThanOrEqual,
  4 => StoryComparisonOperator.greaterThan,
  _ => StoryComparisonOperator.greaterThanOrEqual,
};

StoryCondition _alwaysTrueIntegerCondition(StoryStateSchema schema) =>
    StoryVariableComparisonCondition(
      variableId: schema.variables[1].id,
      operator: StoryComparisonOperator.greaterThanOrEqual,
      value: StoryIntegerValue(0),
    );

StoryEffect _safeEffect(StoryStateSchema schema, int selector, int valueSeed) {
  final definition = schema.variables[selector % schema.variables.length];
  return _effectForDefinition(definition, valueSeed);
}

StoryEffect _safeMainEffect(StoryStateSchema schema) {
  final definition = schema.variables[1];
  return StoryIncrementVariableEffect(
    variableId: definition.id,
    amount: StoryIntegerValue(1),
  );
}

StoryEffect _safeRandomEffect(
  StoryStateSchema schema,
  _SyntheticRandom random,
  int valueSeed,
) {
  // Keep variables #0/#1 out of randomized noise so the primary route's
  // guaranteed predicates remain stable. Randomized effects never unset a
  // variable, which keeps every generated scalar adjustment executable after
  // arbitrary generated branch selections.
  final index = 2 + random.nextInt(schema.variables.length - 2);
  return _effectForDefinition(schema.variables[index], valueSeed);
}

StoryEffect _effectForDefinition(
  StoryVariableDefinition definition,
  int valueSeed,
) => switch (definition.type) {
  StoryValueType.boolean => StorySetVariableEffect(
    variableId: definition.id,
    value: StoryBooleanValue(valueSeed.isEven),
  ),
  StoryValueType.integer => StoryIncrementVariableEffect(
    variableId: definition.id,
    amount: StoryIntegerValue(1),
  ),
  StoryValueType.number => StoryIncrementVariableEffect(
    variableId: definition.id,
    amount: StoryNumberValue(0.25),
  ),
  StoryValueType.string => StorySetVariableEffect(
    variableId: definition.id,
    value: StoryStringValue('synthetic_$valueSeed'),
  ),
};

StoryWeightedTransition _forwardWeightedTransition(
  String prefix,
  int eventIndex,
  int lastEventIndex,
) => StoryWeightedTransition(
  options: [
    StoryWeightedTransitionOption(
      weight: 3,
      transition: StoryEventTransition(
        destinationEventId: _eventId(
          prefix,
          _forwardIndex(eventIndex, 1, lastEventIndex),
        ),
      ),
    ),
    StoryWeightedTransitionOption(
      weight: 1,
      transition: StoryEventTransition(
        destinationEventId: _eventId(
          prefix,
          _forwardIndex(eventIndex, 2, lastEventIndex),
        ),
      ),
    ),
  ],
);

StoryEventPresentation _eventPresentation(String prefix, int eventIndex) =>
    StoryEventPresentation(
      title: StoryText('Synthetic event $eventIndex'),
      body: StoryText(
        'Generated scale-fixture content for $prefix event $eventIndex.',
      ),
    );

int _forwardIndex(int current, int offset, int lastIndex) {
  final target = current + offset;
  return target > lastIndex ? lastIndex : target;
}

StoryEventId _eventId(String prefix, int index) =>
    StoryEventId('evt_${_safeIdToken(prefix)}_${_pad(index)}');

StoryChoiceId _choiceId(String prefix, int eventIndex, int choiceIndex) =>
    StoryChoiceId(
      'ch_${_safeIdToken(prefix)}_${_pad(eventIndex)}_${_pad(choiceIndex, 2)}',
    );

StoryVariableId _variableId(String prefix, int index) =>
    StoryVariableId('var_${_safeIdToken(prefix)}_${_pad(index)}');

String _pad(int value, [int width = 4]) => value.toString().padLeft(width, '0');

String _safeIdToken(String value) =>
    value.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');

String _safeAliasToken(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');

/// Computes deterministic structural metrics using only public story model
/// data.
SyntheticStoryMetrics analyzeSyntheticProject(StoryProject project) {
  final eventIndexes = <StoryEventId, int>{
    for (var index = 0; index < project.events.length; index++)
      project.events[index].id: index,
  };
  final accumulator = _MetricsAccumulator(
    eventCount: project.events.length,
    variableCount: project.stateSchema.variables.length,
  );

  for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
    final event = project.events[eventIndex];
    if (event.automaticTransition != null) {
      accumulator.automaticEventCount++;
    }
    _inspectCondition(
      event.availabilityCondition,
      project.stateSchema,
      accumulator,
      depth: 1,
    );
    for (final effect in event.entryEffects) {
      _inspectEffect(effect, project.stateSchema, accumulator);
    }
    for (final choice in event.choices) {
      accumulator.choiceCount++;
      _inspectCondition(
        choice.availabilityCondition,
        project.stateSchema,
        accumulator,
        depth: 1,
      );
      for (final effect in choice.effects) {
        _inspectEffect(effect, project.stateSchema, accumulator);
      }
      final transition = choice.transition;
      if (transition != null) {
        _inspectTransition(
          transition,
          sourceEventIndex: eventIndex,
          eventIndexes: eventIndexes,
          schema: project.stateSchema,
          accumulator: accumulator,
        );
      }
    }
    final automaticTransition = event.automaticTransition;
    if (automaticTransition != null) {
      _inspectTransition(
        automaticTransition,
        sourceEventIndex: eventIndex,
        eventIndexes: eventIndexes,
        schema: project.stateSchema,
        accumulator: accumulator,
      );
    }
  }

  return accumulator.freeze();
}

void _inspectTransition(
  StoryTransition transition, {
  required int sourceEventIndex,
  required Map<StoryEventId, int> eventIndexes,
  required StoryStateSchema schema,
  required _MetricsAccumulator accumulator,
}) {
  switch (transition) {
    case StoryEventTransition(:final destinationEventId):
      accumulator.directTransitionCount++;
      final destinationIndex = eventIndexes[destinationEventId];
      if (destinationIndex == null) {
        accumulator.missingDestinationCount++;
      } else if (destinationIndex < sourceEventIndex) {
        accumulator.backwardDestinationCount++;
      }
    case StoryConditionalTransition(:final branches, :final fallback):
      accumulator.conditionalTransitionCount++;
      for (final branch in branches) {
        _inspectCondition(branch.condition, schema, accumulator, depth: 1);
        _inspectTransition(
          branch.transition,
          sourceEventIndex: sourceEventIndex,
          eventIndexes: eventIndexes,
          schema: schema,
          accumulator: accumulator,
        );
      }
      _inspectTransition(
        fallback,
        sourceEventIndex: sourceEventIndex,
        eventIndexes: eventIndexes,
        schema: schema,
        accumulator: accumulator,
      );
    case StoryWeightedTransition(:final options):
      accumulator.weightedTransitionCount++;
      for (final option in options) {
        _inspectTransition(
          option.transition,
          sourceEventIndex: sourceEventIndex,
          eventIndexes: eventIndexes,
          schema: schema,
          accumulator: accumulator,
        );
      }
    case StoryTerminalTransition():
      accumulator.terminalTransitionCount++;
  }
}

void _inspectCondition(
  StoryCondition? condition,
  StoryStateSchema schema,
  _MetricsAccumulator accumulator, {
  required int depth,
}) {
  if (condition == null) {
    return;
  }
  accumulator.conditionNodeCount++;
  if (depth > accumulator.maxConditionDepth) {
    accumulator.maxConditionDepth = depth;
  }

  switch (condition) {
    case StoryAllCondition(:final conditions):
      for (final child in conditions) {
        _inspectCondition(child, schema, accumulator, depth: depth + 1);
      }
    case StoryAnyCondition(:final conditions):
      for (final child in conditions) {
        _inspectCondition(child, schema, accumulator, depth: depth + 1);
      }
    case StoryNotCondition(:final condition):
      _inspectCondition(condition, schema, accumulator, depth: depth + 1);
    case StoryVariableIsSetCondition(:final variableId):
      if (!schema.contains(variableId)) {
        accumulator.invalidVariableReferenceCount++;
      }
    case StoryVariableIsUnsetCondition(:final variableId):
      if (!schema.contains(variableId)) {
        accumulator.invalidVariableReferenceCount++;
      }
    case StoryVariableComparisonCondition(
      :final variableId,
      value: final comparisonValue,
    ):
      final definition = schema.definitionFor(variableId);
      if (definition == null || definition.type != comparisonValue.type) {
        accumulator.invalidVariableReferenceCount++;
      }
  }
}

void _inspectEffect(
  StoryEffect effect,
  StoryStateSchema schema,
  _MetricsAccumulator accumulator,
) {
  accumulator.effectCount++;
  switch (effect) {
    case StorySetVariableEffect(:final variableId, :final value):
      final definition = schema.definitionFor(variableId);
      if (definition == null || definition.type != value.type) {
        accumulator.invalidVariableReferenceCount++;
      }
    case StoryUnsetVariableEffect(:final variableId):
      if (!schema.contains(variableId)) {
        accumulator.invalidVariableReferenceCount++;
      }
    case StoryIncrementVariableEffect(:final variableId, :final amount):
      final definition = schema.definitionFor(variableId);
      if (definition == null || definition.type != amount.type) {
        accumulator.invalidVariableReferenceCount++;
      }
    case StoryDecrementVariableEffect(:final variableId, :final amount):
      final definition = schema.definitionFor(variableId);
      if (definition == null || definition.type != amount.type) {
        accumulator.invalidVariableReferenceCount++;
      }
  }
}

/// Produces a deterministic signature from the public authored model.
String syntheticProjectSignature(StoryProject project) {
  final buffer = StringBuffer()
    ..write('P|${project.id.value}|${project.alias?.value}|')
    ..write('${project.entryEventId?.value};');

  for (final definition in project.stateSchema.variables) {
    buffer
      ..write('V|${definition.id.value}|${definition.alias?.value}|')
      ..write('${definition.type.name}|')
      ..write('${_valueSignature(definition.initialValue)};');
  }

  for (final event in project.events) {
    buffer
      ..write('E|${event.id.value}|${event.alias?.value}|')
      ..write('${event.presentation?.title?.value}|')
      ..write('${event.presentation?.body?.value}|')
      ..write('${_conditionSignature(event.availabilityCondition)}|');
    for (final effect in event.entryEffects) {
      buffer.write('EE:${_effectSignature(effect)}|');
    }
    for (final choice in event.choices) {
      buffer
        ..write('C|${choice.id.value}|${choice.alias?.value}|')
        ..write('${choice.presentation?.text.value}|')
        ..write('${_conditionSignature(choice.availabilityCondition)}|');
      for (final effect in choice.effects) {
        buffer.write('CE:${_effectSignature(effect)}|');
      }
      buffer.write('T:${_transitionSignature(choice.transition)};');
    }
    buffer
      ..write('CT:${_transitionSignature(event.continuationTransition)};')
      ..write('AT:${_transitionSignature(event.automaticTransition)};');
  }

  return buffer.toString();
}

String _conditionSignature(StoryCondition? condition) => switch (condition) {
  null => '-',
  StoryAllCondition(:final conditions) =>
    'ALL(${conditions.map(_conditionSignature).join(',')})',
  StoryAnyCondition(:final conditions) =>
    'ANY(${conditions.map(_conditionSignature).join(',')})',
  StoryNotCondition(:final condition) =>
    'NOT(${_conditionSignature(condition)})',
  StoryVariableIsSetCondition(:final variableId) => 'SET(${variableId.value})',
  StoryVariableIsUnsetCondition(:final variableId) =>
    'UNSET(${variableId.value})',
  StoryVariableComparisonCondition(
    :final variableId,
    :final operator,
    :final value,
  ) =>
    'CMP(${variableId.value},${operator.name},${_valueSignature(value)})',
};

String _effectSignature(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect(:final variableId, :final value) =>
    'SET(${variableId.value},${_valueSignature(value)})',
  StoryUnsetVariableEffect(:final variableId) => 'UNSET(${variableId.value})',
  StoryIncrementVariableEffect(:final variableId, :final amount) =>
    'INC(${variableId.value},${_valueSignature(amount)})',
  StoryDecrementVariableEffect(:final variableId, :final amount) =>
    'DEC(${variableId.value},${_valueSignature(amount)})',
};

String _transitionSignature(StoryTransition? transition) =>
    switch (transition) {
      null => '-',
      StoryEventTransition(:final destinationEventId) =>
        'GO(${destinationEventId.value})',
      StoryConditionalTransition(:final branches, :final fallback) =>
        _conditionalTransitionSignature(branches, fallback),
      StoryWeightedTransition(:final options) => _weightedTransitionSignature(
        options,
      ),
      StoryTerminalTransition() => 'END',
    };

String _conditionalTransitionSignature(
  List<StoryConditionalTransitionBranch> branches,
  StoryTransition fallback,
) {
  final branchSignatures = branches.map(
    (branch) =>
        '${_conditionSignature(branch.condition)}=>'
        '${_transitionSignature(branch.transition)}',
  );
  return 'IF(${branchSignatures.join(',')}|'
      'ELSE:${_transitionSignature(fallback)})';
}

String _weightedTransitionSignature(
  List<StoryWeightedTransitionOption> options,
) {
  final optionSignatures = options.map(
    (option) => '${option.weight}:${_transitionSignature(option.transition)}',
  );
  return 'WEIGHT(${optionSignatures.join(',')})';
}

String _valueSignature(StoryValue? value) => switch (value) {
  null => 'unset',
  StoryBooleanValue(:final value) => 'b:$value',
  StoryIntegerValue(:final value) => 'i:$value',
  StoryNumberValue(:final value) => 'n:$value',
  StoryStringValue(:final value) => 's:$value',
};

final class _MetricsAccumulator {
  _MetricsAccumulator({required this.eventCount, required this.variableCount});

  final int eventCount;
  final int variableCount;
  int choiceCount = 0;
  int automaticEventCount = 0;
  int directTransitionCount = 0;
  int conditionalTransitionCount = 0;
  int weightedTransitionCount = 0;
  int terminalTransitionCount = 0;
  int conditionNodeCount = 0;
  int maxConditionDepth = 0;
  int effectCount = 0;
  int backwardDestinationCount = 0;
  int missingDestinationCount = 0;
  int invalidVariableReferenceCount = 0;

  SyntheticStoryMetrics freeze() => SyntheticStoryMetrics(
    eventCount: eventCount,
    choiceCount: choiceCount,
    variableCount: variableCount,
    automaticEventCount: automaticEventCount,
    directTransitionCount: directTransitionCount,
    conditionalTransitionCount: conditionalTransitionCount,
    weightedTransitionCount: weightedTransitionCount,
    terminalTransitionCount: terminalTransitionCount,
    conditionNodeCount: conditionNodeCount,
    maxConditionDepth: maxConditionDepth,
    effectCount: effectCount,
    backwardDestinationCount: backwardDestinationCount,
    missingDestinationCount: missingDestinationCount,
    invalidVariableReferenceCount: invalidVariableReferenceCount,
  );
}

/// Small deterministic PRNG owned by the test generator.
///
/// We avoid `dart:math Random` so fixture topology remains stable even if Dart
/// changes its implementation in a future SDK.
final class _SyntheticRandom {
  _SyntheticRandom(int seed) : _state = seed & 0xffffffff;

  int _state;

  int _nextUint32() {
    _state = (1664525 * _state + 1013904223) & 0xffffffff;
    return _state;
  }

  int nextInt(int upperExclusive) {
    if (upperExclusive <= 0) {
      throw ArgumentError.value(
        upperExclusive,
        'upperExclusive',
        'Random upper bound must be positive.',
      );
    }
    return _nextUint32() % upperExclusive;
  }

  bool nextBool() => (_nextUint32() & 1) == 0;
}
