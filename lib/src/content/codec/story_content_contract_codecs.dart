import 'dart:convert';

import '../../build/story_content_hash.dart';
import '../../identity/story_choice_id.dart';
import '../../identity/story_content_release_id.dart';
import '../../identity/story_entry_point_id.dart';
import '../../identity/story_event_id.dart';
import '../../identity/story_module_id.dart';
import '../../identity/story_module_version.dart';
import '../../identity/story_project_id.dart';
import '../story_content_migration.dart';
import '../story_content_patch.dart';
import '../story_content_release_manifest.dart';
import '../story_save_content_binding.dart';

/// Strict data-format failure for Stage 8L content-versioning contracts.
final class StoryContentContractFormatException implements Exception {
  const StoryContentContractFormatException(
    this.path,
    this.message, {
    this.cause,
  });

  /// Machine-oriented JSON location.
  final String path;

  /// Human-readable failure description.
  final String message;

  /// Optional lower-level parse/construction failure.
  final Object? cause;

  @override
  String toString() => 'StoryContentContractFormatException at $path: $message';
}

/// Deterministic JSON codec for `open_story.content_release` revision 1.
final class StoryContentReleaseManifestCodec {
  const StoryContentReleaseManifestCodec();

  /// Encodes [manifest] with deterministic field/list order and a final newline.
  String encode(StoryContentReleaseManifest manifest) =>
      _pretty(<String, Object?>{
        'contract': StoryContentReleaseManifest.contractId,
        'contractVersion': StoryContentReleaseManifest.contractVersion,
        'releaseId': manifest.releaseId.value,
        'projectId': manifest.projectId.value,
        'bundleId': manifest.bundleId.value,
        'modules': manifest.modules.map(_encodeModule).toList(growable: false),
      });

  /// Decodes one strict content-release JSON document.
  StoryContentReleaseManifest decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'releaseId',
      'projectId',
      'bundleId',
      'modules',
    }, r'$');
    _expectContract(
      root,
      StoryContentReleaseManifest.contractId,
      StoryContentReleaseManifest.contractVersion,
    );
    try {
      return StoryContentReleaseManifest(
        releaseId: StoryContentReleaseId(
          _string(root['releaseId'], r'$.releaseId'),
        ),
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        bundleId: StoryContentHash.parse(
          _string(root['bundleId'], r'$.bundleId'),
        ),
        modules: _list(root['modules'], r'$.modules').asMap().entries.map(
          (entry) => _decodeModule(entry.value, r'$.modules[${entry.key}]'),
        ),
      );
    } on StoryContentContractFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryContentContractFormatException(
        r'$',
        'Invalid content-release manifest.',
        cause: error,
      );
    }
  }
}

/// Deterministic JSON codec for `open_story.content_patch` revision 1.
final class StoryContentPatchManifestCodec {
  const StoryContentPatchManifestCodec();

  /// Encodes [manifest] without embedding patch payload bytes or transport data.
  String encode(StoryContentPatchManifest manifest) =>
      _pretty(<String, Object?>{
        'contract': StoryContentPatchManifest.contractId,
        'contractVersion': StoryContentPatchManifest.contractVersion,
        'projectId': manifest.projectId.value,
        'fromReleaseId': manifest.fromReleaseId.value,
        'toReleaseId': manifest.toReleaseId.value,
        'fromBundleId': manifest.fromBundleId.value,
        'toBundleId': manifest.toBundleId.value,
        'operations': manifest.operations
            .map(_encodePatchOperation)
            .toList(growable: false),
      });

  /// Decodes one strict transport-neutral patch manifest.
  StoryContentPatchManifest decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'projectId',
      'fromReleaseId',
      'toReleaseId',
      'fromBundleId',
      'toBundleId',
      'operations',
    }, r'$');
    _expectContract(
      root,
      StoryContentPatchManifest.contractId,
      StoryContentPatchManifest.contractVersion,
    );
    try {
      return StoryContentPatchManifest(
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        fromReleaseId: StoryContentReleaseId(
          _string(root['fromReleaseId'], r'$.fromReleaseId'),
        ),
        toReleaseId: StoryContentReleaseId(
          _string(root['toReleaseId'], r'$.toReleaseId'),
        ),
        fromBundleId: StoryContentHash.parse(
          _string(root['fromBundleId'], r'$.fromBundleId'),
        ),
        toBundleId: StoryContentHash.parse(
          _string(root['toBundleId'], r'$.toBundleId'),
        ),
        operations: _list(root['operations'], r'$.operations')
            .asMap()
            .entries
            .map(
              (entry) => _decodePatchOperation(
                entry.value,
                r'$.operations[${entry.key}]',
              ),
            ),
      );
    } on StoryContentContractFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryContentContractFormatException(
        r'$',
        'Invalid content-patch manifest.',
        cause: error,
      );
    }
  }
}

/// Deterministic JSON codec for `open_story.save_content_binding` revision 1.
final class StorySaveContentBindingCodec {
  const StorySaveContentBindingCodec();

  /// Encodes content identity persisted beside a runtime snapshot.
  String encode(StorySaveContentBinding binding) => _pretty(<String, Object?>{
    'contract': StorySaveContentBinding.contractId,
    'contractVersion': StorySaveContentBinding.contractVersion,
    'projectId': binding.projectId.value,
    'releaseId': binding.releaseId.value,
    'bundleId': binding.bundleId.value,
    'modules': binding.modules
        .map(_encodeRevisionReference)
        .toList(growable: false),
  });

  /// Decodes one strict save-content binding.
  StorySaveContentBinding decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'projectId',
      'releaseId',
      'bundleId',
      'modules',
    }, r'$');
    _expectContract(
      root,
      StorySaveContentBinding.contractId,
      StorySaveContentBinding.contractVersion,
    );
    try {
      return StorySaveContentBinding(
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        releaseId: StoryContentReleaseId(
          _string(root['releaseId'], r'$.releaseId'),
        ),
        bundleId: StoryContentHash.parse(
          _string(root['bundleId'], r'$.bundleId'),
        ),
        modules: _list(root['modules'], r'$.modules').asMap().entries.map(
          (entry) =>
              _decodeRevisionReference(entry.value, r'$.modules[${entry.key}]'),
        ),
      );
    } on StoryContentContractFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryContentContractFormatException(
        r'$',
        'Invalid save-content binding.',
        cause: error,
      );
    }
  }
}

/// Deterministic JSON codec for `open_story.content_migration` revision 1.
final class StoryContentMigrationPlanCodec {
  const StoryContentMigrationPlanCodec();

  /// Encodes declarative redirects/fallback policy with deterministic ordering.
  String encode(StoryContentMigrationPlan plan) {
    final events = plan.eventRedirects.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    final choices = plan.choiceRedirects.entries.toList()
      ..sort((a, b) => a.key.value.compareTo(b.key.value));
    return _pretty(<String, Object?>{
      'contract': StoryContentMigrationPlan.contractId,
      'contractVersion': StoryContentMigrationPlan.contractVersion,
      'projectId': plan.projectId.value,
      'fromReleaseId': plan.fromReleaseId.value,
      'toReleaseId': plan.toReleaseId.value,
      'eventRedirects': events
          .map(
            (entry) => <String, Object?>{
              'from': entry.key.value,
              'to': entry.value.value,
            },
          )
          .toList(growable: false),
      'choiceRedirects': choices
          .map(
            (entry) => <String, Object?>{
              'from': entry.key.value,
              'to': entry.value.value,
            },
          )
          .toList(growable: false),
      'fallbackEntryPointId': plan.fallbackEntryPointId?.value,
    });
  }

  /// Decodes one strict declarative content-migration plan.
  StoryContentMigrationPlan decode(String source) {
    try {
      final root = _decodeRoot(source);
      _allowOnly(root, const {
        'contract',
        'contractVersion',
        'projectId',
        'fromReleaseId',
        'toReleaseId',
        'eventRedirects',
        'choiceRedirects',
        'fallbackEntryPointId',
      }, r'$');
      _expectContract(
        root,
        StoryContentMigrationPlan.contractId,
        StoryContentMigrationPlan.contractVersion,
      );
      final eventRedirects = <StoryEventId, StoryEventId>{};
      final eventList = _list(root['eventRedirects'], r'$.eventRedirects');
      for (var i = 0; i < eventList.length; i++) {
        final map = _map(eventList[i], r'$.eventRedirects[$i]');
        _allowOnly(map, const {'from', 'to'}, r'$.eventRedirects[$i]');
        final from = StoryEventId(
          _string(map['from'], r'$.eventRedirects[$i].from'),
        );
        if (eventRedirects.containsKey(from)) {
          throw StoryContentContractFormatException(
            r'$.eventRedirects[$i].from',
            'Duplicate event redirect source.',
          );
        }
        eventRedirects[from] = StoryEventId(
          _string(map['to'], r'$.eventRedirects[$i].to'),
        );
      }

      final choiceRedirects = <StoryChoiceId, StoryChoiceId>{};
      final choiceList = _list(root['choiceRedirects'], r'$.choiceRedirects');
      for (var i = 0; i < choiceList.length; i++) {
        final map = _map(choiceList[i], r'$.choiceRedirects[$i]');
        _allowOnly(map, const {'from', 'to'}, r'$.choiceRedirects[$i]');
        final from = StoryChoiceId(
          _string(map['from'], r'$.choiceRedirects[$i].from'),
        );
        if (choiceRedirects.containsKey(from)) {
          throw StoryContentContractFormatException(
            r'$.choiceRedirects[$i].from',
            'Duplicate choice redirect source.',
          );
        }
        choiceRedirects[from] = StoryChoiceId(
          _string(map['to'], r'$.choiceRedirects[$i].to'),
        );
      }

      final fallback = root['fallbackEntryPointId'];
      return StoryContentMigrationPlan(
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        fromReleaseId: StoryContentReleaseId(
          _string(root['fromReleaseId'], r'$.fromReleaseId'),
        ),
        toReleaseId: StoryContentReleaseId(
          _string(root['toReleaseId'], r'$.toReleaseId'),
        ),
        eventRedirects: eventRedirects,
        choiceRedirects: choiceRedirects,
        fallbackEntryPointId: fallback == null
            ? null
            : StoryEntryPointId(_string(fallback, r'$.fallbackEntryPointId')),
      );
    } on StoryContentContractFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryContentContractFormatException(
        r'$',
        'Invalid content-migration plan.',
        cause: error,
      );
    }
  }
}

Map<String, Object?> _encodeModule(StoryContentModuleRevision module) =>
    <String, Object?>{
      'moduleId': module.moduleId.value,
      'moduleVersion': module.moduleVersion.value,
      'contentHash': module.contentHash.value,
      'dependencies': module.dependencies
          .map((id) => id.value)
          .toList(growable: false),
      'compatibleSaveSources': module.compatibleSaveSources
          .map(_encodeRevisionReference)
          .toList(growable: false),
    };

StoryContentModuleRevision _decodeModule(Object? value, String path) {
  final map = _map(value, path);
  _allowOnly(map, const {
    'moduleId',
    'moduleVersion',
    'contentHash',
    'dependencies',
    'compatibleSaveSources',
  }, path);
  final moduleId = StoryModuleId(_string(map['moduleId'], '$path.moduleId'));
  return StoryContentModuleRevision(
    moduleId: moduleId,
    moduleVersion: StoryModuleVersion(
      _string(map['moduleVersion'], '$path.moduleVersion'),
    ),
    contentHash: StoryContentHash.parse(
      _string(map['contentHash'], '$path.contentHash'),
    ),
    dependencies: _list(map['dependencies'], '$path.dependencies')
        .asMap()
        .entries
        .map(
          (entry) => StoryModuleId(
            _string(entry.value, '$path.dependencies[${entry.key}]'),
          ),
        ),
    compatibleSaveSources:
        _list(
          map['compatibleSaveSources'],
          '$path.compatibleSaveSources',
        ).asMap().entries.map(
          (entry) => _decodeRevisionReference(
            entry.value,
            '$path.compatibleSaveSources[${entry.key}]',
          ),
        ),
  );
}

Map<String, Object?> _encodeRevisionReference(
  StoryModuleRevisionReference reference,
) => <String, Object?>{
  'moduleId': reference.moduleId.value,
  'moduleVersion': reference.moduleVersion.value,
  'contentHash': reference.contentHash.value,
};

StoryModuleRevisionReference _decodeRevisionReference(
  Object? value,
  String path,
) {
  final map = _map(value, path);
  _allowOnly(map, const {'moduleId', 'moduleVersion', 'contentHash'}, path);
  return StoryModuleRevisionReference(
    moduleId: StoryModuleId(_string(map['moduleId'], '$path.moduleId')),
    moduleVersion: StoryModuleVersion(
      _string(map['moduleVersion'], '$path.moduleVersion'),
    ),
    contentHash: StoryContentHash.parse(
      _string(map['contentHash'], '$path.contentHash'),
    ),
  );
}

Map<String, Object?> _encodePatchOperation(
  StoryContentPatchOperation operation,
) => <String, Object?>{
  'kind': operation.kind.name,
  'moduleId': operation.moduleId.value,
  'fromRevision': operation.fromRevision == null
      ? null
      : _encodeRevisionReference(operation.fromRevision!),
  'toRevision': operation.toRevision == null
      ? null
      : _encodeRevisionReference(operation.toRevision!),
};

StoryContentPatchOperation _decodePatchOperation(Object? value, String path) {
  final map = _map(value, path);
  _allowOnly(map, const {
    'kind',
    'moduleId',
    'fromRevision',
    'toRevision',
  }, path);
  final moduleId = StoryModuleId(_string(map['moduleId'], '$path.moduleId'));
  final from = map['fromRevision'] == null
      ? null
      : _decodeRevisionReference(map['fromRevision'], '$path.fromRevision');
  final to = map['toRevision'] == null
      ? null
      : _decodeRevisionReference(map['toRevision'], '$path.toRevision');
  final kind = _string(map['kind'], '$path.kind');
  late final StoryContentPatchOperation operation;
  if (kind == 'add') {
    if (to == null) {
      throw StoryContentContractFormatException(
        path,
        'Add operation is missing target revision.',
      );
    }
    operation = StoryContentPatchOperation.add(to);
  } else if (kind == 'replace') {
    if (from == null || to == null) {
      throw StoryContentContractFormatException(
        path,
        'Replace operation requires both revisions.',
      );
    }
    operation = StoryContentPatchOperation.replace(source: from, target: to);
  } else if (kind == 'remove') {
    if (from == null) {
      throw StoryContentContractFormatException(
        path,
        'Remove operation is missing source revision.',
      );
    }
    operation = StoryContentPatchOperation.remove(from);
  } else {
    throw StoryContentContractFormatException(
      '$path.kind',
      'Unknown patch operation kind "$kind".',
    );
  }
  if (operation.moduleId != moduleId) {
    throw StoryContentContractFormatException(
      '$path.moduleId',
      'Operation module ID does not match its revision payload.',
    );
  }
  return operation;
}

Map<String, Object?> _decodeRoot(String source) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on Object catch (error) {
    throw StoryContentContractFormatException(
      r'$',
      'Input is not valid JSON.',
      cause: error,
    );
  }
  return _map(decoded, r'$');
}

void _expectContract(Map<String, Object?> root, String id, int version) {
  final actualId = _string(root['contract'], r'$.contract');
  if (actualId != id) {
    throw StoryContentContractFormatException(
      r'$.contract',
      'Expected "$id", got "$actualId".',
    );
  }
  final actualVersion = root['contractVersion'];
  if (actualVersion is! int || actualVersion != version) {
    throw StoryContentContractFormatException(
      r'$.contractVersion',
      'Expected contract version $version.',
    );
  }
}

String _pretty(Map<String, Object?> value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) {
    throw StoryContentContractFormatException(path, 'Expected JSON object.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw StoryContentContractFormatException(
        path,
        'Object keys must be strings.',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) {
    throw StoryContentContractFormatException(path, 'Expected JSON array.');
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryContentContractFormatException(path, 'Expected string.');
  }
  return value;
}

void _allowOnly(Map<String, Object?> map, Set<String> allowed, String path) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw StoryContentContractFormatException(
        '$path.$key',
        'Unknown field "$key".',
      );
    }
  }
  for (final key in allowed) {
    if (!map.containsKey(key)) {
      throw StoryContentContractFormatException(
        '$path.$key',
        'Required field is missing.',
      );
    }
  }
}
