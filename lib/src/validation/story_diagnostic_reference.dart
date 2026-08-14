import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';

/// Authored entity namespace carried by a [StoryDiagnosticReference].
enum StoryDiagnosticReferenceKind {
  /// A project identity.
  project,

  /// An event identity.
  event,

  /// A choice identity.
  choice,

  /// A state-variable identity.
  variable,
}

/// Machine-readable entity identity relevant to a diagnostic.
///
/// Unlike `StoryDiagnosticLocation`, a reference does not imply that the entity
/// exists. This is important for diagnostics such as a missing transition
/// destination or an undeclared variable reference: tooling still needs the
/// unresolved ID in structured form.
final class StoryDiagnosticReference
    implements Comparable<StoryDiagnosticReference> {
  const StoryDiagnosticReference._({
    required this.kind,
    required this.value,
  });

  /// Creates a project reference.
  factory StoryDiagnosticReference.project(StoryProjectId id) =>
      StoryDiagnosticReference._(
        kind: StoryDiagnosticReferenceKind.project,
        value: id.value,
      );

  /// Creates an event reference, including an unresolved destination ID.
  factory StoryDiagnosticReference.event(StoryEventId id) =>
      StoryDiagnosticReference._(
        kind: StoryDiagnosticReferenceKind.event,
        value: id.value,
      );

  /// Creates a choice reference.
  factory StoryDiagnosticReference.choice(StoryChoiceId id) =>
      StoryDiagnosticReference._(
        kind: StoryDiagnosticReferenceKind.choice,
        value: id.value,
      );

  /// Creates a variable reference, including an undeclared variable ID.
  factory StoryDiagnosticReference.variable(StoryVariableId id) =>
      StoryDiagnosticReference._(
        kind: StoryDiagnosticReferenceKind.variable,
        value: id.value,
      );

  /// Entity namespace of this identity.
  final StoryDiagnosticReferenceKind kind;

  /// Raw stable machine ID token.
  final String value;

  @override
  int compareTo(StoryDiagnosticReference other) {
    final kindComparison = _referenceKindPriority(kind).compareTo(
      _referenceKindPriority(other.kind),
    );
    if (kindComparison != 0) {
      return kindComparison;
    }
    return value.compareTo(other.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDiagnosticReference &&
          other.kind == kind &&
          other.value == value;

  @override
  int get hashCode => Object.hash(StoryDiagnosticReference, kind, value);

  @override
  String toString() => '${kind.name}:$value';
}

int _referenceKindPriority(StoryDiagnosticReferenceKind kind) => switch (kind) {
  StoryDiagnosticReferenceKind.project => 0,
  StoryDiagnosticReferenceKind.event => 1,
  StoryDiagnosticReferenceKind.choice => 2,
  StoryDiagnosticReferenceKind.variable => 3,
};
