/// Externally visible lifecycle state of a `StoryEngine`.
///
/// The type lives separately from the engine implementation so runtime
/// snapshots and the engine can share one lifecycle vocabulary without
/// introducing circular imports.
enum StoryEngineStatus {
  /// The engine has been constructed but `StoryEngine.start()` has not
  /// successfully committed.
  notStarted,

  /// The current event is interactive and waiting for a choice selection.
  awaitingChoice,

  /// The current event is presented and waiting for an explicit continue.
  awaitingContinue,

  /// Runtime traversal reached an explicit terminal transition.
  terminated,
}
