import 'story_runtime_bundle_layout.dart';
import 'story_runtime_bundle_manifest.dart';

/// Immutable byte-oriented runtime bundle produced by a deterministic build.
///
/// Runtime bundle bytes are shipping artifacts, not authored source and never
/// replace the canonical Story Format project.
final class StoryRuntimeBundle {
  factory StoryRuntimeBundle({
    required StoryRuntimeBundleManifest manifest,
    required Map<String, List<int>> files,
  }) {
    final copied = <String, List<int>>{};
    for (final entry in files.entries) {
      if (!StoryRuntimeBundleLayout.isPortablePath(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'files',
          'Runtime bundle paths must be portable relative paths.',
        );
      }
      copied[entry.key] = List<int>.unmodifiable(entry.value);
    }
    return StoryRuntimeBundle._(
      manifest: manifest,
      files: Map<String, List<int>>.unmodifiable(copied),
    );
  }

  StoryRuntimeBundle._({required this.manifest, required this.files});

  /// Parsed canonical runtime-bundle manifest.
  final StoryRuntimeBundleManifest manifest;

  /// Portable path to exact artifact bytes.
  final Map<String, List<int>> files;

  /// Returns artifact bytes at [path], or null when absent.
  List<int>? file(String path) => files[path];
}
