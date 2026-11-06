import 'dart:async';

import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_module_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import 'story_module_loader.dart';
import 'story_module_validator.dart';
import 'story_narrative_module.dart';
import 'story_project_index.dart';

/// Bounded verified cache over a host-provided [StoryModuleLoader].
///
/// Loading, prefetching, cache hits, and eviction are operational concerns only;
/// they must not change narrative behavior. Loaded modules are verified against
/// the global index before becoming observable through this cache.
final class StoryModuleCache {
  StoryModuleCache({
    required this.index,
    required this.loader,
    this.maxCachedModules = 32,
    StoryModuleValidator validator = const StoryModuleValidator(),
  }) : _validator = validator {
    if (maxCachedModules <= 0) {
      throw ArgumentError.value(
        maxCachedModules,
        'maxCachedModules',
        'Module cache capacity must be greater than zero.',
      );
    }
    final report = _validator.validateIndex(index);
    if (!report.isValid) {
      throw StoryModuleLoadException(
        message:
            'Cannot create a module cache for an invalid project index '
            '(${report.issues.length} issue(s)).',
      );
    }
  }

  /// Lightweight project index used to verify loaded content.
  final StoryProjectIndex index;

  /// Host-provided module loading implementation.
  final StoryModuleLoader loader;

  /// Maximum number of module bodies retained by this cache.
  final int maxCachedModules;

  final StoryModuleValidator _validator;
  final Map<StoryModuleId, StoryNarrativeModule> _cache =
      <StoryModuleId, StoryNarrativeModule>{};
  final Map<StoryModuleId, Future<StoryNarrativeModule>> _inFlight =
      <StoryModuleId, Future<StoryNarrativeModule>>{};

  /// Cached module IDs from least-recently used to most-recently used.
  List<StoryModuleId> get cachedModuleIds =>
      List<StoryModuleId>.unmodifiable(_cache.keys);

  /// Whether a verified module body is currently cached.
  bool isCached(StoryModuleId moduleId) => _cache.containsKey(moduleId);

  /// Returns a cached module and marks it most-recently used, or null.
  StoryNarrativeModule? moduleIfCached(StoryModuleId moduleId) {
    final cached = _cache.remove(moduleId);
    if (cached == null) {
      return null;
    }
    _cache[moduleId] = cached;
    return cached;
  }

  /// Loads and verifies one module, reusing completed or in-flight work.
  ///
  /// Concurrent misses for the same stable module ID share one load and
  /// verification operation. Different IDs remain independent. A failed load
  /// or verification is never retained as a completed cache entry or poisoned
  /// flight, so a later request may retry normally.
  ///
  /// Eviction and [clear] affect completed cached bodies only. An already
  /// started load remains in flight and may populate the cache after the
  /// eviction/clear operation completes.
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId) async {
    final descriptor = index.moduleFor(moduleId);
    if (descriptor == null) {
      throw StoryModuleLoadException(
        message: 'Unknown narrative module ${moduleId.value}.',
      );
    }

    final cached = moduleIfCached(moduleId);
    if (cached != null) {
      return cached;
    }

    final pending = _inFlight[moduleId];
    if (pending != null) {
      return pending;
    }

    final completer = Completer<StoryNarrativeModule>();
    final sharedFuture = completer.future;
    _inFlight[moduleId] = sharedFuture;

    // Register the placeholder before invoking host loader code. A loader may
    // synchronously reenter this cache; a non-awaited same-ID request must join
    // the operation that is already responsible for producing that module.
    unawaited(
      _completeLoadFlight(
        moduleId: moduleId,
        descriptorId: descriptor.id,
        sharedFuture: sharedFuture,
        completer: completer,
      ),
    );
    return sharedFuture;
  }

  Future<void> _completeLoadFlight({
    required StoryModuleId moduleId,
    required StoryModuleId descriptorId,
    required Future<StoryNarrativeModule> sharedFuture,
    required Completer<StoryNarrativeModule> completer,
  }) async {
    try {
      late final StoryNarrativeModule loaded;
      try {
        loaded = await loader.loadModule(moduleId);
      } catch (error, stackTrace) {
        if (error is StoryModuleLoadException) {
          _finishFlightError(
            moduleId: moduleId,
            sharedFuture: sharedFuture,
            completer: completer,
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
        _finishFlightError(
          moduleId: moduleId,
          sharedFuture: sharedFuture,
          completer: completer,
          error: StoryModuleLoadException(
            message: 'Failed to load narrative module ${moduleId.value}.',
            cause: error,
          ),
          stackTrace: stackTrace,
        );
        return;
      }

      if (loaded.id != descriptorId) {
        _finishFlightError(
          moduleId: moduleId,
          sharedFuture: sharedFuture,
          completer: completer,
          error: StoryModuleLoadException(
            message:
                'Loader returned module ${loaded.id.value} while '
                '${moduleId.value} was requested.',
          ),
          stackTrace: StackTrace.current,
        );
        return;
      }

      final report = _validator.validateModule(index: index, module: loaded);
      if (!report.isValid) {
        _finishFlightError(
          moduleId: moduleId,
          sharedFuture: sharedFuture,
          completer: completer,
          error: StoryModuleLoadException(
            message:
                'Loaded module ${moduleId.value} does not match the '
                'project index (${report.issues.length} issue(s)).',
          ),
          stackTrace: StackTrace.current,
        );
        return;
      }

      _cache[moduleId] = loaded;
      _enforceCapacity();
      _removeFlight(moduleId, sharedFuture);
      completer.complete(loaded);
    } catch (error, stackTrace) {
      // Keep this internal driver from ever exposing a second unhandled error
      // future. Any unexpected failure is delivered through the one public
      // shared operation, after its flight entry has been removed.
      _finishFlightError(
        moduleId: moduleId,
        sharedFuture: sharedFuture,
        completer: completer,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _finishFlightError({
    required StoryModuleId moduleId,
    required Future<StoryNarrativeModule> sharedFuture,
    required Completer<StoryNarrativeModule> completer,
    required Object error,
    required StackTrace stackTrace,
  }) {
    _removeFlight(moduleId, sharedFuture);
    completer.completeError(error, stackTrace);
  }

  void _removeFlight(
    StoryModuleId moduleId,
    Future<StoryNarrativeModule> sharedFuture,
  ) {
    if (identical(_inFlight[moduleId], sharedFuture)) {
      _inFlight.remove(moduleId);
    }
  }

  /// Eagerly loads modules using normal verified cache semantics.
  ///
  /// Prefetch is intentionally equivalent to future demand loading except for
  /// timing; it cannot change which module data the runtime observes.
  Future<void> prefetch(Iterable<StoryModuleId> moduleIds) async {
    for (final moduleId in moduleIds) {
      await loadModule(moduleId);
    }
  }

  /// Removes one completed cached module body without affecting project/index
  /// semantics. An in-flight load is not cancelled and may populate the cache
  /// after this call.
  bool evict(StoryModuleId moduleId) => _cache.remove(moduleId) != null;

  /// Removes all completed cached module bodies. Pending loads continue and may
  /// populate the cache after this call.
  void clear() => _cache.clear();

  /// Loads a module and the complete transitive dependency closure.
  ///
  /// Traversal is deterministic depth-first order following each descriptor's
  /// authored dependency order. Cycles are permitted and visited once.
  Future<List<StoryNarrativeModule>> loadDependencyClosure(
    StoryModuleId rootModuleId,
  ) async {
    final result = <StoryNarrativeModule>[];
    final visited = <StoryModuleId>{};

    Future<void> visit(StoryModuleId moduleId) async {
      if (!visited.add(moduleId)) {
        return;
      }
      final module = await loadModule(moduleId);
      result.add(module);
      final descriptor = index.moduleFor(moduleId)!;
      for (final dependency in descriptor.dependencies) {
        await visit(dependency);
      }
    }

    await visit(rootModuleId);
    return List<StoryNarrativeModule>.unmodifiable(result);
  }

  /// Materializes an executable project slice rooted at one module.
  ///
  /// Only the requested module and its declared dependency closure are loaded.
  /// If the indexed conventional default entry is present in that closure, it
  /// remains the slice default; otherwise the derived slice has no default
  /// entry and callers use `StoryEngine.startAt(...)`.
  Future<StoryProject> materializeProjectForModule(
    StoryModuleId moduleId,
  ) async {
    final modules = await loadDependencyClosure(moduleId);
    return _projectFromModules(modules: modules);
  }

  /// Materializes the dependency closure needed by one stable event.
  ///
  /// The returned derived project's default entry is the requested event so it
  /// can be passed directly to existing validation/runtime APIs. This does not
  /// modify authored project metadata.
  Future<StoryProject> materializeProjectForEvent(StoryEventId eventId) async {
    final indexedEvent = index.eventFor(eventId);
    if (indexedEvent == null) {
      throw StoryModuleLoadException(
        message: 'Unknown indexed event ${eventId.value}.',
      );
    }
    final modules = await loadDependencyClosure(indexedEvent.moduleId);
    return _projectFromModules(modules: modules, entryEventId: eventId);
  }

  /// Materializes the dependency closure required by one stable entry point.
  Future<StoryProject> materializeProjectForEntryPoint(
    StoryEntryPointId entryPointId,
  ) async {
    final entryPoint = index.entryPointFor(entryPointId);
    if (entryPoint == null) {
      throw StoryModuleLoadException(
        message: 'Unknown narrative entry point ${entryPointId.value}.',
      );
    }
    return materializeProjectForEvent(entryPoint.eventId);
  }

  StoryProject _projectFromModules({
    required List<StoryNarrativeModule> modules,
    StoryEventId? entryEventId,
  }) {
    final events = <StoryEvent>[for (final module in modules) ...module.events];
    final availableIds = <StoryEventId>{for (final event in events) event.id};
    final requestedDefault = entryEventId ?? index.defaultEntryEventId;
    final effectiveDefault =
        requestedDefault != null && availableIds.contains(requestedDefault)
        ? requestedDefault
        : null;

    return StoryProject(
      id: index.projectId,
      stateSchema: index.stateSchema,
      events: events,
      entryEventId: effectiveDefault,
    );
  }

  void _enforceCapacity() {
    while (_cache.length > maxCachedModules) {
      _cache.remove(_cache.keys.first);
    }
  }
}
