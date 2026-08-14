import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_alias.dart';
import '../identity/story_choice_id.dart';
import '../presentation/story_choice_presentation.dart';
import '../transition/story_transition.dart';

/// An authored decision option offered by a story event.
///
/// Choices are event-owned authoring concepts rather than generic graph edges.
/// They retain independent stable machine identity so later refactors can move
/// or rewrite a choice without deriving identity from its parent event or
/// visible text.
///
/// [transition] may be null so authoring tools can represent an in-progress or
/// invalid choice while it is being edited. The runtime rejects selection of a
/// choice that has no transition.
final class StoryChoice {
  /// Creates an authored choice definition.
  factory StoryChoice({
    required StoryChoiceId id,
    StoryAlias? alias,
    StoryChoicePresentation? presentation,
    StoryCondition? availabilityCondition,
    Iterable<StoryEffect> effects = const [],
    StoryTransition? transition,
  }) => StoryChoice._(
    id: id,
    alias: alias,
    presentation: presentation,
    availabilityCondition: availabilityCondition,
    effects: List<StoryEffect>.unmodifiable(effects),
    transition: transition,
  );

  StoryChoice._({
    required this.id,
    required this.alias,
    required this.presentation,
    required this.availabilityCondition,
    required this.effects,
    required this.transition,
  });

  /// Stable machine identity for this choice.
  final StoryChoiceId id;

  /// Optional developer-friendly name that is not used as machine identity.
  final StoryAlias? alias;

  /// Optional human-facing/source-language choice presentation.
  ///
  /// A null value keeps incomplete editor data and non-textual host-specific
  /// integrations representable. Runtime availability/selection never depends
  /// on presentation text.
  final StoryChoicePresentation? presentation;

  /// Optional side-effect-free predicate controlling whether the choice is
  /// currently available.
  ///
  /// A null value means unconditional availability.
  final StoryCondition? availabilityCondition;

  /// Declarative state changes applied after this choice is selected and
  /// before its transition is resolved.
  final List<StoryEffect> effects;

  /// Navigation requested after [effects] have been applied.
  ///
  /// Null is allowed in authored/editor data so incomplete work can exist, but
  /// attempting to select such a choice is a runtime configuration error.
  final StoryTransition? transition;
}
