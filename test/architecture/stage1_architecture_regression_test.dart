import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('architecture regression suite', () {
    test('src dependency direction stays within the approved layer graph', () {
      final violations = <String>[];

      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final sourceLayer = _layerOfPath(entity.path);
        if (sourceLayer == null) {
          violations.add(
            '${entity.path}: file is outside a known Stage 1 layer',
          );
          continue;
        }

        final source = entity.readAsStringSync();
        for (final match in _relativeImportPattern.allMatches(source)) {
          final importUri = match.group(1)!;
          final sourceUri = Uri.file(
            entity.absolute.path,
            windows: Platform.isWindows,
          );
          final resolved = sourceUri.resolve(importUri);
          final targetLayer = _layerOfPath(
            resolved.toFilePath(windows: Platform.isWindows),
          );
          if (targetLayer == null) {
            continue;
          }

          final allowedTargets = _allowedLayerDependencies[sourceLayer];
          if (allowedTargets == null) {
            violations.add(
              '${entity.path}: no dependency policy is registered for '
              'the "$sourceLayer" layer',
            );
            continue;
          }

          if (!allowedTargets.contains(targetLayer)) {
            violations.add(
              '${entity.path}: $sourceLayer must not depend on $targetLayer '
              'through $importUri',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Approved dependency direction is an architectural contract.\n'
            '${violations.join('\n')}',
      );
    });

    test(
      'serialization remains an adapter leaf, never a domain dependency',
      () {
        final violations = <String>[];

        for (final entity in Directory('lib/src').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) {
            continue;
          }
          if (_layerOfPath(entity.path) == 'serialization') {
            continue;
          }

          final source = entity.readAsStringSync();
          if (_serializationImportPattern.hasMatch(source)) {
            violations.add(entity.path);
          }
        }

        expect(
          violations,
          isEmpty,
          reason: 'Domain/runtime code must not depend on serialization.\n'
              '${violations.join('\n')}',
        );
      },
    );

    test('runtime does not depend on draft project serialization', () {
      final violations = <String>[];

      for (final entity in Directory('lib/src/runtime').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains('serialization/')) {
          violations.add(entity.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Runtime execution and authored-project serialization are '
            'separate compatibility boundaries.',
      );
    });

    test('JSON knowledge is isolated to persistence adapter layers', () {
      final violations = <String>[];

      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final layer = _layerOfPath(entity.path);
        final normalizedPath = entity.path.replaceAll('\\', '/');
        final isJsonAdapter =
            layer == 'serialization' ||
            layer == 'persistence' ||
            normalizedPath.startsWith('lib/src/format/codec/');
        if (isJsonAdapter) {
          continue;
        }

        final source = entity.readAsStringSync();
        if (_dartConvertImportPattern.hasMatch(source) ||
            RegExp(r'\bjson(?:Encode|Decode)\s*\(').hasMatch(source)) {
          violations.add(entity.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'JSON is an adapter/codec concern, not a domain/runtime concern.\n'
            '${violations.join('\n')}',
      );
    });

    test(
      'TimeTwirlers does not become a production dependency of the engine',
      () {
        final violations = <String>[];

        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) {
            continue;
          }

          final source = entity.readAsStringSync();
          if (_timeTwirlersDependencyPattern.hasMatch(source)) {
            violations.add(entity.path);
          }
        }

        expect(
          violations,
          isEmpty,
          reason: 'TimeTwirlers remains a reference consumer, not a '
              'dependency of story_engine.\n${violations.join('\n')}',
        );
      },
    );

    test(
      'internal execution and draft-codec machinery stays out of barrel',
      () {
        final barrel = File('lib/story_engine.dart').readAsStringSync();

        for (final forbidden in _internalPublicSurfaceTokens) {
          expect(
            barrel,
            isNot(contains(forbidden)),
            reason: '$forbidden is internal implementation machinery.',
          );
        }

        expect(
          barrel,
          contains("export 'src/state/story_state.dart' show StoryState;"),
          reason: 'StoryStateMutation must remain hidden while StoryState is '
              'public.',
        );
      },
    );
  });
}

final _relativeImportPattern = RegExp(r'''import\s+['"](\.\.?/[^'"]+)['"]''');
final _serializationImportPattern = RegExp(
  r'''(?:import|export)\s+['"][^'"]*serialization/''',
);
final _dartConvertImportPattern = RegExp(
  r'''(?:import|export)\s+['"]dart:convert['"]''',
);
final _timeTwirlersDependencyPattern = RegExp(
  r'''(?:import|export)\s+['"]package:(?:time_twirlers|timetwirlers)/''',
  caseSensitive: false,
);

const _internalPublicSurfaceTokens = <String>[
  'StoryStateMutation',
  'StoryEffectExecutor',
  'StoryTransitionResolver',
  'StoryTransitionResolution',
  'StoryRandomSource',
  'StorySeededRandomSource',
  'StoryProjectDraftCodec',
  'StoryDraftSerializationException',
  'serialization/',
];

const _allowedLayerDependencies = <String, Set<String>>{
  'identity': {'identity'},
  'state': {'identity', 'state'},
  'condition': {'identity', 'state', 'condition'},
  'effect': {'identity', 'state', 'effect'},
  'transition': {'identity', 'condition', 'transition'},
  'presentation': {'presentation'},
  'format': {
    'identity',
    'state',
    'condition',
    'effect',
    'transition',
    'presentation',
    'model',
    'format',
  },
  'model': {
    'identity',
    'state',
    'condition',
    'effect',
    'transition',
    'presentation',
    'model',
  },
  'validation': {
    'identity',
    'state',
    'condition',
    'effect',
    'transition',
    'presentation',
    'model',
    'validation',
  },
  'runtime': {
    'identity',
    'state',
    'condition',
    'effect',
    'transition',
    'model',
    'runtime',
  },
  'persistence': {
    'identity',
    'state',
    'model',
    'runtime',
    'persistence',
  },
  'serialization': {
    'identity',
    'state',
    'condition',
    'effect',
    'transition',
    'model',
    'presentation',
    'serialization',
  },
};

String? _layerOfPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final match = RegExp(r'(?:^|/)lib/src/([^/]+)/').firstMatch(normalized);
  return match?.group(1);
}
