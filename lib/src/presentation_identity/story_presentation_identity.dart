import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_presentation_unit_id.dart';
import '../identity/story_project_id.dart';

const int _maxPortableInteger = 9007199254740991;

/// Current source-language presentation slot occupied by one stable unit.
enum StoryPresentationUnitKind { eventTitle, eventBody, choiceText }

/// Portable authored location of one presentation unit in the current source revision.
///
/// Location is deliberately not identity. A unit may move while retaining its
/// [StoryPresentationUnitId].
final class StoryPresentationUnitLocation {
  const StoryPresentationUnitLocation._({
    required this.kind,
    required this.eventId,
    this.choiceId,
  });

  /// Locates an event-title presentation unit.
  factory StoryPresentationUnitLocation.eventTitle(StoryEventId eventId) =>
      StoryPresentationUnitLocation._(
        kind: StoryPresentationUnitKind.eventTitle,
        eventId: eventId,
      );

  /// Locates an event-body presentation unit.
  factory StoryPresentationUnitLocation.eventBody(StoryEventId eventId) =>
      StoryPresentationUnitLocation._(
        kind: StoryPresentationUnitKind.eventBody,
        eventId: eventId,
      );

  /// Locates a choice-text presentation unit.
  factory StoryPresentationUnitLocation.choiceText({
    required StoryEventId eventId,
    required StoryChoiceId choiceId,
  }) => StoryPresentationUnitLocation._(
    kind: StoryPresentationUnitKind.choiceText,
    eventId: eventId,
    choiceId: choiceId,
  );

  /// Kind of source-language presentation slot.
  final StoryPresentationUnitKind kind;

  /// Event currently containing the source presentation unit.
  final StoryEventId eventId;

  /// Choice identity when [kind] is [StoryPresentationUnitKind.choiceText].
  final StoryChoiceId? choiceId;

  String get _canonicalKey => switch (kind) {
    StoryPresentationUnitKind.eventTitle => 'event_title:${eventId.value}',
    StoryPresentationUnitKind.eventBody => 'event_body:${eventId.value}',
    StoryPresentationUnitKind.choiceText =>
      'choice_text:${eventId.value}:${choiceId!.value}',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryPresentationUnitLocation &&
          other.kind == kind &&
          other.eventId == eventId &&
          other.choiceId == choiceId;

  @override
  int get hashCode => Object.hash(kind, eventId, choiceId);
}

/// Stable identity plus monotonic source revision for one presentation unit.
final class StoryPresentationUnitRecord {
  StoryPresentationUnitRecord({
    required this.unitId,
    required this.location,
    required int sourceRevision,
  }) : sourceRevision = _validateRevision(sourceRevision);

  /// Stable identity retained across wording edits and safe refactors.
  final StoryPresentationUnitId unitId;

  /// Current authored source slot for the unit.
  final StoryPresentationUnitLocation location;

  /// Positive producer-managed revision of the source-language content.
  final int sourceRevision;
}

/// Portable sidecar catalog for stable presentation identities and source revisions.
///
/// Revision 1 intentionally remains separate from frozen Story Format v1. It
/// records identity/revision metadata only; translations, audio files, timing,
/// speaker metadata, and review workflow belong to later contracts.
final class StoryPresentationIdentityCatalog {
  StoryPresentationIdentityCatalog({
    required this.projectId,
    Iterable<StoryPresentationUnitRecord> units = const [],
  }) : units = _copyUnits(units);

  /// Wire-contract identity for Stage 8N presentation-unit metadata.
  static const String contractId = 'open_story.presentation_identity_catalog';

  /// Current presentation-identity wire-contract version.
  static const int contractVersion = 1;

  /// Project whose presentation identities are described.
  final StoryProjectId projectId;

  /// Records in canonical presentation-unit-ID order.
  final List<StoryPresentationUnitRecord> units;

  /// Returns the record currently occupying [location], or null.
  StoryPresentationUnitRecord? unitAt(StoryPresentationUnitLocation location) {
    for (final unit in units) {
      if (unit.location == location) {
        return unit;
      }
    }
    return null;
  }
}

List<StoryPresentationUnitRecord> _copyUnits(
  Iterable<StoryPresentationUnitRecord> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.unitId.value.compareTo(b.unitId.value));
  final ids = <StoryPresentationUnitId>{};
  final locations = <String>{};
  for (final unit in result) {
    if (!ids.add(unit.unitId)) {
      throw ArgumentError('Duplicate presentation-unit ID ${unit.unitId}.');
    }
    if (!locations.add(unit.location._canonicalKey)) {
      throw ArgumentError(
        'Multiple presentation units occupy ${unit.location._canonicalKey}.',
      );
    }
  }
  return List<StoryPresentationUnitRecord>.unmodifiable(result);
}

int _validateRevision(int value) {
  if (value < 1 || value > _maxPortableInteger) {
    throw ArgumentError.value(
      value,
      'sourceRevision',
      'Source revisions must be positive exact portable integers.',
    );
  }
  return value;
}
