import 'dart:convert';

import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_alias.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_choice.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../presentation/story_choice_presentation.dart';
import '../presentation/story_event_presentation.dart';
import '../presentation/story_text.dart';
import '../state/story_state_schema.dart';
import '../state/story_value.dart';
import '../state/story_value_type.dart';
import '../state/story_variable_definition.dart';
import '../transition/story_transition.dart';

/// Internal Stage 1I codec for proving the authored-project serialization
/// boundary before Story Format v1 is designed and frozen.
///
/// This type is intentionally not exported from `package:story_engine/`.
/// Its draft document shape may change incompatibly during foundation work.
final class StoryProjectDraftCodec {
  const StoryProjectDraftCodec();

  static const String documentType = 'story_engine_project_draft';
  static const int draftRevision = 3;
  static const int oldestSupportedDraftRevision = 1;

  /// Encodes [project] into a JSON-compatible deterministic data tree.
  Map<String, Object?> encode(StoryProject project) => <String, Object?>{
    'documentType': documentType,
    'draftRevision': draftRevision,
    'project': _encodeProject(project),
  };

  /// Decodes one draft authored-project data tree.
  ///
  /// This is intentionally strict about unknown keys so a newer document is
  /// never silently loaded and then re-saved with unsupported data discarded.
  StoryProject decode(Object? encoded) {
    try {
      final root = _map(encoded, r'$');
      _allowOnly(
        root,
        const {'documentType', 'draftRevision', 'project'},
        r'$',
      );

      final type = _string(
        _required(root, 'documentType', r'$'),
        r'$.documentType',
      );
      if (type != documentType) {
        throw StoryDraftSerializationException(
          r'$.documentType',
          'Expected "$documentType", got "$type".',
        );
      }

      final revision = _integer(
        _required(root, 'draftRevision', r'$'),
        r'$.draftRevision',
      );
      if (revision < oldestSupportedDraftRevision || revision > draftRevision) {
        throw StoryDraftSerializationException(
          r'$.draftRevision',
          'Unsupported internal draft revision $revision. Supported range is '
          '$oldestSupportedDraftRevision..$draftRevision.',
        );
      }

      return _decodeProject(
        _required(root, 'project', r'$'),
        r'$.project',
        draftRevision: revision,
      );
    } on StoryDraftSerializationException {
      rethrow;
    } catch (error) {
      throw StoryDraftSerializationException(
        r'$',
        'Invalid Stage 1I draft project data.',
        cause: error,
      );
    }
  }

  /// Encodes [project] as compact deterministic JSON.
  String encodeJson(StoryProject project) => jsonEncode(encode(project));

  /// Decodes compact or pretty-printed JSON containing the internal draft
  /// document shape.
  StoryProject decodeJson(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error) {
      throw StoryDraftSerializationException(
        r'$',
        'Input is not valid JSON.',
        cause: error,
      );
    }
    return decode(decoded);
  }
}

/// Internal structured failure for the provisional Stage 1I draft codec.
///
/// The exception is intentionally package-private with the codec. Public
/// persistence/format diagnostics will be designed with Story Format v1.
final class StoryDraftSerializationException implements Exception {
  const StoryDraftSerializationException(
    this.path,
    this.message, {
    this.cause,
  });

  final String path;
  final String message;
  final Object? cause;

  @override
  String toString() {
    final causeText = cause == null ? '' : ' Cause: $cause';
    return 'StoryDraftSerializationException at $path: $message$causeText';
  }
}

Map<String, Object?> _encodeProject(StoryProject project) {
  final result = <String, Object?>{
    'id': project.id.value,
  };
  _putAlias(result, project.alias);
  result['stateSchema'] = _encodeStateSchema(project.stateSchema);
  result['events'] = project.events.map(_encodeEvent).toList(growable: false);
  final entryEventId = project.entryEventId;
  if (entryEventId != null) {
    result['entryEventId'] = entryEventId.value;
  }
  return result;
}

StoryProject _decodeProject(
  Object? encoded,
  String path, {
  required int draftRevision,
}) {
  final map = _map(encoded, path);
  _allowOnly(
    map,
    const {'id', 'alias', 'stateSchema', 'events', 'entryEventId'},
    path,
  );

  return StoryProject(
    id: StoryProjectId(_string(_required(map, 'id', path), '$path.id')),
    alias: _decodeAlias(map, path),
    stateSchema: _decodeStateSchema(
      _required(map, 'stateSchema', path),
      '$path.stateSchema',
    ),
    events: _list(_required(map, 'events', path), '$path.events')
        .indexed
        .map(
          (entry) => _decodeEvent(
            entry.$2,
            '$path.events[${entry.$1}]',
            draftRevision: draftRevision,
          ),
        ),
    entryEventId: map.containsKey('entryEventId')
        ? StoryEventId(_string(map['entryEventId'], '$path.entryEventId'))
        : null,
  );
}

Map<String, Object?> _encodeStateSchema(StoryStateSchema schema) =>
    <String, Object?>{
      'variables': schema.variables
          .map(_encodeVariableDefinition)
          .toList(growable: false),
    };

StoryStateSchema _decodeStateSchema(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'variables'}, path);
  return StoryStateSchema(
    variables: _list(_required(map, 'variables', path), '$path.variables')
        .indexed
        .map(
          (entry) => _decodeVariableDefinition(
            entry.$2,
            '$path.variables[${entry.$1}]',
          ),
        ),
  );
}

Map<String, Object?> _encodeVariableDefinition(
  StoryVariableDefinition definition,
) {
  final result = <String, Object?>{
    'id': definition.id.value,
    'type': definition.type.name,
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
  String path,
) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'id', 'alias', 'type', 'initialValue'}, path);
  final type = _decodeValueType(
    _string(_required(map, 'type', path), '$path.type'),
    '$path.type',
  );

  return StoryVariableDefinition(
    id: StoryVariableId(_string(_required(map, 'id', path), '$path.id')),
    alias: _decodeAlias(map, path),
    type: type,
    initialValue: map.containsKey('initialValue')
        ? _decodeValue(map['initialValue'], '$path.initialValue')
        : null,
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

StoryEvent _decodeEvent(
  Object? encoded,
  String path, {
  required int draftRevision,
}) {
  final map = _map(encoded, path);
  _allowOnly(
    map,
    draftRevision >= 3
        ? const {
            'id',
            'alias',
            'presentation',
            'availabilityCondition',
            'entryEffects',
            'choices',
            'continuationTransition',
            'automaticTransition',
          }
        : draftRevision >= 2
        ? const {
            'id',
            'alias',
            'presentation',
            'availabilityCondition',
            'entryEffects',
            'choices',
            'automaticTransition',
          }
        : const {
            'id',
            'alias',
            'availabilityCondition',
            'entryEffects',
            'choices',
            'automaticTransition',
          },
    path,
  );

  return StoryEvent(
    id: StoryEventId(_string(_required(map, 'id', path), '$path.id')),
    alias: _decodeAlias(map, path),
    presentation: map.containsKey('presentation')
        ? _decodeEventPresentation(map['presentation'], '$path.presentation')
        : null,
    availabilityCondition: map.containsKey('availabilityCondition')
        ? _decodeCondition(
            map['availabilityCondition'],
            '$path.availabilityCondition',
          )
        : null,
    entryEffects: _list(
      _required(map, 'entryEffects', path),
      '$path.entryEffects',
    ).indexed.map(
      (entry) => _decodeEffect(entry.$2, '$path.entryEffects[${entry.$1}]'),
    ),
    choices: _list(
      _required(map, 'choices', path),
      '$path.choices',
    ).indexed.map(
      (entry) => _decodeChoice(
        entry.$2,
        '$path.choices[${entry.$1}]',
        draftRevision: draftRevision,
      ),
    ),
    continuationTransition: map.containsKey('continuationTransition')
        ? _decodeTransition(
            map['continuationTransition'],
            '$path.continuationTransition',
          )
        : null,
    automaticTransition: map.containsKey('automaticTransition')
        ? _decodeTransition(
            map['automaticTransition'],
            '$path.automaticTransition',
          )
        : null,
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

StoryChoice _decodeChoice(
  Object? encoded,
  String path, {
  required int draftRevision,
}) {
  final map = _map(encoded, path);
  _allowOnly(
    map,
    draftRevision >= 2
        ? const {
            'id',
            'alias',
            'presentation',
            'availabilityCondition',
            'effects',
            'transition',
          }
        : const {
            'id',
            'alias',
            'availabilityCondition',
            'effects',
            'transition',
          },
    path,
  );

  return StoryChoice(
    id: StoryChoiceId(_string(_required(map, 'id', path), '$path.id')),
    alias: _decodeAlias(map, path),
    presentation: map.containsKey('presentation')
        ? _decodeChoicePresentation(map['presentation'], '$path.presentation')
        : null,
    availabilityCondition: map.containsKey('availabilityCondition')
        ? _decodeCondition(
            map['availabilityCondition'],
            '$path.availabilityCondition',
          )
        : null,
    effects: _list(
      _required(map, 'effects', path),
      '$path.effects',
    ).indexed.map(
      (entry) => _decodeEffect(entry.$2, '$path.effects[${entry.$1}]'),
    ),
    transition: map.containsKey('transition')
        ? _decodeTransition(map['transition'], '$path.transition')
        : null,
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

StoryEventPresentation _decodeEventPresentation(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'title', 'body'}, path);

  final title = map.containsKey('title')
      ? StoryText(_string(map['title'], '$path.title'))
      : null;
  final body = map.containsKey('body')
      ? StoryText(_string(map['body'], '$path.body'))
      : null;

  if (title == null && body == null) {
    throw StoryDraftSerializationException(
      path,
      'Event presentation requires a title, a body, or both.',
    );
  }
  return StoryEventPresentation(title: title, body: body);
}

Map<String, Object?> _encodeChoicePresentation(
  StoryChoicePresentation presentation,
) => <String, Object?>{'text': presentation.text.value};

StoryChoicePresentation _decodeChoicePresentation(
  Object? encoded,
  String path,
) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'text'}, path);
  return StoryChoicePresentation(
    text: StoryText(_string(_required(map, 'text', path), '$path.text')),
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
        'kind': 'variableIsSet',
        'variableId': variableId.value,
      },
      StoryVariableIsUnsetCondition(:final variableId) => <String, Object?>{
        'kind': 'variableIsUnset',
        'variableId': variableId.value,
      },
      StoryVariableComparisonCondition(
        :final variableId,
        :final operator,
        :final value,
      ) => <String, Object?>{
        'kind': 'variableComparison',
        'variableId': variableId.value,
        'operator': operator.name,
        'value': _encodeValue(value),
      },
    };

StoryCondition _decodeCondition(Object? encoded, String path) {
  final map = _map(encoded, path);
  final kind = _string(_required(map, 'kind', path), '$path.kind');

  return switch (kind) {
    'all' => _decodeConditionGroup(map, path, all: true),
    'any' => _decodeConditionGroup(map, path, all: false),
    'not' => _decodeNotCondition(map, path),
    'variableIsSet' => _decodeVariablePresenceCondition(map, path, isSet: true),
    'variableIsUnset' => _decodeVariablePresenceCondition(
      map,
      path,
      isSet: false,
    ),
    'variableComparison' => _decodeVariableComparisonCondition(map, path),
    _ => throw StoryDraftSerializationException(
      '$path.kind',
      'Unknown condition kind "$kind".',
    ),
  };
}

StoryCondition _decodeConditionGroup(
  Map<String, Object?> map,
  String path, {
  required bool all,
}) {
  _allowOnly(map, const {'kind', 'conditions'}, path);
  final conditions = _list(
    _required(map, 'conditions', path),
    '$path.conditions',
  ).indexed.map(
    (entry) => _decodeCondition(entry.$2, '$path.conditions[${entry.$1}]'),
  );
  return all ? StoryAllCondition(conditions) : StoryAnyCondition(conditions);
}

StoryCondition _decodeNotCondition(Map<String, Object?> map, String path) {
  _allowOnly(map, const {'kind', 'condition'}, path);
  return StoryNotCondition(
    _decodeCondition(_required(map, 'condition', path), '$path.condition'),
  );
}

StoryCondition _decodeVariablePresenceCondition(
  Map<String, Object?> map,
  String path, {
  required bool isSet,
}) {
  _allowOnly(map, const {'kind', 'variableId'}, path);
  final variableId = StoryVariableId(
    _string(_required(map, 'variableId', path), '$path.variableId'),
  );
  return isSet
      ? StoryVariableIsSetCondition(variableId: variableId)
      : StoryVariableIsUnsetCondition(variableId: variableId);
}

StoryCondition _decodeVariableComparisonCondition(
  Map<String, Object?> map,
  String path,
) {
  _allowOnly(map, const {'kind', 'variableId', 'operator', 'value'}, path);
  return StoryVariableComparisonCondition(
    variableId: StoryVariableId(
      _string(_required(map, 'variableId', path), '$path.variableId'),
    ),
    operator: _decodeComparisonOperator(
      _string(_required(map, 'operator', path), '$path.operator'),
      '$path.operator',
    ),
    value: _decodeValue(_required(map, 'value', path), '$path.value'),
  );
}

Map<String, Object?> _encodeEffect(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect(:final variableId, :final value) => <String, Object?>{
    'kind': 'setVariable',
    'variableId': variableId.value,
    'value': _encodeValue(value),
  },
  StoryUnsetVariableEffect(:final variableId) => <String, Object?>{
    'kind': 'unsetVariable',
    'variableId': variableId.value,
  },
  StoryIncrementVariableEffect(:final variableId, :final amount) =>
    <String, Object?>{
      'kind': 'incrementVariable',
      'variableId': variableId.value,
      'amount': _encodeValue(amount),
    },
  StoryDecrementVariableEffect(:final variableId, :final amount) =>
    <String, Object?>{
      'kind': 'decrementVariable',
      'variableId': variableId.value,
      'amount': _encodeValue(amount),
    },
};

StoryEffect _decodeEffect(Object? encoded, String path) {
  final map = _map(encoded, path);
  final kind = _string(_required(map, 'kind', path), '$path.kind');
  final variableId = StoryVariableId(
    _string(_required(map, 'variableId', path), '$path.variableId'),
  );

  return switch (kind) {
    'setVariable' => _decodeSetEffect(map, path, variableId),
    'unsetVariable' => _decodeUnsetEffect(map, path, variableId),
    'incrementVariable' => _decodeAdjustmentEffect(
      map,
      path,
      variableId,
      increment: true,
    ),
    'decrementVariable' => _decodeAdjustmentEffect(
      map,
      path,
      variableId,
      increment: false,
    ),
    _ => throw StoryDraftSerializationException(
      '$path.kind',
      'Unknown effect kind "$kind".',
    ),
  };
}

StoryEffect _decodeSetEffect(
  Map<String, Object?> map,
  String path,
  StoryVariableId variableId,
) {
  _allowOnly(map, const {'kind', 'variableId', 'value'}, path);
  return StorySetVariableEffect(
    variableId: variableId,
    value: _decodeValue(_required(map, 'value', path), '$path.value'),
  );
}

StoryEffect _decodeUnsetEffect(
  Map<String, Object?> map,
  String path,
  StoryVariableId variableId,
) {
  _allowOnly(map, const {'kind', 'variableId'}, path);
  return StoryUnsetVariableEffect(variableId: variableId);
}

StoryEffect _decodeAdjustmentEffect(
  Map<String, Object?> map,
  String path,
  StoryVariableId variableId, {
  required bool increment,
}) {
  _allowOnly(map, const {'kind', 'variableId', 'amount'}, path);
  final amount = _decodeValue(_required(map, 'amount', path), '$path.amount');
  return increment
      ? StoryIncrementVariableEffect(variableId: variableId, amount: amount)
      : StoryDecrementVariableEffect(variableId: variableId, amount: amount);
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

StoryTransition _decodeTransition(Object? encoded, String path) {
  final map = _map(encoded, path);
  final kind = _string(_required(map, 'kind', path), '$path.kind');

  return switch (kind) {
    'event' => _decodeEventTransition(map, path),
    'conditional' => _decodeConditionalTransition(map, path),
    'weighted' => _decodeWeightedTransition(map, path),
    'terminal' => _decodeTerminalTransition(map, path),
    _ => throw StoryDraftSerializationException(
      '$path.kind',
      'Unknown transition kind "$kind".',
    ),
  };
}

StoryTransition _decodeEventTransition(Map<String, Object?> map, String path) {
  _allowOnly(map, const {'kind', 'destinationEventId'}, path);
  return StoryEventTransition(
    destinationEventId: StoryEventId(
      _string(
        _required(map, 'destinationEventId', path),
        '$path.destinationEventId',
      ),
    ),
  );
}

StoryTransition _decodeConditionalTransition(
  Map<String, Object?> map,
  String path,
) {
  _allowOnly(map, const {'kind', 'branches', 'fallback'}, path);
  final branches = _list(
    _required(map, 'branches', path),
    '$path.branches',
  ).indexed.map((entry) {
    final branchPath = '$path.branches[${entry.$1}]';
    final branch = _map(entry.$2, branchPath);
    _allowOnly(branch, const {'condition', 'transition'}, branchPath);
    return StoryConditionalTransitionBranch(
      condition: _decodeCondition(
        _required(branch, 'condition', branchPath),
        '$branchPath.condition',
      ),
      transition: _decodeTransition(
        _required(branch, 'transition', branchPath),
        '$branchPath.transition',
      ),
    );
  });

  return StoryConditionalTransition(
    branches: branches,
    fallback: _decodeTransition(
      _required(map, 'fallback', path),
      '$path.fallback',
    ),
  );
}

StoryTransition _decodeWeightedTransition(
  Map<String, Object?> map,
  String path,
) {
  _allowOnly(map, const {'kind', 'options'}, path);
  final options = _list(
    _required(map, 'options', path),
    '$path.options',
  ).indexed.map((entry) {
    final optionPath = '$path.options[${entry.$1}]';
    final option = _map(entry.$2, optionPath);
    _allowOnly(option, const {'weight', 'transition'}, optionPath);
    return StoryWeightedTransitionOption(
      weight: _integer(
        _required(option, 'weight', optionPath),
        '$optionPath.weight',
      ),
      transition: _decodeTransition(
        _required(option, 'transition', optionPath),
        '$optionPath.transition',
      ),
    );
  });

  return StoryWeightedTransition(options: options);
}

StoryTransition _decodeTerminalTransition(
  Map<String, Object?> map,
  String path,
) {
  _allowOnly(map, const {'kind'}, path);
  return const StoryTerminalTransition();
}

Map<String, Object?> _encodeValue(StoryValue value) => switch (value) {
  StoryBooleanValue(:final value) => <String, Object?>{
    'type': StoryValueType.boolean.name,
    'value': value,
  },
  StoryIntegerValue(:final value) => <String, Object?>{
    'type': StoryValueType.integer.name,
    'value': value,
  },
  StoryNumberValue(:final value) => <String, Object?>{
    'type': StoryValueType.number.name,
    'value': value,
  },
  StoryStringValue(:final value) => <String, Object?>{
    'type': StoryValueType.string.name,
    'value': value,
  },
};

StoryValue _decodeValue(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'type', 'value'}, path);
  final type = _decodeValueType(
    _string(_required(map, 'type', path), '$path.type'),
    '$path.type',
  );
  final value = _required(map, 'value', path);

  return switch (type) {
    StoryValueType.boolean => StoryBooleanValue(_boolean(value, '$path.value')),
    StoryValueType.integer => StoryIntegerValue(_integer(value, '$path.value')),
    StoryValueType.number => StoryNumberValue(_number(value, '$path.value')),
    StoryValueType.string => StoryStringValue(_string(value, '$path.value')),
  };
}

StoryValueType _decodeValueType(String name, String path) {
  for (final type in StoryValueType.values) {
    if (type.name == name) {
      return type;
    }
  }
  throw StoryDraftSerializationException(
    path,
    'Unknown story value type "$name".',
  );
}

StoryComparisonOperator _decodeComparisonOperator(String name, String path) {
  for (final operator in StoryComparisonOperator.values) {
    if (operator.name == name) {
      return operator;
    }
  }
  throw StoryDraftSerializationException(
    path,
    'Unknown comparison operator "$name".',
  );
}

void _putAlias(Map<String, Object?> result, StoryAlias? alias) {
  if (alias != null) {
    result['alias'] = alias.value;
  }
}

StoryAlias? _decodeAlias(Map<String, Object?> map, String path) =>
    map.containsKey('alias')
        ? StoryAlias(_string(map['alias'], '$path.alias'))
        : null;

Object? _required(Map<String, Object?> map, String key, String path) {
  if (!map.containsKey(key)) {
    throw StoryDraftSerializationException(
      '$path.$key',
      'Required field is missing.',
    );
  }
  return map[key];
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) {
    throw StoryDraftSerializationException(path, 'Expected an object/map.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw StoryDraftSerializationException(
        path,
        'Object keys must be strings.',
      );
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) {
    throw StoryDraftSerializationException(path, 'Expected a list.');
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryDraftSerializationException(path, 'Expected a string.');
  }
  return value;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) {
    throw StoryDraftSerializationException(path, 'Expected a boolean.');
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryDraftSerializationException(path, 'Expected an integer.');
  }
  return value;
}

double _number(Object? value, String path) {
  if (value is! num) {
    throw StoryDraftSerializationException(path, 'Expected a number.');
  }
  return value.toDouble();
}

void _allowOnly(
  Map<String, Object?> map,
  Set<String> allowed,
  String path,
) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw StoryDraftSerializationException(
        '$path.$key',
        'Unknown field. Stage 1I draft decoding is strict to prevent data '
        'loss.',
      );
    }
  }
}
