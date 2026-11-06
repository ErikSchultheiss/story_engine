import 'story_format_extension_namespace.dart';
import 'story_format_extension_payload.dart';
import 'story_format_extension_target.dart';

/// One opaque, namespaced extension payload attached to a stable authored
/// entity.
///
/// The core format preserves this value but does not execute or interpret its
/// payload as story semantics.
final class StoryFormatExtensionAttachment {
  const StoryFormatExtensionAttachment({
    required this.namespace,
    required this.target,
    required this.payload,
  });

  final StoryFormatExtensionNamespace namespace;
  final StoryFormatExtensionTarget target;
  final StoryFormatExtensionPayload payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatExtensionAttachment &&
          other.namespace == namespace &&
          other.target == target &&
          other.payload == payload;

  @override
  int get hashCode =>
      Object.hash(StoryFormatExtensionAttachment, namespace, target, payload);

  @override
  String toString() => 'StoryFormatExtensionAttachment($namespace @ $target)';
}
