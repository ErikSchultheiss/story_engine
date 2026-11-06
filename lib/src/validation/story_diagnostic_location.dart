import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';
import 'story_ordered_comparison.dart';

/// Kind of authored structure identified by a [StoryDiagnosticLocation].
enum StoryDiagnosticLocationKind {
  /// The project document itself.
  project,

  /// One authored event.
  event,

  /// One event-owned authored choice.
  choice,

  /// One declared story-state variable.
  variable,

  /// A condition nested in authored data.
  condition,

  /// An effect nested in authored data.
  effect,

  /// A transition nested in authored data.
  transition,
}

/// One machine-readable segment in a diagnostic structural path.
///
/// Paths deliberately use structured field/index segments rather than a
/// display string so Studio/CLI consumers can navigate authored trees without
/// parsing human-facing text.
sealed class StoryDiagnosticPathSegment
    implements Comparable<StoryDiagnosticPathSegment> {
  const StoryDiagnosticPathSegment();

  /// Creates a named authored-field segment.
  const factory StoryDiagnosticPathSegment.field(String name) =
      StoryDiagnosticFieldPathSegment;

  /// Creates a zero-based authored-list index segment.
  const factory StoryDiagnosticPathSegment.index(int index) =
      StoryDiagnosticIndexPathSegment;
}

/// Named authored-field segment in a diagnostic path.
final class StoryDiagnosticFieldPathSegment extends StoryDiagnosticPathSegment {
  /// Creates a field segment.
  const StoryDiagnosticFieldPathSegment(this.name) : assert(name != '');

  /// Machine-facing field name.
  final String name;

  @override
  int compareTo(StoryDiagnosticPathSegment other) {
    return switch (other) {
      StoryDiagnosticFieldPathSegment(name: final otherName) => name.compareTo(
        otherName,
      ),
      StoryDiagnosticIndexPathSegment() => -1,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticFieldPathSegment && other.name == name;

  @override
  int get hashCode => Object.hash(StoryDiagnosticFieldPathSegment, name);

  @override
  String toString() => name;
}

/// Zero-based authored-list index segment in a diagnostic path.
final class StoryDiagnosticIndexPathSegment extends StoryDiagnosticPathSegment {
  /// Creates a list-index segment.
  const StoryDiagnosticIndexPathSegment(this.index) : assert(index >= 0);

  /// Zero-based list position.
  final int index;

  @override
  int compareTo(StoryDiagnosticPathSegment other) {
    return switch (other) {
      StoryDiagnosticFieldPathSegment() => 1,
      StoryDiagnosticIndexPathSegment(index: final otherIndex) =>
        index.compareTo(otherIndex),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticIndexPathSegment && other.index == index;

  @override
  int get hashCode => Object.hash(StoryDiagnosticIndexPathSegment, index);

  @override
  String toString() => '[$index]';
}

/// Precise machine-readable location of one validation problem.
///
/// Stable typed entity IDs identify the authored subject where one exists.
/// [path] supplies structural detail for nested conditions/effects/transitions
/// and fields that do not have independent authored identity.
final class StoryDiagnosticLocation
    implements Comparable<StoryDiagnosticLocation> {
  StoryDiagnosticLocation._({
    required this.kind,
    required this.projectId,
    required this.eventId,
    required this.choiceId,
    required this.variableId,
    required Iterable<StoryDiagnosticPathSegment> path,
  }) : path = List<StoryDiagnosticPathSegment>.unmodifiable(path);

  /// Locates the project document or one of its fields.
  factory StoryDiagnosticLocation.project({
    required StoryProjectId projectId,
    Iterable<StoryDiagnosticPathSegment> path = const [],
  }) => StoryDiagnosticLocation._(
    kind: StoryDiagnosticLocationKind.project,
    projectId: projectId,
    eventId: null,
    choiceId: null,
    variableId: null,
    path: path,
  );

  /// Locates an event or one of its direct fields.
  factory StoryDiagnosticLocation.event({
    required StoryProjectId projectId,
    required StoryEventId eventId,
    Iterable<StoryDiagnosticPathSegment> path = const [],
  }) => StoryDiagnosticLocation._(
    kind: StoryDiagnosticLocationKind.event,
    projectId: projectId,
    eventId: eventId,
    choiceId: null,
    variableId: null,
    path: path,
  );

  /// Locates an event-owned choice or one of its direct fields.
  factory StoryDiagnosticLocation.choice({
    required StoryProjectId projectId,
    required StoryEventId eventId,
    required StoryChoiceId choiceId,
    Iterable<StoryDiagnosticPathSegment> path = const [],
  }) => StoryDiagnosticLocation._(
    kind: StoryDiagnosticLocationKind.choice,
    projectId: projectId,
    eventId: eventId,
    choiceId: choiceId,
    variableId: null,
    path: path,
  );

  /// Locates a declared scalar variable or one of its fields.
  factory StoryDiagnosticLocation.variable({
    required StoryProjectId projectId,
    required StoryVariableId variableId,
    Iterable<StoryDiagnosticPathSegment> path = const [],
  }) => StoryDiagnosticLocation._(
    kind: StoryDiagnosticLocationKind.variable,
    projectId: projectId,
    eventId: null,
    choiceId: null,
    variableId: variableId,
    path: path,
  );

  /// Locates a nested authored condition.
  factory StoryDiagnosticLocation.condition({
    required StoryProjectId projectId,
    StoryEventId? eventId,
    StoryChoiceId? choiceId,
    required Iterable<StoryDiagnosticPathSegment> path,
  }) => StoryDiagnosticLocation._nested(
    kind: StoryDiagnosticLocationKind.condition,
    projectId: projectId,
    eventId: eventId,
    choiceId: choiceId,
    path: path,
  );

  /// Locates a nested authored effect.
  factory StoryDiagnosticLocation.effect({
    required StoryProjectId projectId,
    StoryEventId? eventId,
    StoryChoiceId? choiceId,
    required Iterable<StoryDiagnosticPathSegment> path,
  }) => StoryDiagnosticLocation._nested(
    kind: StoryDiagnosticLocationKind.effect,
    projectId: projectId,
    eventId: eventId,
    choiceId: choiceId,
    path: path,
  );

  /// Locates a nested authored transition.
  factory StoryDiagnosticLocation.transition({
    required StoryProjectId projectId,
    StoryEventId? eventId,
    StoryChoiceId? choiceId,
    required Iterable<StoryDiagnosticPathSegment> path,
  }) => StoryDiagnosticLocation._nested(
    kind: StoryDiagnosticLocationKind.transition,
    projectId: projectId,
    eventId: eventId,
    choiceId: choiceId,
    path: path,
  );

  factory StoryDiagnosticLocation._nested({
    required StoryDiagnosticLocationKind kind,
    required StoryProjectId projectId,
    required StoryEventId? eventId,
    required StoryChoiceId? choiceId,
    required Iterable<StoryDiagnosticPathSegment> path,
  }) {
    final copiedPath = List<StoryDiagnosticPathSegment>.unmodifiable(path);
    if (copiedPath.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'Nested condition/effect/transition locations require a structural '
            'path.',
      );
    }
    if (choiceId != null && eventId == null) {
      throw ArgumentError.value(
        choiceId,
        'choiceId',
        'A choice-owned nested location also requires its event ID.',
      );
    }

    return StoryDiagnosticLocation._(
      kind: kind,
      projectId: projectId,
      eventId: eventId,
      choiceId: choiceId,
      variableId: null,
      path: copiedPath,
    );
  }

  /// Broad authored structure category at this location.
  final StoryDiagnosticLocationKind kind;

  /// Project containing this location.
  final StoryProjectId projectId;

  /// Enclosing/current event identity when applicable.
  final StoryEventId? eventId;

  /// Enclosing/current choice identity when applicable.
  final StoryChoiceId? choiceId;

  /// Variable identity when [kind] is [StoryDiagnosticLocationKind.variable].
  final StoryVariableId? variableId;

  /// Structured path from project root to the relevant authored structure.
  final List<StoryDiagnosticPathSegment> path;

  /// Compact machine-oriented rendering of [path].
  ///
  /// This is intended for logs/debugging. Consumers that navigate data should
  /// use the structured [path] segments directly.
  String get pathString {
    final buffer = StringBuffer();
    for (final segment in path) {
      switch (segment) {
        case StoryDiagnosticFieldPathSegment(:final name):
          if (buffer.length > 0) {
            buffer.write('.');
          }
          buffer.write(name);
        case StoryDiagnosticIndexPathSegment(:final index):
          buffer.write('[$index]');
      }
    }
    return buffer.toString();
  }

  /// Human-readable location including the most specific stable authored ID.
  ///
  /// This is intended for logs, console output, and developer diagnostics.
  /// Structured tooling should continue to use [kind], typed IDs, and [path]
  /// directly rather than parsing this string.
  String get displayString {
    final owner = switch (kind) {
      StoryDiagnosticLocationKind.project => 'project ${projectId.value}',
      StoryDiagnosticLocationKind.variable => 'variable ${variableId!.value}',
      StoryDiagnosticLocationKind.event => 'event ${eventId!.value}',
      StoryDiagnosticLocationKind.choice =>
        'choice ${choiceId!.value} in event ${eventId!.value}',
      StoryDiagnosticLocationKind.condition ||
      StoryDiagnosticLocationKind.effect ||
      StoryDiagnosticLocationKind.transition =>
        choiceId != null
            ? '${kind.name} in choice ${choiceId!.value} '
                  '(event ${eventId!.value})'
            : eventId != null
            ? '${kind.name} in event ${eventId!.value}'
            : '${kind.name} in project ${projectId.value}',
    };
    final renderedPath = pathString;
    return renderedPath.isEmpty ? owner : '$owner @ $renderedPath';
  }

  @override
  int compareTo(StoryDiagnosticLocation other) {
    var comparison = projectId.value.compareTo(other.projectId.value);
    if (comparison != 0) {
      return comparison;
    }

    comparison = _comparePaths(path, other.path);
    if (comparison != 0) {
      return comparison;
    }

    comparison = _locationKindPriority(
      kind,
    ).compareTo(_locationKindPriority(other.kind));
    if (comparison != 0) {
      return comparison;
    }

    comparison = _compareNullableString(eventId?.value, other.eventId?.value);
    if (comparison != 0) {
      return comparison;
    }

    comparison = _compareNullableString(choiceId?.value, other.choiceId?.value);
    if (comparison != 0) {
      return comparison;
    }

    return _compareNullableString(variableId?.value, other.variableId?.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticLocation &&
          other.kind == kind &&
          other.projectId == projectId &&
          other.eventId == eventId &&
          other.choiceId == choiceId &&
          other.variableId == variableId &&
          _orderedPathEqual(other.path, path);

  @override
  int get hashCode => Object.hash(
    StoryDiagnosticLocation,
    kind,
    projectId,
    eventId,
    choiceId,
    variableId,
    Object.hashAll(path),
  );

  @override
  String toString() {
    final renderedPath = pathString;
    return 'StoryDiagnosticLocation('
        'kind: ${kind.name}, '
        'project: ${projectId.value}, '
        'event: ${eventId?.value}, '
        'choice: ${choiceId?.value}, '
        'variable: ${variableId?.value}, '
        'path: ${renderedPath.isEmpty ? '<root>' : renderedPath}'
        ')';
  }
}

int _comparePaths(
  List<StoryDiagnosticPathSegment> left,
  List<StoryDiagnosticPathSegment> right,
) => compareStoryOrderedValues(left, right);

bool _orderedPathEqual(
  List<StoryDiagnosticPathSegment> left,
  List<StoryDiagnosticPathSegment> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _compareNullableString(String? left, String? right) {
  if (left == null) {
    return right == null ? 0 : -1;
  }
  if (right == null) {
    return 1;
  }
  return left.compareTo(right);
}

int _locationKindPriority(StoryDiagnosticLocationKind kind) => switch (kind) {
  StoryDiagnosticLocationKind.project => 0,
  StoryDiagnosticLocationKind.variable => 1,
  StoryDiagnosticLocationKind.event => 2,
  StoryDiagnosticLocationKind.choice => 3,
  StoryDiagnosticLocationKind.condition => 4,
  StoryDiagnosticLocationKind.effect => 5,
  StoryDiagnosticLocationKind.transition => 6,
};
