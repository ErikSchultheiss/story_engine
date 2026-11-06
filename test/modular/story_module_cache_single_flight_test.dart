import 'dart:async';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryModuleCache single-flight', () {
    test('overlapping equal module IDs share one verified load', () async {
      final fixture = _Fixture.single('module_a');
      final pending = Completer<StoryNarrativeModule>();
      final loader = _CallbackLoader((_) => pending.future);
      final cache = fixture.cache(loader: loader);

      final requests = <Future<StoryNarrativeModule>>[
        cache.loadModule(fixture.moduleIds.single),
        cache.loadModule(StoryModuleId('module_a')),
        cache.loadModule(StoryModuleId('module_a')),
        cache.loadModule(StoryModuleId('module_a')),
      ];

      expect(loader.calls, hasLength(1));
      expect(cache.cachedModuleIds, isEmpty);
      expect(cache.isCached(fixture.moduleIds.single), isFalse);
      expect(cache.moduleIfCached(fixture.moduleIds.single), isNull);

      pending.complete(fixture.modules[fixture.moduleIds.single]!);
      final results = await Future.wait(requests);

      expect(loader.calls, [fixture.moduleIds.single]);
      expect(
        results.every((module) => identical(module, results.first)),
        isTrue,
      );
      expect(cache.isCached(fixture.moduleIds.single), isTrue);
    });

    test(
      'different IDs remain parallel and completion order controls capacity-one residency',
      () async {
        for (final completionOrder in <List<String>>[
          <String>['module_a', 'module_b'],
          <String>['module_b', 'module_a'],
        ]) {
          final fixture = _Fixture.multiple(<String>['module_a', 'module_b']);
          final pending = <StoryModuleId, Completer<StoryNarrativeModule>>{
            for (final id in fixture.moduleIds)
              id: Completer<StoryNarrativeModule>(),
          };
          final loader = _CallbackLoader(
            (moduleId) => pending[moduleId]!.future,
          );
          final cache = fixture.cache(loader: loader, maxCachedModules: 1);

          final a = cache.loadModule(StoryModuleId('module_a'));
          final b = cache.loadModule(StoryModuleId('module_b'));
          expect(loader.calls.map((id) => id.value).toSet(), <String>{
            'module_a',
            'module_b',
          });

          for (final token in completionOrder) {
            final id = StoryModuleId(token);
            pending[id]!.complete(fixture.modules[id]!);
            await (token == 'module_a' ? a : b);
          }
          await Future.wait(<Future<StoryNarrativeModule>>[a, b]);

          expect(cache.cachedModuleIds.single.value, completionOrder.last);
        }
      },
    );

    test('cache hit keeps LRU behavior after single-flight success', () async {
      final fixture = _Fixture.multiple(<String>[
        'module_a',
        'module_b',
        'module_c',
      ]);
      final loader = _CallbackLoader(
        (moduleId) async => fixture.modules[moduleId]!,
      );
      final cache = fixture.cache(loader: loader, maxCachedModules: 2);

      await cache.loadModule(StoryModuleId('module_a'));
      await cache.loadModule(StoryModuleId('module_b'));
      await cache.loadModule(StoryModuleId('module_a'));
      expect(cache.cachedModuleIds.map((id) => id.value), <String>[
        'module_b',
        'module_a',
      ]);

      await cache.loadModule(StoryModuleId('module_c'));
      expect(cache.cachedModuleIds.map((id) => id.value), <String>[
        'module_a',
        'module_c',
      ]);
      expect(loader.calls.map((id) => id.value), <String>[
        'module_a',
        'module_b',
        'module_c',
      ]);
    });

    test(
      'generic asynchronous failure is shared once and preserves its cause',
      () async {
        final fixture = _Fixture.single('module_a');
        final pending = Completer<StoryNarrativeModule>();
        final loader = _CallbackLoader((_) => pending.future);
        final cache = fixture.cache(loader: loader);
        final requests = <Future<StoryNarrativeModule>>[
          cache.loadModule(StoryModuleId('module_a')),
          cache.loadModule(StoryModuleId('module_a')),
          cache.loadModule(StoryModuleId('module_a')),
        ];
        final captured = requests.map(_captureError).toList();
        final cause = StateError('loader failed');

        pending.completeError(cause, StackTrace.current);
        final errors = await Future.wait(captured);

        expect(loader.calls, hasLength(1));
        expect(errors.every((error) => identical(error, errors.first)), isTrue);
        final error = errors.first as StoryModuleLoadException;
        expect(identical(error.cause, cause), isTrue);
        expect(cache.cachedModuleIds, isEmpty);
      },
    );

    test(
      'existing StoryModuleLoadException keeps identity for all waiters',
      () async {
        final fixture = _Fixture.single('module_a');
        final pending = Completer<StoryNarrativeModule>();
        final loader = _CallbackLoader((_) => pending.future);
        final cache = fixture.cache(loader: loader);
        final expected = StoryModuleLoadException(message: 'expected failure');
        final captured = <Future<Object>>[
          _captureError(cache.loadModule(StoryModuleId('module_a'))),
          _captureError(cache.loadModule(StoryModuleId('module_a'))),
        ];

        pending.completeError(expected, StackTrace.current);
        final errors = await Future.wait(captured);

        expect(loader.calls, hasLength(1));
        expect(errors.every((error) => identical(error, expected)), isTrue);
      },
    );

    test(
      'synchronous loader throw becomes one future failure and is retryable',
      () async {
        final fixture = _Fixture.single('module_a');
        final expected = StoryModuleLoadException(message: 'sync failure');
        var shouldFail = true;
        final loader = _CallbackLoader((moduleId) {
          if (shouldFail) {
            shouldFail = false;
            throw expected;
          }
          return Future<StoryNarrativeModule>.value(fixture.modules[moduleId]!);
        });
        final cache = fixture.cache(loader: loader);

        final error = await _captureError(
          cache.loadModule(StoryModuleId('module_a')),
        );
        expect(identical(error, expected), isTrue);
        expect(cache.isCached(StoryModuleId('module_a')), isFalse);

        final module = await cache.loadModule(StoryModuleId('module_a'));
        expect(module.id, StoryModuleId('module_a'));
        expect(loader.calls, hasLength(2));
      },
    );

    test('flight is removed before an error continuation retries', () async {
      final fixture = _Fixture.single('module_a');
      final firstAttempt = Completer<StoryNarrativeModule>();
      var calls = 0;
      final loader = _CallbackLoader((moduleId) {
        calls += 1;
        if (calls == 1) {
          return firstAttempt.future;
        }
        return Future<StoryNarrativeModule>.value(fixture.modules[moduleId]!);
      });
      final cache = fixture.cache(loader: loader);
      Object? firstError;

      final retried = cache
          .loadModule(StoryModuleId('module_a'))
          .then<StoryNarrativeModule>(
            (module) => module,
            onError: (Object error, StackTrace _) {
              firstError = error;
              return cache.loadModule(StoryModuleId('module_a'));
            },
          );
      firstAttempt.completeError(
        StateError('first attempt'),
        StackTrace.current,
      );

      final result = await retried;
      expect(firstError, isA<StoryModuleLoadException>());
      expect(result.id, StoryModuleId('module_a'));
      expect(calls, 2);
    });

    test(
      'wrong returned module ID is shared, never cached, and retryable',
      () async {
        final fixture = _Fixture.multiple(<String>['module_a', 'module_b']);
        final requested = StoryModuleId('module_a');
        var returnWrongId = true;
        final loader = _CallbackLoader((_) async {
          if (returnWrongId) {
            return fixture.modules[StoryModuleId('module_b')]!;
          }
          return fixture.modules[requested]!;
        });
        final cache = fixture.cache(loader: loader);
        final errors = await Future.wait(<Future<Object>>[
          _captureError(cache.loadModule(requested)),
          _captureError(cache.loadModule(StoryModuleId('module_a'))),
        ]);

        expect(errors.every((error) => identical(error, errors.first)), isTrue);
        expect(cache.isCached(requested), isFalse);
        expect(loader.calls, hasLength(1));

        returnWrongId = false;
        expect((await cache.loadModule(requested)).id, requested);
        expect(loader.calls, hasLength(2));
      },
    );

    test(
      'verification failure is shared, never cached, and retryable',
      () async {
        final fixture = _Fixture.single('module_a');
        final moduleId = fixture.moduleIds.single;
        var invalid = true;
        final invalidModule = StoryNarrativeModule(
          projectId: StoryProjectId('wrong_project'),
          id: moduleId,
          events: fixture.modules[moduleId]!.events,
        );
        final loader = _CallbackLoader((_) async {
          return invalid ? invalidModule : fixture.modules[moduleId]!;
        });
        final cache = fixture.cache(loader: loader);
        final errors = await Future.wait(<Future<Object>>[
          _captureError(cache.loadModule(moduleId)),
          _captureError(cache.loadModule(StoryModuleId('module_a'))),
        ]);

        expect(errors.every((error) => identical(error, errors.first)), isTrue);
        expect(cache.isCached(moduleId), isFalse);
        expect(loader.calls, hasLength(1));

        invalid = false;
        expect(
          await cache.loadModule(moduleId),
          same(fixture.modules[moduleId]),
        );
        expect(loader.calls, hasLength(2));
      },
    );

    test(
      'project, event-set, duplicate, and outbound parity failures stay single-flight',
      () async {
        final projectId = StoryProjectId('project_parity_cases');
        final moduleId = StoryModuleId('module_a');
        final first = StoryEventId('event_first');
        final second = StoryEventId('event_second');
        final index = StoryProjectIndex(
          projectId: projectId,
          stateSchema: StoryStateSchema.empty(),
          modules: <StoryModuleIndexEntry>[StoryModuleIndexEntry(id: moduleId)],
          events: <StoryEventIndexEntry>[
            StoryEventIndexEntry(
              id: first,
              moduleId: moduleId,
              outboundEventIds: <StoryEventId>[second],
            ),
            StoryEventIndexEntry(id: second, moduleId: moduleId),
          ],
        );
        final validFirst = StoryEvent(
          id: first,
          continuationTransition: StoryEventTransition(
            destinationEventId: second,
          ),
        );
        final validSecond = StoryEvent(
          id: second,
          continuationTransition: const StoryTerminalTransition(),
        );
        final invalidModules = <StoryNarrativeModule>[
          StoryNarrativeModule(
            projectId: StoryProjectId('wrong_project'),
            id: moduleId,
            events: <StoryEvent>[validFirst, validSecond],
          ),
          StoryNarrativeModule(
            projectId: projectId,
            id: moduleId,
            events: <StoryEvent>[validFirst],
          ),
          StoryNarrativeModule(
            projectId: projectId,
            id: moduleId,
            events: <StoryEvent>[validFirst, validFirst, validSecond],
          ),
          StoryNarrativeModule(
            projectId: projectId,
            id: moduleId,
            events: <StoryEvent>[
              StoryEvent(
                id: first,
                continuationTransition: const StoryTerminalTransition(),
              ),
              validSecond,
            ],
          ),
        ];

        for (final invalidModule in invalidModules) {
          final loader = _CallbackLoader((_) async => invalidModule);
          final cache = StoryModuleCache(index: index, loader: loader);
          final errors = await Future.wait(<Future<Object>>[
            _captureError(cache.loadModule(moduleId)),
            _captureError(cache.loadModule(StoryModuleId('module_a'))),
          ]);

          expect(loader.calls, hasLength(1));
          expect(
            errors.every((error) => identical(error, errors.first)),
            isTrue,
          );
          expect(errors.first, isA<StoryModuleLoadException>());
          expect(cache.isCached(moduleId), isFalse);
        }
      },
    );

    test(
      'evict and clear during loading preserve the shared pending flight',
      () async {
        final fixture = _Fixture.single('module_a');
        final pending = Completer<StoryNarrativeModule>();
        final loader = _CallbackLoader((_) => pending.future);
        final cache = fixture.cache(loader: loader);
        final first = cache.loadModule(StoryModuleId('module_a'));

        expect(cache.evict(StoryModuleId('module_a')), isFalse);
        cache.clear();
        final second = cache.loadModule(StoryModuleId('module_a'));
        expect(loader.calls, hasLength(1));

        pending.complete(fixture.modules[StoryModuleId('module_a')]!);
        final results = await Future.wait(<Future<StoryNarrativeModule>>[
          first,
          second,
        ]);
        expect(identical(results[0], results[1]), isTrue);
        expect(cache.isCached(StoryModuleId('module_a')), isTrue);

        expect(cache.evict(StoryModuleId('module_a')), isTrue);
        await cache.loadModule(StoryModuleId('module_a'));
        expect(loader.calls, hasLength(2));
      },
    );

    test(
      'failure for one ID does not block or remove another flight',
      () async {
        final fixture = _Fixture.multiple(<String>['module_a', 'module_b']);
        final pending = <StoryModuleId, Completer<StoryNarrativeModule>>{
          for (final id in fixture.moduleIds)
            id: Completer<StoryNarrativeModule>(),
        };
        final loader = _CallbackLoader((moduleId) => pending[moduleId]!.future);
        final cache = fixture.cache(loader: loader);
        final aError = _captureError(
          cache.loadModule(StoryModuleId('module_a')),
        );
        final b = cache.loadModule(StoryModuleId('module_b'));

        pending[StoryModuleId('module_a')]!.completeError(
          StateError('a failed'),
          StackTrace.current,
        );
        expect(await aError, isA<StoryModuleLoadException>());
        expect(loader.calls, hasLength(2));

        pending[StoryModuleId('module_b')]!.complete(
          fixture.modules[StoryModuleId('module_b')]!,
        );
        expect((await b).id, StoryModuleId('module_b'));
        expect(cache.isCached(StoryModuleId('module_b')), isTrue);
      },
    );

    test(
      'non-awaited synchronous same-ID loader reentry joins the placeholder',
      () async {
        final fixture = _Fixture.single('module_a');
        late StoryModuleCache cache;
        Future<StoryNarrativeModule>? nested;
        final loader = _CallbackLoader((moduleId) {
          nested = cache.loadModule(StoryModuleId(moduleId.value));
          return Future<StoryNarrativeModule>.value(fixture.modules[moduleId]!);
        });
        cache = fixture.cache(loader: loader);

        final outer = await cache.loadModule(StoryModuleId('module_a'));
        final inner = await nested!;

        expect(loader.calls, hasLength(1));
        expect(identical(outer, inner), isTrue);
      },
    );

    test(
      'demand, prefetch, and cyclic dependency closure share overlapping loads',
      () async {
        final fixture = _Fixture.cyclicPair();
        final a = StoryModuleId('module_a');
        final b = StoryModuleId('module_b');
        final aPending = Completer<StoryNarrativeModule>();
        final bPending = Completer<StoryNarrativeModule>();
        final bStarted = Completer<void>();
        final loader = _CallbackLoader((moduleId) {
          if (moduleId == a) {
            return aPending.future;
          }
          if (!bStarted.isCompleted) {
            bStarted.complete();
          }
          return bPending.future;
        });
        final cache = fixture.cache(loader: loader);

        final prefetch = cache.prefetch(<StoryModuleId>[a, b]);
        final closure = cache.loadDependencyClosure(StoryModuleId('module_a'));
        final demand = cache.loadModule(StoryModuleId('module_a'));
        expect(loader.calls, <StoryModuleId>[a]);

        aPending.complete(fixture.modules[a]!);
        expect(await demand, same(fixture.modules[a]));
        await bStarted.future;
        expect(loader.calls, <StoryModuleId>[a, b]);

        bPending.complete(fixture.modules[b]!);
        await prefetch;
        final loadedClosure = await closure;

        expect(loader.calls, <StoryModuleId>[a, b]);
        expect(loadedClosure.map((module) => module.id), <StoryModuleId>[a, b]);
      },
    );

    test(
      'unknown IDs fail asynchronously without invoking the loader',
      () async {
        final fixture = _Fixture.single('module_a');
        final loader = _CallbackLoader(
          (moduleId) async => fixture.modules[moduleId]!,
        );
        final cache = fixture.cache(loader: loader);
        Future<StoryNarrativeModule>? request;

        expect(
          () => request = cache.loadModule(StoryModuleId('unknown_module')),
          returnsNormally,
        );
        await expectLater(request, throwsA(isA<StoryModuleLoadException>()));
        expect(loader.calls, isEmpty);
      },
    );

    test('separate cache instances never share flights', () async {
      final fixture = _Fixture.single('module_a');
      final pending = Completer<StoryNarrativeModule>();
      final loader = _CallbackLoader((_) => pending.future);
      final firstCache = fixture.cache(loader: loader);
      final secondCache = fixture.cache(loader: loader);

      final first = firstCache.loadModule(StoryModuleId('module_a'));
      final second = secondCache.loadModule(StoryModuleId('module_a'));
      expect(loader.calls, hasLength(2));

      pending.complete(fixture.modules[StoryModuleId('module_a')]!);
      final modules = await Future.wait(<Future<StoryNarrativeModule>>[
        first,
        second,
      ]);
      expect(identical(modules[0], modules[1]), isTrue);
      expect(firstCache.isCached(StoryModuleId('module_a')), isTrue);
      expect(secondCache.isCached(StoryModuleId('module_a')), isTrue);
    });

    test(
      'handled failures do not create a second uncaught cleanup error',
      () async {
        final fixture = _Fixture.single('module_a');
        final uncaught = <Object>[];

        // Create the failing future inside the guarded error zone. Dart futures
        // retain the error zone in which they are created; creating [pending]
        // outside this zone would prevent its error from crossing into the
        // guarded await and can make the test hang even when the cache is correct.
        final zoned = runZonedGuarded(
          () async {
            final pending = Completer<StoryNarrativeModule>();
            final loader = _CallbackLoader((_) => pending.future);
            final cache = fixture.cache(loader: loader);
            final handled = _captureError(
              cache.loadModule(StoryModuleId('module_a')),
            );

            expect(loader.calls, hasLength(1));
            pending.completeError(StateError('handled'), StackTrace.current);
            expect(await handled, isA<StoryModuleLoadException>());

            // Give any accidentally detached cleanup future a chance to report
            // an uncaught asynchronous error to this zone.
            await Future<void>.value();
            await Future<void>.value();
          },
          (Object error, StackTrace stackTrace) {
            uncaught.add(error);
          },
        );
        if (zoned != null) {
          await zoned;
        }

        expect(uncaught, isEmpty);
      },
    );
  });
}

Future<Object> _captureError(Future<StoryNarrativeModule> future) async {
  try {
    await future;
  } catch (error) {
    return error;
  }
  fail('Expected the module request to fail.');
}

final class _CallbackLoader implements StoryModuleLoader {
  _CallbackLoader(this.onLoad);

  final Future<StoryNarrativeModule> Function(StoryModuleId moduleId) onLoad;
  final List<StoryModuleId> calls = <StoryModuleId>[];

  @override
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId) {
    calls.add(moduleId);
    return onLoad(moduleId);
  }
}

final class _Fixture {
  _Fixture({
    required this.index,
    required this.moduleIds,
    required this.modules,
  });

  factory _Fixture.single(String moduleToken) =>
      _Fixture.multiple(<String>[moduleToken]);

  factory _Fixture.multiple(List<String> moduleTokens) {
    final projectId = StoryProjectId('project_single_flight');
    final moduleIds = <StoryModuleId>[
      for (final token in moduleTokens) StoryModuleId(token),
    ];
    final events = <StoryEventIndexEntry>[];
    final modules = <StoryModuleId, StoryNarrativeModule>{};
    for (final moduleId in moduleIds) {
      final eventId = StoryEventId('event_${moduleId.value}');
      events.add(StoryEventIndexEntry(id: eventId, moduleId: moduleId));
      modules[moduleId] = StoryNarrativeModule(
        projectId: projectId,
        id: moduleId,
        events: <StoryEvent>[
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
    }
    return _Fixture(
      index: StoryProjectIndex(
        projectId: projectId,
        stateSchema: StoryStateSchema.empty(),
        modules: <StoryModuleIndexEntry>[
          for (final moduleId in moduleIds) StoryModuleIndexEntry(id: moduleId),
        ],
        events: events,
      ),
      moduleIds: moduleIds,
      modules: modules,
    );
  }

  factory _Fixture.cyclicPair() {
    final projectId = StoryProjectId('project_single_flight_cycle');
    final a = StoryModuleId('module_a');
    final b = StoryModuleId('module_b');
    final eventA = StoryEventId('event_module_a');
    final eventB = StoryEventId('event_module_b');
    return _Fixture(
      index: StoryProjectIndex(
        projectId: projectId,
        stateSchema: StoryStateSchema.empty(),
        modules: <StoryModuleIndexEntry>[
          StoryModuleIndexEntry(id: a, dependencies: <StoryModuleId>[b]),
          StoryModuleIndexEntry(id: b, dependencies: <StoryModuleId>[a]),
        ],
        events: <StoryEventIndexEntry>[
          StoryEventIndexEntry(id: eventA, moduleId: a),
          StoryEventIndexEntry(id: eventB, moduleId: b),
        ],
      ),
      moduleIds: <StoryModuleId>[a, b],
      modules: <StoryModuleId, StoryNarrativeModule>{
        a: StoryNarrativeModule(
          projectId: projectId,
          id: a,
          events: <StoryEvent>[
            StoryEvent(
              id: eventA,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
        b: StoryNarrativeModule(
          projectId: projectId,
          id: b,
          events: <StoryEvent>[
            StoryEvent(
              id: eventB,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
      },
    );
  }

  final StoryProjectIndex index;
  final List<StoryModuleId> moduleIds;
  final Map<StoryModuleId, StoryNarrativeModule> modules;

  StoryModuleCache cache({
    required StoryModuleLoader loader,
    int maxCachedModules = 32,
  }) => StoryModuleCache(
    index: index,
    loader: loader,
    maxCachedModules: maxCachedModules,
  );
}
