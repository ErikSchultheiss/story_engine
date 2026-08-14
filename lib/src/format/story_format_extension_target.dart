import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import 'story_format_group_id.dart';
import 'story_format_tag_id.dart';

/// Stable-identity attachment point for opaque Story Format extension data.
///
/// V1 deliberately allows extensions only on entities with durable identity.
/// Conditions, effects, transition branches, and weighted options are not
/// extension targets because they currently have no independent stable IDs.
sealed class StoryFormatExtensionTarget {
  const StoryFormatExtensionTarget();
}

/// Project-wide extension attachment.
final class StoryFormatProjectExtensionTarget
    extends StoryFormatExtensionTarget {
  const StoryFormatProjectExtensionTarget();

  @override
  bool operator ==(Object other) => other is StoryFormatProjectExtensionTarget;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'StoryFormatProjectExtensionTarget()';
}

/// Extension attachment to one authored event identity.
final class StoryFormatEventExtensionTarget extends StoryFormatExtensionTarget {
  const StoryFormatEventExtensionTarget(this.eventId);

  final StoryEventId eventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatEventExtensionTarget && other.eventId == eventId;

  @override
  int get hashCode => Object.hash(StoryFormatEventExtensionTarget, eventId);

  @override
  String toString() => 'StoryFormatEventExtensionTarget($eventId)';
}

/// Extension attachment to one authored choice identity.
final class StoryFormatChoiceExtensionTarget
    extends StoryFormatExtensionTarget {
  const StoryFormatChoiceExtensionTarget(this.choiceId);

  final StoryChoiceId choiceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatChoiceExtensionTarget && other.choiceId == choiceId;

  @override
  int get hashCode => Object.hash(StoryFormatChoiceExtensionTarget, choiceId);

  @override
  String toString() => 'StoryFormatChoiceExtensionTarget($choiceId)';
}

/// Extension attachment to one authored scalar-variable identity.
final class StoryFormatVariableExtensionTarget
    extends StoryFormatExtensionTarget {
  const StoryFormatVariableExtensionTarget(this.variableId);

  final StoryVariableId variableId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatVariableExtensionTarget &&
          other.variableId == variableId;

  @override
  int get hashCode => Object.hash(StoryFormatVariableExtensionTarget, variableId);

  @override
  String toString() => 'StoryFormatVariableExtensionTarget($variableId)';
}

/// Extension attachment to one authoring-group identity.
final class StoryFormatGroupExtensionTarget extends StoryFormatExtensionTarget {
  const StoryFormatGroupExtensionTarget(this.groupId);

  final StoryFormatGroupId groupId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatGroupExtensionTarget && other.groupId == groupId;

  @override
  int get hashCode => Object.hash(StoryFormatGroupExtensionTarget, groupId);

  @override
  String toString() => 'StoryFormatGroupExtensionTarget($groupId)';
}

/// Extension attachment to one authoring-tag identity.
final class StoryFormatTagExtensionTarget extends StoryFormatExtensionTarget {
  const StoryFormatTagExtensionTarget(this.tagId);

  final StoryFormatTagId tagId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatTagExtensionTarget && other.tagId == tagId;

  @override
  int get hashCode => Object.hash(StoryFormatTagExtensionTarget, tagId);

  @override
  String toString() => 'StoryFormatTagExtensionTarget($tagId)';
}
