import '../identity/story_alias.dart';
import '../identity/story_variable_id.dart';
import 'story_variable_definition.dart';

/// Immutable authored declaration of the scalar state variables in a project.
///
/// Variable machine IDs and aliases must each be unique within this variable
/// namespace. Other authored entity namespaces may reuse the same alias token.
final class StoryStateSchema {
  factory StoryStateSchema({
    required Iterable<StoryVariableDefinition> variables,
  }) {
    final definitions = List<StoryVariableDefinition>.unmodifiable(variables);
    final byId = <StoryVariableId, StoryVariableDefinition>{};
    final byAlias = <StoryAlias, StoryVariableDefinition>{};

    for (final definition in definitions) {
      if (byId.containsKey(definition.id)) {
        throw ArgumentError.value(
          definition.id,
          'variables',
          'Duplicate story variable ID.',
        );
      }
      byId[definition.id] = definition;

      final alias = definition.alias;
      if (alias != null) {
        if (byAlias.containsKey(alias)) {
          throw ArgumentError.value(
            alias,
            'variables',
            'Duplicate story variable alias within the variable namespace.',
          );
        }
        byAlias[alias] = definition;
      }
    }

    return StoryStateSchema._(
      definitions,
      Map<StoryVariableId, StoryVariableDefinition>.unmodifiable(byId),
      Map<StoryAlias, StoryVariableDefinition>.unmodifiable(byAlias),
    );
  }

  StoryStateSchema._(this.variables, this._byId, this._byAlias);

  /// Creates an empty schema for projects without scalar variables.
  factory StoryStateSchema.empty() => StoryStateSchema(variables: const []);

  /// Variable definitions in deterministic authored order.
  final List<StoryVariableDefinition> variables;

  final Map<StoryVariableId, StoryVariableDefinition> _byId;
  final Map<StoryAlias, StoryVariableDefinition> _byAlias;

  /// Returns the definition for [id], or `null` if the ID is undeclared.
  StoryVariableDefinition? definitionFor(StoryVariableId id) => _byId[id];

  /// Returns the definition carrying [alias], or `null` if none exists.
  StoryVariableDefinition? definitionForAlias(StoryAlias alias) =>
      _byAlias[alias];

  /// Whether [id] is declared by this schema.
  bool contains(StoryVariableId id) => _byId.containsKey(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryStateSchema &&
          _orderedDefinitionsEqual(variables, other.variables);

  @override
  int get hashCode => Object.hashAll(variables);

  @override
  String toString() => 'StoryStateSchema(${variables.length} variables)';
}

bool _orderedDefinitionsEqual(
  List<StoryVariableDefinition> left,
  List<StoryVariableDefinition> right,
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
