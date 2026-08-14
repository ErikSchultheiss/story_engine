import '../model/story_project.dart';
import 'story_format_extension_attachment.dart';
import 'story_format_metadata.dart';
import 'story_format_organization.dart';

/// Lossless in-memory authored Story Format v1 document.
///
/// [project] is the executable/validation semantic projection. Organization
/// and opaque extensions are format-level authored data deliberately kept out
/// of `StoryProject` so authoring metadata cannot acquire runtime semantics.
///
/// The Stage 5C bundle layout and Stage 5D codec adapt this value without
/// making physical storage or JSON concerns part of the semantic document
/// contract itself.
final class StoryFormatDocument {
  factory StoryFormatDocument({
    required StoryProject project,
    StoryFormatOrganization? organization,
    Iterable<StoryFormatExtensionAttachment> extensions = const [],
  }) {
    final copiedExtensions = List<StoryFormatExtensionAttachment>.unmodifiable(
      extensions,
    );
    _validateUniqueExtensionAttachments(copiedExtensions);

    return StoryFormatDocument._(
      metadata: const StoryFormatMetadata.current(),
      project: project,
      organization: organization ?? StoryFormatOrganization.empty(),
      extensions: copiedExtensions,
    );
  }

  StoryFormatDocument._({
    required this.metadata,
    required this.project,
    required this.organization,
    required this.extensions,
  });

  /// Story Format identity/version for this public v1 document model.
  final StoryFormatMetadata metadata;

  /// Current executable/validation authored semantic projection.
  final StoryProject project;

  /// Runtime-neutral groups/tags retained losslessly by the format layer.
  final StoryFormatOrganization organization;

  /// Opaque namespaced extension data in caller-authored declaration order.
  ///
  /// Attachments are semantically set-like by `(target, namespace)`: duplicate
  /// pairs are rejected. Stage 5D encodes this set-like collection in
  /// canonical target/namespace order.
  final List<StoryFormatExtensionAttachment> extensions;

  /// Returns the runtime/validation authored projection without organization or
  /// opaque extension metadata.
  StoryProject toStoryProject() => project;

  @override
  String toString() =>
      'StoryFormatDocument(project: ${project.id}, groups: '
      '${organization.groups.length}, tags: ${organization.tags.length}, '
      'extensions: ${extensions.length})';
}

void _validateUniqueExtensionAttachments(
  List<StoryFormatExtensionAttachment> extensions,
) {
  final seen = <_ExtensionAttachmentKey>{};
  for (final extension in extensions) {
    final key = _ExtensionAttachmentKey(
      target: extension.target,
      namespace: extension.namespace.value,
    );
    if (!seen.add(key)) {
      throw ArgumentError.value(
        extension,
        'extensions',
        'Only one extension payload may exist for a given target and '
            'namespace.',
      );
    }
  }
}

final class _ExtensionAttachmentKey {
  const _ExtensionAttachmentKey({
    required this.target,
    required this.namespace,
  });

  final Object target;
  final String namespace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ExtensionAttachmentKey &&
          other.target == target &&
          other.namespace == namespace;

  @override
  int get hashCode => Object.hash(target, namespace);
}
