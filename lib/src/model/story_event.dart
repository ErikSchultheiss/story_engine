import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_alias.dart';
import '../identity/story_event_id.dart';
import '../presentation/story_event_presentation.dart';
import '../transition/story_transition.dart';
import 'story_choice.dart';

/// The fundamental executable authored unit in a story project.
///
/// The term "event" is intentionally broader than "scene" and less tied to
/// graph implementation language than "node". A prose scene, dialogue beat,
/// quest event, tutorial step, or management-game event can all be represented
/// by this concept.
///
/// Stage 2G supports three explicit runtime flow modes while still allowing
/// incomplete editor data. A runnable event is exactly one of:
/// interactive (one or more choices), continuation (a host-visible pause with
/// no decision), or automatic (synchronous non-pausing flow). The runtime
/// enforces that invariant when the event is entered.
final class StoryEvent {
  /// Creates an authored event definition.
  factory StoryEvent({
    required StoryEventId id,
    StoryAlias? alias,
    StoryEventPresentation? presentation,
    StoryCondition? availabilityCondition,
    Iterable<StoryEffect> entryEffects = const [],
    Iterable<StoryChoice> choices = const [],
    StoryTransition? continuationTransition,
    StoryTransition? automaticTransition,
  }) => StoryEvent._(
    id: id,
    alias: alias,
    presentation: presentation,
    availabilityCondition: availabilityCondition,
    entryEffects: List<StoryEffect>.unmodifiable(entryEffects),
    choices: List<StoryChoice>.unmodifiable(choices),
    continuationTransition: continuationTransition,
    automaticTransition: automaticTransition,
  );

  StoryEvent._({
    required this.id,
    required this.alias,
    required this.presentation,
    required this.availabilityCondition,
    required this.entryEffects,
    required this.choices,
    required this.continuationTransition,
    required this.automaticTransition,
  });

  /// Stable machine identity for this event.
  final StoryEventId id;

  /// Optional developer-friendly name that is not used as machine identity.
  final StoryAlias? alias;

  /// Optional human-facing/source-language presentation data.
  ///
  /// Presentation is deliberately independent from runtime identity and flow.
  /// Continuation events provide the host-visible no-choice pause. Automatic
  /// events remain synchronous; presentation on them does not create a pause.
  final StoryEventPresentation? presentation;

  /// Optional side-effect-free predicate that must be true before this event
  /// may be entered.
  ///
  /// The predicate is evaluated against the incoming state before
  /// [entryEffects] are applied. A null value means the event is always
  /// available.
  final StoryCondition? availabilityCondition;

  /// Declarative state changes applied every time this event is entered.
  final List<StoryEffect> entryEffects;

  /// Authored choices displayed by an interactive event.
  final List<StoryChoice> choices;

  /// Navigation performed only after the host explicitly continues this event.
  ///
  /// A continuation event has this value and no [choices] or
  /// [automaticTransition]. After event availability and [entryEffects] are
  /// processed, the runtime pauses with the event current until
  /// `StoryEngine.continueStory()` is called.
  final StoryTransition? continuationTransition;

  /// Navigation performed automatically after [entryEffects].
  ///
  /// A runnable automatic event has this value and no [choices] or
  /// [continuationTransition]. Automatic events never create a host-visible
  /// pause. Incomplete or temporarily ambiguous definitions are allowed in
  /// authored data so the Studio can edit them, but the runtime rejects them
  /// when entered.
  final StoryTransition? automaticTransition;
}
