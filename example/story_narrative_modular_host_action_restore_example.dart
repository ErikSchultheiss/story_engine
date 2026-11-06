import 'package:story_engine/story_engine.dart';

final _projectId = StoryProjectId('modular_host_action_restore_example');
final _dialogueModuleId = StoryModuleId('module_village_dialogue');
final _sharedModuleId = StoryModuleId('module_shared_outcome');
final _unrelatedModuleId = StoryModuleId('module_unrelated');
final _dialogueEventId = StoryEventId('blacksmith_dialogue');
final _sharedEventId = StoryEventId('market_ready');
final _unrelatedEventId = StoryEventId('unrelated_event');
final _entryPointId = StoryEntryPointId('blacksmith');

/// Runs the modular host-action aggregate-restore walkthrough.
///
/// [log] exists so the package test suite can exercise the same source while
/// keeping normal `dart run` output deterministic.
Future<void> runModularHostActionRestoreExample({
  void Function(Object?)? log,
}) async {
  final void Function(Object?) write = log ?? print;
  final index = buildModularHostActionExampleIndex();
  final loader = ExampleModuleLoader(buildModularHostActionExampleModules());
  final cache = StoryModuleCache(index: index, loader: loader);
  final project = await cache.materializeProjectForEntryPoint(_entryPointId);
  final entryPoints = index.entryPoints;

  final validation = StoryValidator.validate(
    project,
    additionalEntryEventIds: entryPoints.map((entry) => entry.eventId),
  );
  write('Validation: ${validation.summary}');
  if (validation.hasErrors) {
    write(validation.format());
    return;
  }

  write('Loaded modules: ${_moduleIds(loader.loads)}');
  write('Materialized events: ${_eventIds(project.events)}');

  final runtime = StoryNarrativeRuntime(
    project: project,
    entryPoints: entryPoints,
  );
  final session = runtime.startSession(_entryPointId);
  write('Session status before host work: ${session.sessionStatus.name}');

  final host = _ExampleExternalHost(write);
  final request = session.requestHostAction(
    schemaNamespace: 'com.example.world',
    actionId: 'load_market_scene',
    arguments: const {'area': 'market'},
    resultType: const StoryHostActionValueType.boolean(),
  );
  host.dispatch(request);

  write('Session status while pending: ${session.sessionStatus.name}');
  write('Pending request before save: ${request.id.value}');

  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final snapshotJson = codec.encodeJson(runtime.createSnapshot());
  write('Saved aggregate snapshot: ${snapshotJson.length} JSON characters');

  final restoredObserver = _RequestedActionObserver();
  final decoded = codec.decodeJson(
    snapshotJson,
    project: project,
    entryPoints: entryPoints,
  );
  final restored = StoryNarrativeRuntime.restore(
    project: project,
    entryPoints: entryPoints,
    snapshot: decoded,
    observers: [restoredObserver],
  );
  final restoredSession = restored.sessionByIndex(session.index);
  final restoredRequest = restoredSession.pendingHostAction;
  if (restoredRequest == null) {
    throw StateError('The restored session lost its pending host action.');
  }

  write('Restored session status: ${restoredSession.sessionStatus.name}');
  write('Restored pending request: ${restoredRequest.id.value}');
  write(
    'Host-action requests replayed during restore: '
    '${restoredObserver.requestedCount}',
  );

  host.reconcile(restoredRequest);
  write('External dispatch count after restore: ${host.dispatchCount}');

  restored.applyInput(
    StoryNarrativeHostActionCompletedInput(
      sessionIndex: restoredSession.index,
      requestId: restoredRequest.id,
      value: true,
    ),
  );
  write('Status after host result: ${restoredSession.sessionStatus.name}');

  restored.applyInput(
    StoryNarrativeContinueInput(sessionIndex: restoredSession.index),
  );
  write(
    'Current event after continue: ${restoredSession.currentEvent?.id.value}',
  );

  restored.applyInput(
    StoryNarrativeContinueInput(sessionIndex: restoredSession.index),
  );
  write('Finished status: ${restoredSession.sessionStatus.name}');
}

/// Lightweight modular index used by the Example 3 integration walkthrough.
StoryProjectIndex buildModularHostActionExampleIndex() {
  return StoryProjectIndex(
    projectId: _projectId,
    stateSchema: StoryStateSchema.empty(),
    modules: [
      StoryModuleIndexEntry(
        id: _dialogueModuleId,
        dependencies: [_sharedModuleId],
      ),
      StoryModuleIndexEntry(id: _sharedModuleId),
      StoryModuleIndexEntry(id: _unrelatedModuleId),
    ],
    events: [
      StoryEventIndexEntry(
        id: _dialogueEventId,
        moduleId: _dialogueModuleId,
        outboundEventIds: [_sharedEventId],
      ),
      StoryEventIndexEntry(id: _sharedEventId, moduleId: _sharedModuleId),
      StoryEventIndexEntry(id: _unrelatedEventId, moduleId: _unrelatedModuleId),
    ],
    entryPoints: [
      StoryEntryPoint(id: _entryPointId, eventId: _dialogueEventId),
    ],
  );
}

/// In-memory module bodies used only to keep the runnable example self-contained.
Map<StoryModuleId, StoryNarrativeModule>
buildModularHostActionExampleModules() {
  return <StoryModuleId, StoryNarrativeModule>{
    _dialogueModuleId: StoryNarrativeModule(
      projectId: _projectId,
      id: _dialogueModuleId,
      events: [
        StoryEvent(
          id: _dialogueEventId,
          presentation: StoryEventPresentation(
            title: const StoryText('Village Blacksmith'),
            body: const StoryText(
              'The blacksmith asks the host to prepare the market scene.',
            ),
          ),
          continuationTransition: StoryEventTransition(
            destinationEventId: _sharedEventId,
          ),
        ),
      ],
    ),
    _sharedModuleId: StoryNarrativeModule(
      projectId: _projectId,
      id: _sharedModuleId,
      events: [
        StoryEvent(
          id: _sharedEventId,
          presentation: StoryEventPresentation(
            title: const StoryText('Market Ready'),
            body: const StoryText('The prepared market scene is ready.'),
          ),
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    ),
    _unrelatedModuleId: StoryNarrativeModule(
      projectId: _projectId,
      id: _unrelatedModuleId,
      events: [
        StoryEvent(
          id: _unrelatedEventId,
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    ),
  };
}

/// Small storage-neutral loader used by this self-contained example.
final class ExampleModuleLoader implements StoryModuleLoader {
  ExampleModuleLoader(this.modules);

  final Map<StoryModuleId, StoryNarrativeModule> modules;
  final List<StoryModuleId> loads = <StoryModuleId>[];

  @override
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId) async {
    loads.add(moduleId);
    final module = modules[moduleId];
    if (module == null) {
      throw StoryModuleLoadException(
        message: 'Example module ${moduleId.value} is unavailable.',
      );
    }
    return module;
  }
}

final class _ExampleExternalHost {
  _ExampleExternalHost(this._write);

  final void Function(Object?) _write;
  final Set<StoryHostActionRequestId> _dispatched =
      <StoryHostActionRequestId>{};
  int dispatchCount = 0;

  void dispatch(StoryHostActionRequest request) {
    if (!_dispatched.add(request.id)) {
      throw StateError('Host work ${request.id} was dispatched twice.');
    }
    dispatchCount++;
    _write('External dispatch #$dispatchCount: ${request.id.value}');
  }

  void reconcile(StoryHostActionRequest request) {
    if (!_dispatched.contains(request.id)) {
      throw StateError(
        'The restored request ${request.id} has no matching external work.',
      );
    }
    _write('Reconciled existing request: ${request.id.value}');
  }
}

final class _RequestedActionObserver implements StoryNarrativeObserver {
  int requestedCount = 0;

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    if (observation is StoryNarrativeHostActionRequested) {
      requestedCount++;
    }
  }
}

String _moduleIds(Iterable<StoryModuleId> moduleIds) =>
    moduleIds.map((id) => id.value).join(', ');

String _eventIds(Iterable<StoryEvent> events) =>
    events.map((event) => event.id.value).join(', ');

Future<void> main() async {
  await runModularHostActionRestoreExample();
}
