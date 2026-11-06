import '../identity/story_module_id.dart';
import 'story_narrative_module.dart';

/// Host-provided abstraction that obtains one narrative module by stable ID.
///
/// The interface deliberately says nothing about files, databases, asset
/// bundles, HTTP, addressables, pak files, or another storage technology.
/// Implementations may complete asynchronously; completion timing is not part
/// of narrative semantics.
///
/// A cache may register a same-module single-flight placeholder before invoking
/// loader code. Synchronous, non-awaited reentrant requests for that same module
/// can therefore join the pending load. Loader implementations MUST NOT await a
/// cache request whose completion depends on the very loader invocation making
/// that request, directly or through a circular chain; such host-side circular
/// waiting cannot be resolved by module single-flight. This is separate from
/// ordinary cyclic authored module dependencies, which dependency-closure
/// traversal supports.
abstract interface class StoryModuleLoader {
  /// Loads the requested module or throws when it cannot be supplied.
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId);
}

/// Reports failure to load or verify modular narrative content.
final class StoryModuleLoadException implements Exception {
  const StoryModuleLoadException({required this.message, this.cause});

  /// Human-readable failure summary.
  final String message;

  /// Optional underlying implementation failure.
  final Object? cause;

  @override
  String toString() => 'StoryModuleLoadException: $message';
}
