import 'dart:convert';

import '../../identity/story_choice_id.dart';
import '../../identity/story_event_id.dart';
import '../../identity/story_presentation_unit_id.dart';
import '../../identity/story_project_id.dart';
import '../story_presentation_identity.dart';

/// Strict data-format failure for the Stage 8N presentation-identity contract.
final class StoryPresentationIdentityFormatException implements Exception {
  const StoryPresentationIdentityFormatException(
    this.path,
    this.message, {
    this.cause,
  });

  final String path;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StoryPresentationIdentityFormatException at $path: $message';
}

/// Deterministic JSON codec for `open_story.presentation_identity_catalog` v1.
final class StoryPresentationIdentityCatalogCodec {
  const StoryPresentationIdentityCatalogCodec();

  String encode(StoryPresentationIdentityCatalog catalog) =>
      _pretty(<String, Object?>{
        'contract': StoryPresentationIdentityCatalog.contractId,
        'contractVersion': StoryPresentationIdentityCatalog.contractVersion,
        'projectId': catalog.projectId.value,
        'units': catalog.units
            .map(
              (unit) => <String, Object?>{
                'unitId': unit.unitId.value,
                'sourceRevision': unit.sourceRevision,
                'kind': _encodeKind(unit.location.kind),
                'eventId': unit.location.eventId.value,
                if (unit.location.choiceId != null)
                  'choiceId': unit.location.choiceId!.value,
              },
            )
            .toList(growable: false),
      });

  StoryPresentationIdentityCatalog decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'projectId',
      'units',
    }, r'$');
    if (_string(root['contract'], r'$.contract') !=
        StoryPresentationIdentityCatalog.contractId) {
      throw const StoryPresentationIdentityFormatException(
        r'$.contract',
        'Unsupported presentation-identity contract.',
      );
    }
    if (_integer(root['contractVersion'], r'$.contractVersion') !=
        StoryPresentationIdentityCatalog.contractVersion) {
      throw const StoryPresentationIdentityFormatException(
        r'$.contractVersion',
        'Unsupported presentation-identity contract version.',
      );
    }

    try {
      return StoryPresentationIdentityCatalog(
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        units: _list(root['units'], r'$.units').asMap().entries.map(
          (entry) => _decodeUnit(entry.value, r'$.units[${entry.key}]'),
        ),
      );
    } on StoryPresentationIdentityFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryPresentationIdentityFormatException(
        r'$',
        'Invalid presentation-identity catalog.',
        cause: error,
      );
    }
  }
}

StoryPresentationUnitRecord _decodeUnit(Object? raw, String path) {
  final object = _object(raw, path);
  _allowOnly(object, const {
    'unitId',
    'sourceRevision',
    'kind',
    'eventId',
    'choiceId',
  }, path);
  final kind = _decodeKind(_string(object['kind'], '$path.kind'), '$path.kind');
  final eventId = StoryEventId(_string(object['eventId'], '$path.eventId'));
  final location = switch (kind) {
    StoryPresentationUnitKind.eventTitle => _withoutChoice(
      object,
      path,
      StoryPresentationUnitLocation.eventTitle(eventId),
    ),
    StoryPresentationUnitKind.eventBody => _withoutChoice(
      object,
      path,
      StoryPresentationUnitLocation.eventBody(eventId),
    ),
    StoryPresentationUnitKind.choiceText =>
      StoryPresentationUnitLocation.choiceText(
        eventId: eventId,
        choiceId: StoryChoiceId(_string(object['choiceId'], '$path.choiceId')),
      ),
  };
  return StoryPresentationUnitRecord(
    unitId: StoryPresentationUnitId(_string(object['unitId'], '$path.unitId')),
    location: location,
    sourceRevision: _integer(object['sourceRevision'], '$path.sourceRevision'),
  );
}

StoryPresentationUnitLocation _withoutChoice(
  Map<String, Object?> object,
  String path,
  StoryPresentationUnitLocation location,
) {
  if (object.containsKey('choiceId')) {
    throw StoryPresentationIdentityFormatException(
      '$path.choiceId',
      'choiceId is valid only for choice_text units.',
    );
  }
  return location;
}

String _encodeKind(StoryPresentationUnitKind kind) => switch (kind) {
  StoryPresentationUnitKind.eventTitle => 'event_title',
  StoryPresentationUnitKind.eventBody => 'event_body',
  StoryPresentationUnitKind.choiceText => 'choice_text',
};

StoryPresentationUnitKind _decodeKind(String value, String path) =>
    switch (value) {
      'event_title' => StoryPresentationUnitKind.eventTitle,
      'event_body' => StoryPresentationUnitKind.eventBody,
      'choice_text' => StoryPresentationUnitKind.choiceText,
      _ => throw StoryPresentationIdentityFormatException(
        path,
        'Unknown presentation-unit kind $value.',
      ),
    };

Map<String, Object?> _decodeRoot(String source) {
  try {
    return _object(jsonDecode(source), r'$');
  } on StoryPresentationIdentityFormatException {
    rethrow;
  } on Object catch (error) {
    throw StoryPresentationIdentityFormatException(
      r'$',
      'Document must be valid JSON.',
      cause: error,
    );
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw StoryPresentationIdentityFormatException(
      path,
      'Expected JSON object.',
    );
  }
  return value;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List<Object?>) {
    throw StoryPresentationIdentityFormatException(
      path,
      'Expected JSON array.',
    );
  }
  return value;
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryPresentationIdentityFormatException(path, 'Expected string.');
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryPresentationIdentityFormatException(path, 'Expected integer.');
  }
  return value;
}

void _allowOnly(Map<String, Object?> value, Set<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw StoryPresentationIdentityFormatException(
        '$path.$key',
        'Unknown field $key.',
      );
    }
  }
}

String _pretty(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';
