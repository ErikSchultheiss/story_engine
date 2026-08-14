import 'dart:convert';

import '../../condition/story_condition.dart';
import '../../effect/story_effect.dart';
import '../../identity/story_alias.dart';
import '../../identity/story_choice_id.dart';
import '../../identity/story_event_id.dart';
import '../../identity/story_project_id.dart';
import '../../identity/story_variable_id.dart';
import '../../model/story_choice.dart';
import '../../model/story_event.dart';
import '../../model/story_project.dart';
import '../../presentation/story_choice_presentation.dart';
import '../../presentation/story_event_presentation.dart';
import '../../presentation/story_text.dart';
import '../../state/story_state_schema.dart';
import '../../state/story_value.dart';
import '../../state/story_value_type.dart';
import '../../state/story_variable_definition.dart';
import '../../transition/story_transition.dart';
import '../story_format_bundle.dart';
import '../story_format_bundle_layout.dart';
import '../story_format_compatibility.dart';
import '../story_format_document.dart';
import '../story_format_extension_attachment.dart';
import '../story_format_extension_namespace.dart';
import '../story_format_extension_payload.dart';
import '../story_format_extension_target.dart';
import '../story_format_group.dart';
import '../story_format_group_id.dart';
import '../story_format_metadata.dart';
import 'story_format_migrations.dart';
import '../story_format_organization.dart';
import '../story_format_tag.dart';
import '../story_format_tag_id.dart';

/// Deterministic public Story Format v1 bundle codec.
///
/// The codec operates on the logical [StoryFormatBundle] rather than the
/// filesystem. Applications decide how bundle files are stored or transported.
/// Every encoded core JSON file uses UTF-8-compatible JSON text, two-space
/// indentation, LF newlines, a final newline, fixed field ordering, and stable
/// discriminator tokens.
///
/// V1 decoding is deliberately strict about unknown core fields/kinds. An
/// unsupported semantic construct must never be silently discarded and then
/// re-saved with changed story meaning. Opaque forward extension data belongs
/// in the explicit Story Format extension mechanism instead. Unsupported
/// authored-format identity/version is reported separately through
/// `StoryFormatCompatibilityException` before current-v1 shape validation.
final class StoryFormatCodec {
  const StoryFormatCodec();

  static final StoryFormatMigrationPipeline _migrations =
      StoryFormatMigrationPipeline.builtIn();

  /// Encodes a runtime/validation [StoryProject] as a current Story Format
  /// bundle with empty organization and extension metadata.
  ///
  /// Use [encode] with a [StoryFormatDocument] when runtime-neutral authoring
  /// metadata must be preserved. This shortcut is intended for applications
  /// whose authored source is exactly the executable project model.
  StoryFormatBundle encodeProject(StoryProject project) =>
      encode(StoryFormatDocument(project: project));

  /// Decodes [bundle] and returns only its runtime/validation project
  /// projection.
  ///
  /// Organization and extension metadata are intentionally not returned by
  /// this shortcut. Use [decode] when the caller needs a lossless authored
  /// document for editing or re-encoding.
  StoryProject decodeProject(StoryFormatBundle bundle) => decode(bundle).project;

  /// Encodes [document] into the canonical Story Format v1 logical bundle.
  StoryFormatBundle encode(StoryFormatDocument document) {
    if (document.metadata.formatId != StoryFormatMetadata.currentFormatId ||
        document.metadata.formatVersion !=
            StoryFormatMetadata.currentFormatVersion) {
      throw StoryFormatCodecException(
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$',
        message: 'Only the current Story Format v1 document model can be '
            'encoded by this codec.',
      );
    }

    final eventByPath = <String, StoryEvent>{};
    for (final event in document.project.events) {
      final path = StoryFormatBundleLayout.eventPath(event.id);
      if (eventByPath.containsKey(path)) {
        throw StoryFormatCodecException(
          bundlePath: StoryFormatBundleLayout.projectPath,
          jsonPath: r'$.project.eventIds',
          message: 'Duplicate event ID ${event.id.value} cannot be encoded '
              'because each stable event identity owns one event file.',
        );
      }
      eventByPath[path] = event;
    }

    final files = <String, String>{};
    files[StoryFormatBundleLayout.projectPath] = _encodeCanonicalJson(
      _encodeProjectManifest(document.project),
    );

    if (!document.organization.isEmpty) {
      files[StoryFormatBundleLayout.organizationPath] = _encodeCanonicalJson(
        _encodeOrganization(document.organization),
      );
    }

    if (document.extensions.isNotEmpty) {
      files[StoryFormatBundleLayout.extensionsPath] = _encodeCanonicalJson(
        _encodeExtensions(document.extensions),
      );
    }

    final eventPaths = eventByPath.keys.toList()..sort();
    for (final path in eventPaths) {
      files[path] = _encodeCanonicalJson(_encodeEvent(eventByPath[path]!));
    }

    return StoryFormatBundle(files: files);
  }

  /// Decodes one strict Story Format v1 logical bundle.
  ///
  /// Parsing creates authored data; it does not execute `StoryValidator` or
  /// require the project to be runnable. Representable incomplete semantic and
  /// runtime-neutral metadata references are preserved for editor repair.
  StoryFormatDocument decode(StoryFormatBundle bundle) {
    final currentBundle = _migrateToCurrent(bundle);
    final projectSource = currentBundle.file(StoryFormatBundleLayout.projectPath);
    if (projectSource == null) {
      throw const StoryFormatCodecException(
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$',
        message: 'Required Story Format project manifest is missing.',
      );
    }

    final manifest = _decodeProjectManifest(
      _decodeJson(projectSource, StoryFormatBundleLayout.projectPath),
      StoryFormatBundleLayout.projectPath,
    );

    final expectedCorePaths = <String>{StoryFormatBundleLayout.projectPath};
    final events = <StoryEvent>[];
    final seenEventIds = <StoryEventId>{};

    for (var index = 0; index < manifest.eventIds.length; index++) {
      final eventId = manifest.eventIds[index];
      if (!seenEventIds.add(eventId)) {
        throw StoryFormatCodecException(
          bundlePath: StoryFormatBundleLayout.projectPath,
          jsonPath: '\$.project.eventIds[$index]',
          message: 'Duplicate event ID ${eventId.value} in the project '
              'manifest cannot map to a one-file-per-ID v1 bundle.',
        );
      }

      final path = StoryFormatBundleLayout.eventPath(eventId);
      expectedCorePaths.add(path);
      final source = currentBundle.file(path);
      if (source == null) {
        throw StoryFormatCodecException(
          bundlePath: path,
          jsonPath: r'$',
          message: 'Manifest event ${eventId.value} is missing its canonical '
              'event file.',
        );
      }

      final event = _decodeEvent(_decodeJson(source, path), path);
      if (event.id != eventId) {
        throw StoryFormatCodecException(
          bundlePath: path,
          jsonPath: r'$.id',
          message: 'Event file identity ${event.id.value} does not match '
              'manifest identity ${eventId.value}.',
        );
      }
      events.add(event);
    }

    StoryFormatOrganization organization = StoryFormatOrganization.empty();
    final organizationSource = currentBundle.file(
      StoryFormatBundleLayout.organizationPath,
    );
    if (organizationSource != null) {
      expectedCorePaths.add(StoryFormatBundleLayout.organizationPath);
      organization = _decodeOrganization(
        _decodeJson(
          organizationSource,
          StoryFormatBundleLayout.organizationPath,
        ),
        StoryFormatBundleLayout.organizationPath,
      );
    }

    List<StoryFormatExtensionAttachment> extensions = const [];
    final extensionsSource = currentBundle.file(
      StoryFormatBundleLayout.extensionsPath,
    );
    if (extensionsSource != null) {
      expectedCorePaths.add(StoryFormatBundleLayout.extensionsPath);
      extensions = _decodeExtensions(
        _decodeJson(extensionsSource, StoryFormatBundleLayout.extensionsPath),
        StoryFormatBundleLayout.extensionsPath,
      );
    }

    for (final path in currentBundle.files.keys) {
      if (!expectedCorePaths.contains(path)) {
        throw StoryFormatCodecException(
          bundlePath: path,
          jsonPath: r'$',
          message: 'Unexpected file in Story Format v1 bundle. Unknown core '
              'files are not ignored silently.',
        );
      }
    }

    final project = _checked(
      StoryFormatBundleLayout.projectPath,
      r'$.project',
      () => StoryProject(
        id: manifest.id,
        alias: manifest.alias,
        stateSchema: manifest.stateSchema,
        events: events,
        entryEventId: manifest.entryEventId,
      ),
    );

    return _checked(
      StoryFormatBundleLayout.projectPath,
      r'$',
      () => StoryFormatDocument(
        project: project,
        organization: organization,
        extensions: extensions,
      ),
    );
  }

  StoryFormatBundle _migrateToCurrent(StoryFormatBundle bundle) {
    final projectSource = bundle.file(StoryFormatBundleLayout.projectPath);
    if (projectSource == null) {
      throw const StoryFormatCodecException(
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$',
        message: 'Required Story Format project manifest is missing.',
      );
    }

    final root = _map(
      _decodeJson(projectSource, StoryFormatBundleLayout.projectPath),
      StoryFormatBundleLayout.projectPath,
      r'$',
    );
    final formatId = _string(
      _required(
        root,
        'formatId',
        StoryFormatBundleLayout.projectPath,
        r'$',
      ),
      StoryFormatBundleLayout.projectPath,
      r'$.formatId',
    );
    if (formatId != StoryFormatMetadata.currentFormatId) {
      throw StoryFormatCompatibilityException(
        issue: StoryFormatCompatibilityIssue.unsupportedFormatIdentity,
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$.formatId',
        message: 'Story Format identity "$formatId" is not supported by the '
            'current story_engine authored-format reader.',
        foundFormatId: formatId,
      );
    }

    final version = _integer(
      _required(
        root,
        'formatVersion',
        StoryFormatBundleLayout.projectPath,
        r'$',
      ),
      StoryFormatBundleLayout.projectPath,
      r'$.formatVersion',
    );
    if (version <= 0) {
      throw StoryFormatCodecException(
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$.formatVersion',
        message: 'Story Format versions must be positive integers.',
      );
    }

    final current = StoryFormatMetadata.currentFormatVersion;
    if (version > current) {
      throw StoryFormatCompatibilityException(
        issue: StoryFormatCompatibilityIssue.unsupportedFormatVersion,
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$.formatVersion',
        message: 'Story Format version $version is newer than supported '
            'version $current.',
        foundFormatId: formatId,
        foundFormatVersion: version,
      );
    }
    if (version == current) {
      return bundle;
    }

    if (!_migrations.canMigrate(fromVersion: version, toVersion: current)) {
      throw StoryFormatCompatibilityException(
        issue: StoryFormatCompatibilityIssue.unsupportedFormatVersion,
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$.formatVersion',
        message: 'No Story Format migration path exists from version '
            '$version to $current.',
        foundFormatId: formatId,
        foundFormatVersion: version,
      );
    }

    try {
      return _migrations.migrate(
        bundle: bundle,
        fromVersion: version,
        toVersion: current,
      );
    } catch (error) {
      throw StoryFormatCodecException(
        bundlePath: StoryFormatBundleLayout.projectPath,
        jsonPath: r'$',
        message: 'Story Format migration failed.',
        cause: error,
      );
    }
  }
}

/// Structured public failure produced while encoding or decoding Story Format.
final class StoryFormatCodecException implements Exception {
  const StoryFormatCodecException({
    required this.bundlePath,
    required this.jsonPath,
    required this.message,
    this.cause,
  });

  /// Bundle-relative file associated with the failure.
  final String bundlePath;

  /// JSONPath-like location within [bundlePath].
  final String jsonPath;

  /// Human-readable failure explanation.
  final String message;

  /// Optional underlying parser/domain-construction failure.
  final Object? cause;

  /// Compact bundle + JSON location for developer logs.
  String get location => '$bundlePath:$jsonPath';

  /// Generic recovery guidance for malformed current-version Story Format.
  String get suggestion => 'Inspect $bundlePath at $jsonPath and correct the '
      'malformed or unsupported current-version data.';

  @override
  String toString() {
    final causeText = cause == null ? '' : ' Cause: $cause';
    return 'StoryFormatCodecException at $bundlePath:$jsonPath: '
        '$message$causeText';
  }
}

final class _ProjectManifest {
  const _ProjectManifest({
    required this.id,
    required this.alias,
    required this.stateSchema,
    required this.eventIds,
    required this.entryEventId,
  });

  final StoryProjectId id;
  final StoryAlias? alias;
  final StoryStateSchema stateSchema;
  final List<StoryEventId> eventIds;
  final StoryEventId? entryEventId;
}

Map<String, Object?> _encodeProjectManifest(StoryProject project) {
  final projectData = <String, Object?>{'id': project.id.value};
  _putAlias(projectData, project.alias);
  projectData['stateSchema'] = _encodeStateSchema(project.stateSchema);
  projectData['eventIds'] = project.events
      .map((event) => event.id.value)
      .toList(growable: false);
  final entryEventId = project.entryEventId;
  if (entryEventId != null) {
    projectData['entryEventId'] = entryEventId.value;
  }

  return <String, Object?>{
    'formatId': StoryFormatMetadata.currentFormatId,
    'formatVersion': StoryFormatMetadata.currentFormatVersion,
    'project': projectData,
  };
}

_ProjectManifest _decodeProjectManifest(Object? encoded, String bundlePath) {
  const rootPath = r'$';
  final root = _map(encoded, bundlePath, rootPath);

  // Compatibility identity/version must be inspected before applying the
  // current-version field vocabulary. A future v2 bundle may legitimately
  // contain fields unknown to v1; callers need an unsupported-version signal,
  // not a misleading unknown-field error.
  final formatId = _string(
    _required(root, 'formatId', bundlePath, rootPath),
    bundlePath,
    r'$.formatId',
  );
  if (formatId != StoryFormatMetadata.currentFormatId) {
    throw StoryFormatCompatibilityException(
      issue: StoryFormatCompatibilityIssue.unsupportedFormatIdentity,
      bundlePath: bundlePath,
      jsonPath: r'$.formatId',
      message: 'Story Format identity "$formatId" is not supported by the '
          'current story_engine authored-format reader.',
      foundFormatId: formatId,
    );
  }

  final formatVersion = _integer(
    _required(root, 'formatVersion', bundlePath, rootPath),
    bundlePath,
    r'$.formatVersion',
  );
  if (formatVersion != StoryFormatMetadata.currentFormatVersion) {
    throw StoryFormatCompatibilityException(
      issue: StoryFormatCompatibilityIssue.unsupportedFormatVersion,
      bundlePath: bundlePath,
      jsonPath: r'$.formatVersion',
      message: 'Story Format version $formatVersion is not supported by this '
          'reader; current version is '
          '${StoryFormatMetadata.currentFormatVersion}.',
      foundFormatId: formatId,
      foundFormatVersion: formatVersion,
    );
  }

  _allowOnly(
    root,
    const {'formatId', 'formatVersion', 'project'},
    bundlePath,
    rootPath,
  );

  final projectPath = r'$.project';
  final project = _map(
    _required(root, 'project', bundlePath, rootPath),
    bundlePath,
    projectPath,
  );
  _allowOnly(
    project,
    const {'id', 'alias', 'stateSchema', 'eventIds', 'entryEventId'},
    bundlePath,
    projectPath,
  );

  final eventIdsData = _list(
    _required(project, 'eventIds', bundlePath, projectPath),
    bundlePath,
    r'$.project.eventIds',
  );

  return _ProjectManifest(
    id: _checked(
      bundlePath,
      r'$.project.id',
      () => StoryProjectId(
        _string(
          _required(project, 'id', bundlePath, projectPath),
          bundlePath,
          r'$.project.id',
        ),
      ),
    ),
    alias: _decodeAlias(project, bundlePath, projectPath),
    stateSchema: _decodeStateSchema(
      _required(project, 'stateSchema', bundlePath, projectPath),
      bundlePath,
      r'$.project.stateSchema',
    ),
    eventIds: List<StoryEventId>.unmodifiable([
      for (var index = 0; index < eventIdsData.length; index++)
        _checked(
          bundlePath,
          '\$.project.eventIds[$index]',
          () => StoryEventId(
            _string(
              eventIdsData[index],
              bundlePath,
              '\$.project.eventIds[$index]',
            ),
          ),
        ),
    ]),
    entryEventId: project.containsKey('entryEventId')
        ? _checked(
            bundlePath,
            r'$.project.entryEventId',
            () => StoryEventId(
              _string(
                project['entryEventId'],
                bundlePath,
                r'$.project.entryEventId',
              ),
            ),
          )
        : null,
  );
}

Map<String, Object?> _encodeStateSchema(StoryStateSchema schema) =>
    <String, Object?>{
      'variables': schema.variables
          .map(_encodeVariableDefinition)
          .toList(growable: false),
    };

StoryStateSchema _decodeStateSchema(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'variables'}, bundlePath, path);
  final variables = _list(
    _required(map, 'variables', bundlePath, path),
    bundlePath,
    '$path.variables',
  );
  return _checked(
    bundlePath,
    path,
    () => StoryStateSchema(
      variables: [
        for (var index = 0; index < variables.length; index++)
          _decodeVariableDefinition(
            variables[index],
            bundlePath,
            '$path.variables[$index]',
          ),
      ],
    ),
  );
}

Map<String, Object?> _encodeVariableDefinition(
  StoryVariableDefinition definition,
) {
  final result = <String, Object?>{
    'id': definition.id.value,
    'type': _valueTypeToken(definition.type),
  };
  _putAlias(result, definition.alias);
  final initialValue = definition.initialValue;
  if (initialValue != null) {
    result['initialValue'] = _encodeValue(initialValue);
  }
  return result;
}

StoryVariableDefinition _decodeVariableDefinition(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {'id', 'alias', 'type', 'initialValue'},
    bundlePath,
    path,
  );

  return _checked(
    bundlePath,
    path,
    () => StoryVariableDefinition(
      id: StoryVariableId(
        _string(
          _required(map, 'id', bundlePath, path),
          bundlePath,
          '$path.id',
        ),
      ),
      alias: _decodeAlias(map, bundlePath, path),
      type: _decodeValueType(
        _string(
          _required(map, 'type', bundlePath, path),
          bundlePath,
          '$path.type',
        ),
        bundlePath,
        '$path.type',
      ),
      initialValue: map.containsKey('initialValue')
          ? _decodeValue(map['initialValue'], bundlePath, '$path.initialValue')
          : null,
    ),
  );
}

Map<String, Object?> _encodeEvent(StoryEvent event) {
  final result = <String, Object?>{'id': event.id.value};
  _putAlias(result, event.alias);
  final presentation = event.presentation;
  if (presentation != null) {
    result['presentation'] = _encodeEventPresentation(presentation);
  }
  final availabilityCondition = event.availabilityCondition;
  if (availabilityCondition != null) {
    result['availabilityCondition'] = _encodeCondition(availabilityCondition);
  }
  result['entryEffects'] = event.entryEffects
      .map(_encodeEffect)
      .toList(growable: false);
  result['choices'] = event.choices.map(_encodeChoice).toList(growable: false);
  final continuationTransition = event.continuationTransition;
  if (continuationTransition != null) {
    result['continuationTransition'] = _encodeTransition(continuationTransition);
  }
  final automaticTransition = event.automaticTransition;
  if (automaticTransition != null) {
    result['automaticTransition'] = _encodeTransition(automaticTransition);
  }
  return result;
}

StoryEvent _decodeEvent(Object? encoded, String bundlePath) {
  const path = r'$';
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {
      'id',
      'alias',
      'presentation',
      'availabilityCondition',
      'entryEffects',
      'choices',
      'continuationTransition',
      'automaticTransition',
    },
    bundlePath,
    path,
  );

  final entryEffects = _list(
    _required(map, 'entryEffects', bundlePath, path),
    bundlePath,
    r'$.entryEffects',
  );
  final choices = _list(
    _required(map, 'choices', bundlePath, path),
    bundlePath,
    r'$.choices',
  );

  return _checked(
    bundlePath,
    path,
    () => StoryEvent(
      id: StoryEventId(
        _string(
          _required(map, 'id', bundlePath, path),
          bundlePath,
          r'$.id',
        ),
      ),
      alias: _decodeAlias(map, bundlePath, path),
      presentation: map.containsKey('presentation')
          ? _decodeEventPresentation(
              map['presentation'],
              bundlePath,
              r'$.presentation',
            )
          : null,
      availabilityCondition: map.containsKey('availabilityCondition')
          ? _decodeCondition(
              map['availabilityCondition'],
              bundlePath,
              r'$.availabilityCondition',
            )
          : null,
      entryEffects: [
        for (var index = 0; index < entryEffects.length; index++)
          _decodeEffect(
            entryEffects[index],
            bundlePath,
            '\$.entryEffects[$index]',
          ),
      ],
      choices: [
        for (var index = 0; index < choices.length; index++)
          _decodeChoice(choices[index], bundlePath, '\$.choices[$index]'),
      ],
      continuationTransition: map.containsKey('continuationTransition')
          ? _decodeTransition(
              map['continuationTransition'],
              bundlePath,
              r'$.continuationTransition',
            )
          : null,
      automaticTransition: map.containsKey('automaticTransition')
          ? _decodeTransition(
              map['automaticTransition'],
              bundlePath,
              r'$.automaticTransition',
            )
          : null,
    ),
  );
}

Map<String, Object?> _encodeChoice(StoryChoice choice) {
  final result = <String, Object?>{'id': choice.id.value};
  _putAlias(result, choice.alias);
  final presentation = choice.presentation;
  if (presentation != null) {
    result['presentation'] = _encodeChoicePresentation(presentation);
  }
  final availabilityCondition = choice.availabilityCondition;
  if (availabilityCondition != null) {
    result['availabilityCondition'] = _encodeCondition(availabilityCondition);
  }
  result['effects'] = choice.effects.map(_encodeEffect).toList(growable: false);
  final transition = choice.transition;
  if (transition != null) {
    result['transition'] = _encodeTransition(transition);
  }
  return result;
}

StoryChoice _decodeChoice(Object? encoded, String bundlePath, String path) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {
      'id',
      'alias',
      'presentation',
      'availabilityCondition',
      'effects',
      'transition',
    },
    bundlePath,
    path,
  );
  final effects = _list(
    _required(map, 'effects', bundlePath, path),
    bundlePath,
    '$path.effects',
  );

  return _checked(
    bundlePath,
    path,
    () => StoryChoice(
      id: StoryChoiceId(
        _string(
          _required(map, 'id', bundlePath, path),
          bundlePath,
          '$path.id',
        ),
      ),
      alias: _decodeAlias(map, bundlePath, path),
      presentation: map.containsKey('presentation')
          ? _decodeChoicePresentation(
              map['presentation'],
              bundlePath,
              '$path.presentation',
            )
          : null,
      availabilityCondition: map.containsKey('availabilityCondition')
          ? _decodeCondition(
              map['availabilityCondition'],
              bundlePath,
              '$path.availabilityCondition',
            )
          : null,
      effects: [
        for (var index = 0; index < effects.length; index++)
          _decodeEffect(effects[index], bundlePath, '$path.effects[$index]'),
      ],
      transition: map.containsKey('transition')
          ? _decodeTransition(map['transition'], bundlePath, '$path.transition')
          : null,
    ),
  );
}

Map<String, Object?> _encodeEventPresentation(
  StoryEventPresentation presentation,
) {
  final result = <String, Object?>{};
  final title = presentation.title;
  if (title != null) {
    result['title'] = title.value;
  }
  final body = presentation.body;
  if (body != null) {
    result['body'] = body.value;
  }
  return result;
}

StoryEventPresentation _decodeEventPresentation(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'title', 'body'}, bundlePath, path);
  final title = map.containsKey('title')
      ? StoryText(_string(map['title'], bundlePath, '$path.title'))
      : null;
  final body = map.containsKey('body')
      ? StoryText(_string(map['body'], bundlePath, '$path.body'))
      : null;
  if (title == null && body == null) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Event presentation requires a title, a body, or both.',
    );
  }
  return StoryEventPresentation(title: title, body: body);
}

Map<String, Object?> _encodeChoicePresentation(
  StoryChoicePresentation presentation,
) => <String, Object?>{'text': presentation.text.value};

StoryChoicePresentation _decodeChoicePresentation(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'text'}, bundlePath, path);
  return StoryChoicePresentation(
    text: StoryText(
      _string(
        _required(map, 'text', bundlePath, path),
        bundlePath,
        '$path.text',
      ),
    ),
  );
}

Map<String, Object?> _encodeCondition(StoryCondition condition) =>
    switch (condition) {
      StoryAllCondition(:final conditions) => <String, Object?>{
        'kind': 'all',
        'conditions': conditions.map(_encodeCondition).toList(growable: false),
      },
      StoryAnyCondition(:final conditions) => <String, Object?>{
        'kind': 'any',
        'conditions': conditions.map(_encodeCondition).toList(growable: false),
      },
      StoryNotCondition(:final condition) => <String, Object?>{
        'kind': 'not',
        'condition': _encodeCondition(condition),
      },
      StoryVariableIsSetCondition(:final variableId) => <String, Object?>{
        'kind': 'variable_is_set',
        'variableId': variableId.value,
      },
      StoryVariableIsUnsetCondition(:final variableId) => <String, Object?>{
        'kind': 'variable_is_unset',
        'variableId': variableId.value,
      },
      StoryVariableComparisonCondition(
        :final variableId,
        :final operator,
        :final value,
      ) => <String, Object?>{
        'kind': 'variable_comparison',
        'variableId': variableId.value,
        'operator': _comparisonOperatorToken(operator),
        'value': _encodeValue(value),
      },
    };

StoryCondition _decodeCondition(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  final kind = _string(
    _required(map, 'kind', bundlePath, path),
    bundlePath,
    '$path.kind',
  );

  return switch (kind) {
    'all' => _decodeConditionGroup(map, bundlePath, path, all: true),
    'any' => _decodeConditionGroup(map, bundlePath, path, all: false),
    'not' => _decodeNotCondition(map, bundlePath, path),
    'variable_is_set' => _decodeVariablePresenceCondition(
      map,
      bundlePath,
      path,
      isSet: true,
    ),
    'variable_is_unset' => _decodeVariablePresenceCondition(
      map,
      bundlePath,
      path,
      isSet: false,
    ),
    'variable_comparison' => _decodeVariableComparisonCondition(
      map,
      bundlePath,
      path,
    ),
    _ => throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: '$path.kind',
      message: 'Unknown Story Format v1 condition kind "$kind".',
    ),
  };
}

StoryCondition _decodeConditionGroup(
  Map<String, Object?> map,
  String bundlePath,
  String path, {
  required bool all,
}) {
  _allowOnly(map, const {'kind', 'conditions'}, bundlePath, path);
  final conditions = _list(
    _required(map, 'conditions', bundlePath, path),
    bundlePath,
    '$path.conditions',
  );
  return _checked(
    bundlePath,
    path,
    () => all
        ? StoryAllCondition([
            for (var index = 0; index < conditions.length; index++)
              _decodeCondition(
                conditions[index],
                bundlePath,
                '$path.conditions[$index]',
              ),
          ])
        : StoryAnyCondition([
            for (var index = 0; index < conditions.length; index++)
              _decodeCondition(
                conditions[index],
                bundlePath,
                '$path.conditions[$index]',
              ),
          ]),
  );
}

StoryCondition _decodeNotCondition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(map, const {'kind', 'condition'}, bundlePath, path);
  return StoryNotCondition(
    _decodeCondition(
      _required(map, 'condition', bundlePath, path),
      bundlePath,
      '$path.condition',
    ),
  );
}

StoryCondition _decodeVariablePresenceCondition(
  Map<String, Object?> map,
  String bundlePath,
  String path, {
  required bool isSet,
}) {
  _allowOnly(map, const {'kind', 'variableId'}, bundlePath, path);
  final variableId = _checked(
    bundlePath,
    '$path.variableId',
    () => StoryVariableId(
      _string(
        _required(map, 'variableId', bundlePath, path),
        bundlePath,
        '$path.variableId',
      ),
    ),
  );
  return isSet
      ? StoryVariableIsSetCondition(variableId: variableId)
      : StoryVariableIsUnsetCondition(variableId: variableId);
}

StoryCondition _decodeVariableComparisonCondition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(
    map,
    const {'kind', 'variableId', 'operator', 'value'},
    bundlePath,
    path,
  );
  return _checked(
    bundlePath,
    path,
    () => StoryVariableComparisonCondition(
      variableId: StoryVariableId(
        _string(
          _required(map, 'variableId', bundlePath, path),
          bundlePath,
          '$path.variableId',
        ),
      ),
      operator: _decodeComparisonOperator(
        _string(
          _required(map, 'operator', bundlePath, path),
          bundlePath,
          '$path.operator',
        ),
        bundlePath,
        '$path.operator',
      ),
      value: _decodeValue(
        _required(map, 'value', bundlePath, path),
        bundlePath,
        '$path.value',
      ),
    ),
  );
}

Map<String, Object?> _encodeEffect(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect(:final variableId, :final value) => <String, Object?>{
    'kind': 'set_variable',
    'variableId': variableId.value,
    'value': _encodeValue(value),
  },
  StoryUnsetVariableEffect(:final variableId) => <String, Object?>{
    'kind': 'unset_variable',
    'variableId': variableId.value,
  },
  StoryIncrementVariableEffect(:final variableId, :final amount) =>
    <String, Object?>{
      'kind': 'increment_variable',
      'variableId': variableId.value,
      'amount': _encodeValue(amount),
    },
  StoryDecrementVariableEffect(:final variableId, :final amount) =>
    <String, Object?>{
      'kind': 'decrement_variable',
      'variableId': variableId.value,
      'amount': _encodeValue(amount),
    },
};

StoryEffect _decodeEffect(Object? encoded, String bundlePath, String path) {
  final map = _map(encoded, bundlePath, path);
  final kind = _string(
    _required(map, 'kind', bundlePath, path),
    bundlePath,
    '$path.kind',
  );
  final variableId = _checked(
    bundlePath,
    '$path.variableId',
    () => StoryVariableId(
      _string(
        _required(map, 'variableId', bundlePath, path),
        bundlePath,
        '$path.variableId',
      ),
    ),
  );

  return switch (kind) {
    'set_variable' => _decodeSetEffect(map, bundlePath, path, variableId),
    'unset_variable' => _decodeUnsetEffect(map, bundlePath, path, variableId),
    'increment_variable' => _decodeAdjustmentEffect(
      map,
      bundlePath,
      path,
      variableId,
      increment: true,
    ),
    'decrement_variable' => _decodeAdjustmentEffect(
      map,
      bundlePath,
      path,
      variableId,
      increment: false,
    ),
    _ => throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: '$path.kind',
      message: 'Unknown Story Format v1 effect kind "$kind".',
    ),
  };
}

StoryEffect _decodeSetEffect(
  Map<String, Object?> map,
  String bundlePath,
  String path,
  StoryVariableId variableId,
) {
  _allowOnly(map, const {'kind', 'variableId', 'value'}, bundlePath, path);
  return StorySetVariableEffect(
    variableId: variableId,
    value: _decodeValue(
      _required(map, 'value', bundlePath, path),
      bundlePath,
      '$path.value',
    ),
  );
}

StoryEffect _decodeUnsetEffect(
  Map<String, Object?> map,
  String bundlePath,
  String path,
  StoryVariableId variableId,
) {
  _allowOnly(map, const {'kind', 'variableId'}, bundlePath, path);
  return StoryUnsetVariableEffect(variableId: variableId);
}

StoryEffect _decodeAdjustmentEffect(
  Map<String, Object?> map,
  String bundlePath,
  String path,
  StoryVariableId variableId, {
  required bool increment,
}) {
  _allowOnly(map, const {'kind', 'variableId', 'amount'}, bundlePath, path);
  final amount = _decodeValue(
    _required(map, 'amount', bundlePath, path),
    bundlePath,
    '$path.amount',
  );
  return _checked(
    bundlePath,
    path,
    () => increment
        ? StoryIncrementVariableEffect(variableId: variableId, amount: amount)
        : StoryDecrementVariableEffect(variableId: variableId, amount: amount),
  );
}

Map<String, Object?> _encodeTransition(StoryTransition transition) =>
    switch (transition) {
      StoryEventTransition(:final destinationEventId) => <String, Object?>{
        'kind': 'event',
        'destinationEventId': destinationEventId.value,
      },
      StoryConditionalTransition(:final branches, :final fallback) =>
        <String, Object?>{
          'kind': 'conditional',
          'branches': branches
              .map(
                (branch) => <String, Object?>{
                  'condition': _encodeCondition(branch.condition),
                  'transition': _encodeTransition(branch.transition),
                },
              )
              .toList(growable: false),
          'fallback': _encodeTransition(fallback),
        },
      StoryWeightedTransition(:final options) => <String, Object?>{
        'kind': 'weighted',
        'options': options
            .map(
              (option) => <String, Object?>{
                'weight': option.weight,
                'transition': _encodeTransition(option.transition),
              },
            )
            .toList(growable: false),
      },
      StoryTerminalTransition() => <String, Object?>{'kind': 'terminal'},
    };

StoryTransition _decodeTransition(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  final kind = _string(
    _required(map, 'kind', bundlePath, path),
    bundlePath,
    '$path.kind',
  );
  return switch (kind) {
    'event' => _decodeEventTransition(map, bundlePath, path),
    'conditional' => _decodeConditionalTransition(map, bundlePath, path),
    'weighted' => _decodeWeightedTransition(map, bundlePath, path),
    'terminal' => _decodeTerminalTransition(map, bundlePath, path),
    _ => throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: '$path.kind',
      message: 'Unknown Story Format v1 transition kind "$kind".',
    ),
  };
}

StoryTransition _decodeEventTransition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(map, const {'kind', 'destinationEventId'}, bundlePath, path);
  return _checked(
    bundlePath,
    '$path.destinationEventId',
    () => StoryEventTransition(
      destinationEventId: StoryEventId(
        _string(
          _required(map, 'destinationEventId', bundlePath, path),
          bundlePath,
          '$path.destinationEventId',
        ),
      ),
    ),
  );
}

StoryTransition _decodeConditionalTransition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(map, const {'kind', 'branches', 'fallback'}, bundlePath, path);
  final branchesData = _list(
    _required(map, 'branches', bundlePath, path),
    bundlePath,
    '$path.branches',
  );
  final branches = <StoryConditionalTransitionBranch>[];
  for (var index = 0; index < branchesData.length; index++) {
    final branchPath = '$path.branches[$index]';
    final branch = _map(branchesData[index], bundlePath, branchPath);
    _allowOnly(
      branch,
      const {'condition', 'transition'},
      bundlePath,
      branchPath,
    );
    branches.add(
      StoryConditionalTransitionBranch(
        condition: _decodeCondition(
          _required(branch, 'condition', bundlePath, branchPath),
          bundlePath,
          '$branchPath.condition',
        ),
        transition: _decodeTransition(
          _required(branch, 'transition', bundlePath, branchPath),
          bundlePath,
          '$branchPath.transition',
        ),
      ),
    );
  }
  return _checked(
    bundlePath,
    path,
    () => StoryConditionalTransition(
      branches: branches,
      fallback: _decodeTransition(
        _required(map, 'fallback', bundlePath, path),
        bundlePath,
        '$path.fallback',
      ),
    ),
  );
}

StoryTransition _decodeWeightedTransition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(map, const {'kind', 'options'}, bundlePath, path);
  final optionsData = _list(
    _required(map, 'options', bundlePath, path),
    bundlePath,
    '$path.options',
  );
  final options = <StoryWeightedTransitionOption>[];
  for (var index = 0; index < optionsData.length; index++) {
    final optionPath = '$path.options[$index]';
    final option = _map(optionsData[index], bundlePath, optionPath);
    _allowOnly(
      option,
      const {'weight', 'transition'},
      bundlePath,
      optionPath,
    );
    options.add(
      _checked(
        bundlePath,
        optionPath,
        () => StoryWeightedTransitionOption(
          weight: _integer(
            _required(option, 'weight', bundlePath, optionPath),
            bundlePath,
            '$optionPath.weight',
          ),
          transition: _decodeTransition(
            _required(option, 'transition', bundlePath, optionPath),
            bundlePath,
            '$optionPath.transition',
          ),
        ),
      ),
    );
  }
  return _checked(
    bundlePath,
    path,
    () => StoryWeightedTransition(options: options),
  );
}

StoryTransition _decodeTerminalTransition(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) {
  _allowOnly(map, const {'kind'}, bundlePath, path);
  return const StoryTerminalTransition();
}

Map<String, Object?> _encodeValue(StoryValue value) => switch (value) {
  StoryBooleanValue(:final value) => <String, Object?>{
    'type': 'boolean',
    'value': value,
  },
  StoryIntegerValue(:final value) => <String, Object?>{
    'type': 'integer',
    'value': value,
  },
  StoryNumberValue(:final value) => <String, Object?>{
    'type': 'number',
    'value': value,
  },
  StoryStringValue(:final value) => <String, Object?>{
    'type': 'string',
    'value': value,
  },
};

StoryValue _decodeValue(Object? encoded, String bundlePath, String path) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'type', 'value'}, bundlePath, path);
  final type = _decodeValueType(
    _string(
      _required(map, 'type', bundlePath, path),
      bundlePath,
      '$path.type',
    ),
    bundlePath,
    '$path.type',
  );
  final value = _required(map, 'value', bundlePath, path);
  return _checked(
    bundlePath,
    path,
    () => switch (type) {
      StoryValueType.boolean => StoryBooleanValue(
        _boolean(value, bundlePath, '$path.value'),
      ),
      StoryValueType.integer => StoryIntegerValue(
        _integer(value, bundlePath, '$path.value'),
      ),
      StoryValueType.number => StoryNumberValue(
        _number(value, bundlePath, '$path.value'),
      ),
      StoryValueType.string => StoryStringValue(
        _string(value, bundlePath, '$path.value'),
      ),
    },
  );
}

Map<String, Object?> _encodeOrganization(
  StoryFormatOrganization organization,
) => <String, Object?>{
  'groups': organization.groups.map(_encodeGroup).toList(growable: false),
  'tags': organization.tags.map(_encodeTag).toList(growable: false),
};

StoryFormatOrganization _decodeOrganization(
  Object? encoded,
  String bundlePath,
) {
  const path = r'$';
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'groups', 'tags'}, bundlePath, path);
  final groups = _list(
    _required(map, 'groups', bundlePath, path),
    bundlePath,
    r'$.groups',
  );
  final tags = _list(
    _required(map, 'tags', bundlePath, path),
    bundlePath,
    r'$.tags',
  );
  return _checked(
    bundlePath,
    path,
    () => StoryFormatOrganization(
      groups: [
        for (var index = 0; index < groups.length; index++)
          _decodeGroup(groups[index], bundlePath, '\$.groups[$index]'),
      ],
      tags: [
        for (var index = 0; index < tags.length; index++)
          _decodeTag(tags[index], bundlePath, '\$.tags[$index]'),
      ],
    ),
  );
}

Map<String, Object?> _encodeGroup(StoryFormatGroup group) {
  final result = <String, Object?>{'id': group.id.value};
  _putAlias(result, group.alias);
  final label = group.label;
  if (label != null) {
    result['label'] = label.value;
  }
  result['eventIds'] = group.eventIds
      .map((eventId) => eventId.value)
      .toList(growable: false);
  result['children'] = group.children.map(_encodeGroup).toList(growable: false);
  return result;
}

StoryFormatGroup _decodeGroup(Object? encoded, String bundlePath, String path) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {'id', 'alias', 'label', 'eventIds', 'children'},
    bundlePath,
    path,
  );
  final eventIds = _list(
    _required(map, 'eventIds', bundlePath, path),
    bundlePath,
    '$path.eventIds',
  );
  final children = _list(
    _required(map, 'children', bundlePath, path),
    bundlePath,
    '$path.children',
  );
  return _checked(
    bundlePath,
    path,
    () => StoryFormatGroup(
      id: StoryFormatGroupId(
        _string(
          _required(map, 'id', bundlePath, path),
          bundlePath,
          '$path.id',
        ),
      ),
      alias: _decodeAlias(map, bundlePath, path),
      label: map.containsKey('label')
          ? StoryText(_string(map['label'], bundlePath, '$path.label'))
          : null,
      eventIds: [
        for (var index = 0; index < eventIds.length; index++)
          StoryEventId(
            _string(
              eventIds[index],
              bundlePath,
              '$path.eventIds[$index]',
            ),
          ),
      ],
      children: [
        for (var index = 0; index < children.length; index++)
          _decodeGroup(
            children[index],
            bundlePath,
            '$path.children[$index]',
          ),
      ],
    ),
  );
}

Map<String, Object?> _encodeTag(StoryFormatTag tag) {
  final result = <String, Object?>{'id': tag.id.value};
  _putAlias(result, tag.alias);
  final label = tag.label;
  if (label != null) {
    result['label'] = label.value;
  }
  result['eventIds'] = tag.eventIds
      .map((eventId) => eventId.value)
      .toList(growable: false);
  return result;
}

StoryFormatTag _decodeTag(Object? encoded, String bundlePath, String path) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {'id', 'alias', 'label', 'eventIds'},
    bundlePath,
    path,
  );
  final eventIds = _list(
    _required(map, 'eventIds', bundlePath, path),
    bundlePath,
    '$path.eventIds',
  );
  return _checked(
    bundlePath,
    path,
    () => StoryFormatTag(
      id: StoryFormatTagId(
        _string(
          _required(map, 'id', bundlePath, path),
          bundlePath,
          '$path.id',
        ),
      ),
      alias: _decodeAlias(map, bundlePath, path),
      label: map.containsKey('label')
          ? StoryText(_string(map['label'], bundlePath, '$path.label'))
          : null,
      eventIds: [
        for (var index = 0; index < eventIds.length; index++)
          StoryEventId(
            _string(
              eventIds[index],
              bundlePath,
              '$path.eventIds[$index]',
            ),
          ),
      ],
    ),
  );
}

Map<String, Object?> _encodeExtensions(
  List<StoryFormatExtensionAttachment> extensions,
) {
  final ordered = extensions.toList()..sort(_compareExtensions);
  return <String, Object?>{
    'attachments': ordered.map(_encodeExtension).toList(growable: false),
  };
}

List<StoryFormatExtensionAttachment> _decodeExtensions(
  Object? encoded,
  String bundlePath,
) {
  const path = r'$';
  final map = _map(encoded, bundlePath, path);
  _allowOnly(map, const {'attachments'}, bundlePath, path);
  final attachments = _list(
    _required(map, 'attachments', bundlePath, path),
    bundlePath,
    r'$.attachments',
  );
  final result = <StoryFormatExtensionAttachment>[
    for (var index = 0; index < attachments.length; index++)
      _decodeExtension(
        attachments[index],
        bundlePath,
        '\$.attachments[$index]',
      ),
  ];
  result.sort(_compareExtensions);
  return List<StoryFormatExtensionAttachment>.unmodifiable(result);
}

Map<String, Object?> _encodeExtension(
  StoryFormatExtensionAttachment attachment,
) => <String, Object?>{
  'namespace': attachment.namespace.value,
  'target': _encodeExtensionTarget(attachment.target),
  'payload': attachment.payload.value,
};

StoryFormatExtensionAttachment _decodeExtension(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  _allowOnly(
    map,
    const {'namespace', 'target', 'payload'},
    bundlePath,
    path,
  );
  return _checked(
    bundlePath,
    path,
    () => StoryFormatExtensionAttachment(
      namespace: StoryFormatExtensionNamespace(
        _string(
          _required(map, 'namespace', bundlePath, path),
          bundlePath,
          '$path.namespace',
        ),
      ),
      target: _decodeExtensionTarget(
        _required(map, 'target', bundlePath, path),
        bundlePath,
        '$path.target',
      ),
      payload: StoryFormatExtensionPayload(
        _required(map, 'payload', bundlePath, path),
      ),
    ),
  );
}

Map<String, Object?> _encodeExtensionTarget(StoryFormatExtensionTarget target) =>
    switch (target) {
      StoryFormatProjectExtensionTarget() => <String, Object?>{
        'kind': 'project',
      },
      StoryFormatEventExtensionTarget(:final eventId) => <String, Object?>{
        'kind': 'event',
        'id': eventId.value,
      },
      StoryFormatChoiceExtensionTarget(:final choiceId) => <String, Object?>{
        'kind': 'choice',
        'id': choiceId.value,
      },
      StoryFormatVariableExtensionTarget(:final variableId) => <String, Object?>{
        'kind': 'variable',
        'id': variableId.value,
      },
      StoryFormatGroupExtensionTarget(:final groupId) => <String, Object?>{
        'kind': 'group',
        'id': groupId.value,
      },
      StoryFormatTagExtensionTarget(:final tagId) => <String, Object?>{
        'kind': 'tag',
        'id': tagId.value,
      },
    };

StoryFormatExtensionTarget _decodeExtensionTarget(
  Object? encoded,
  String bundlePath,
  String path,
) {
  final map = _map(encoded, bundlePath, path);
  final kind = _string(
    _required(map, 'kind', bundlePath, path),
    bundlePath,
    '$path.kind',
  );
  if (kind == 'project') {
    _allowOnly(map, const {'kind'}, bundlePath, path);
    return const StoryFormatProjectExtensionTarget();
  }
  _allowOnly(map, const {'kind', 'id'}, bundlePath, path);
  final id = _string(
    _required(map, 'id', bundlePath, path),
    bundlePath,
    '$path.id',
  );
  return _checked(
    bundlePath,
    path,
    () => switch (kind) {
      'event' => StoryFormatEventExtensionTarget(StoryEventId(id)),
      'choice' => StoryFormatChoiceExtensionTarget(StoryChoiceId(id)),
      'variable' => StoryFormatVariableExtensionTarget(StoryVariableId(id)),
      'group' => StoryFormatGroupExtensionTarget(StoryFormatGroupId(id)),
      'tag' => StoryFormatTagExtensionTarget(StoryFormatTagId(id)),
      _ => throw StoryFormatCodecException(
        bundlePath: bundlePath,
        jsonPath: '$path.kind',
        message: 'Unknown Story Format v1 extension target kind "$kind".',
      ),
    },
  );
}

int _compareExtensions(
  StoryFormatExtensionAttachment left,
  StoryFormatExtensionAttachment right,
) {
  final leftTarget = _extensionTargetSortKey(left.target);
  final rightTarget = _extensionTargetSortKey(right.target);
  final targetCompare = leftTarget.compareTo(rightTarget);
  if (targetCompare != 0) {
    return targetCompare;
  }
  return left.namespace.value.compareTo(right.namespace.value);
}

String _extensionTargetSortKey(StoryFormatExtensionTarget target) =>
    switch (target) {
      StoryFormatProjectExtensionTarget() => '0:project',
      StoryFormatEventExtensionTarget(:final eventId) =>
        '1:event:${eventId.value}',
      StoryFormatChoiceExtensionTarget(:final choiceId) =>
        '2:choice:${choiceId.value}',
      StoryFormatVariableExtensionTarget(:final variableId) =>
        '3:variable:${variableId.value}',
      StoryFormatGroupExtensionTarget(:final groupId) =>
        '4:group:${groupId.value}',
      StoryFormatTagExtensionTarget(:final tagId) => '5:tag:${tagId.value}',
    };

String _valueTypeToken(StoryValueType type) => switch (type) {
  StoryValueType.boolean => 'boolean',
  StoryValueType.integer => 'integer',
  StoryValueType.number => 'number',
  StoryValueType.string => 'string',
};

StoryValueType _decodeValueType(
  String token,
  String bundlePath,
  String path,
) => switch (token) {
  'boolean' => StoryValueType.boolean,
  'integer' => StoryValueType.integer,
  'number' => StoryValueType.number,
  'string' => StoryValueType.string,
  _ => throw StoryFormatCodecException(
    bundlePath: bundlePath,
    jsonPath: path,
    message: 'Unknown Story Format v1 value type "$token".',
  ),
};

String _comparisonOperatorToken(StoryComparisonOperator operator) =>
    switch (operator) {
      StoryComparisonOperator.equal => 'equal',
      StoryComparisonOperator.notEqual => 'not_equal',
      StoryComparisonOperator.lessThan => 'less_than',
      StoryComparisonOperator.lessThanOrEqual => 'less_than_or_equal',
      StoryComparisonOperator.greaterThan => 'greater_than',
      StoryComparisonOperator.greaterThanOrEqual => 'greater_than_or_equal',
    };

StoryComparisonOperator _decodeComparisonOperator(
  String token,
  String bundlePath,
  String path,
) => switch (token) {
  'equal' => StoryComparisonOperator.equal,
  'not_equal' => StoryComparisonOperator.notEqual,
  'less_than' => StoryComparisonOperator.lessThan,
  'less_than_or_equal' => StoryComparisonOperator.lessThanOrEqual,
  'greater_than' => StoryComparisonOperator.greaterThan,
  'greater_than_or_equal' => StoryComparisonOperator.greaterThanOrEqual,
  _ => throw StoryFormatCodecException(
    bundlePath: bundlePath,
    jsonPath: path,
    message: 'Unknown Story Format v1 comparison operator "$token".',
  ),
};

void _putAlias(Map<String, Object?> result, StoryAlias? alias) {
  if (alias != null) {
    result['alias'] = alias.value;
  }
}

StoryAlias? _decodeAlias(
  Map<String, Object?> map,
  String bundlePath,
  String path,
) => map.containsKey('alias')
    ? _checked(
        bundlePath,
        '$path.alias',
        () => StoryAlias(_string(map['alias'], bundlePath, '$path.alias')),
      )
    : null;

const _jsonEncoder = JsonEncoder.withIndent('  ');

String _encodeCanonicalJson(Object? value) =>
    '${_jsonEncoder.convert(value)}\n';

Object? _decodeJson(String source, String bundlePath) {
  try {
    return jsonDecode(source);
  } catch (error) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: r'$',
      message: 'File is not valid JSON.',
      cause: error,
    );
  }
}

T _checked<T>(String bundlePath, String path, T Function() create) {
  try {
    return create();
  } on StoryFormatCodecException {
    rethrow;
  } on ArgumentError catch (error) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Decoded value violates the Story Format v1 data contract.',
      cause: error,
    );
  } on StateError catch (error) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Decoded value violates the Story Format v1 data contract.',
      cause: error,
    );
  }
}

Object? _required(
  Map<String, Object?> map,
  String key,
  String bundlePath,
  String path,
) {
  if (!map.containsKey(key)) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: '$path.$key',
      message: 'Required field is missing.',
    );
  }
  return map[key];
}

Map<String, Object?> _map(
  Object? value,
  String bundlePath,
  String path,
) {
  if (value is! Map) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected a JSON object.',
    );
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw StoryFormatCodecException(
        bundlePath: bundlePath,
        jsonPath: path,
        message: 'JSON object keys must be strings.',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String bundlePath, String path) {
  if (value is! List) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected a JSON array.',
    );
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String bundlePath, String path) {
  if (value is! String) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected a string.',
    );
  }
  return value;
}

bool _boolean(Object? value, String bundlePath, String path) {
  if (value is! bool) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected a boolean.',
    );
  }
  return value;
}

int _integer(Object? value, String bundlePath, String path) {
  if (value is! int) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected an integer.',
    );
  }
  return value;
}

double _number(Object? value, String bundlePath, String path) {
  if (value is! num) {
    throw StoryFormatCodecException(
      bundlePath: bundlePath,
      jsonPath: path,
      message: 'Expected a number.',
    );
  }
  return value.toDouble();
}

void _allowOnly(
  Map<String, Object?> map,
  Set<String> allowed,
  String bundlePath,
  String path,
) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw StoryFormatCodecException(
        bundlePath: bundlePath,
        jsonPath: '$path.$key',
        message: 'Unknown Story Format v1 core field. Unknown semantic data '
            'is not ignored silently; use an explicit extension payload for '
            'opaque metadata.',
      );
    }
  }
}
