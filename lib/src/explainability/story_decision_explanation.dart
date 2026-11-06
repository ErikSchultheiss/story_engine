import '../identity/story_choice_id.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../orchestration/story_entry_point.dart';
import '../state/story_value.dart';
import 'story_condition_explanation.dart';

/// Structured explanation of whether one authored choice is available.
final class StoryChoiceExplanation {
  const StoryChoiceExplanation._({
    required this.eventId,
    required this.choiceId,
    required this.available,
    required this.condition,
  });

  factory StoryChoiceExplanation({
    required StoryEventId eventId,
    required StoryChoiceId choiceId,
    required bool available,
    StoryConditionExplanation? condition,
  }) {
    if (condition == null && !available) {
      throw ArgumentError.value(
        available,
        'available',
        'A choice without an availability condition is unconditional.',
      );
    }
    if (condition != null && condition.result != available) {
      throw ArgumentError.value(
        available,
        'available',
        'Choice availability must match its evaluated condition result.',
      );
    }
    return StoryChoiceExplanation._(
      eventId: eventId,
      choiceId: choiceId,
      available: available,
      condition: condition,
    );
  }

  final StoryEventId eventId;
  final StoryChoiceId choiceId;
  final bool available;

  /// Null when the choice is authored as unconditionally available.
  final StoryConditionExplanation? condition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryChoiceExplanation &&
          other.eventId == eventId &&
          other.choiceId == choiceId &&
          other.available == available &&
          other.condition == condition;

  @override
  int get hashCode => Object.hash(
    StoryChoiceExplanation,
    eventId,
    choiceId,
    available,
    condition,
  );

  @override
  String toString() =>
      'StoryChoiceExplanation($choiceId, available: $available)';
}

/// Outcome of comparing one explicit host fact with an entry-point requirement.
enum StoryHostConditionExplanationStatus { matched, mismatched, missing }

/// Structured result for one entry-point host-condition requirement.
final class StoryHostConditionExplanation {
  factory StoryHostConditionExplanation({
    required StoryHostConditionKey key,
    required String schemaNamespace,
    required String conditionId,
    Map<String, Object> arguments = const {},
    required bool expected,
    required bool? actual,
  }) {
    final requirement = StoryHostConditionRequirement(
      key: key,
      schemaNamespace: schemaNamespace,
      conditionId: conditionId,
      arguments: arguments,
      expected: expected,
    );
    return StoryHostConditionExplanation._(
      key: requirement.key,
      schemaNamespace: requirement.schemaNamespace,
      conditionId: requirement.conditionId,
      arguments: requirement.arguments,
      expected: requirement.expected,
      actual: actual,
    );
  }

  const StoryHostConditionExplanation._({
    required this.key,
    required this.schemaNamespace,
    required this.conditionId,
    required this.arguments,
    required this.expected,
    required this.actual,
  });

  final StoryHostConditionKey key;
  final String schemaNamespace;
  final String conditionId;
  final Map<String, Object> arguments;
  final bool expected;

  /// Explicit host result, or null when the required fact was not supplied.
  final bool? actual;

  StoryHostConditionExplanationStatus get status {
    final value = actual;
    if (value == null) {
      return StoryHostConditionExplanationStatus.missing;
    }
    return value == expected
        ? StoryHostConditionExplanationStatus.matched
        : StoryHostConditionExplanationStatus.mismatched;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHostConditionExplanation &&
          other.key == key &&
          other.schemaNamespace == schemaNamespace &&
          other.conditionId == conditionId &&
          _mapsEqual(other.arguments, arguments) &&
          other.expected == expected &&
          other.actual == actual;

  @override
  int get hashCode => Object.hash(
    StoryHostConditionExplanation,
    key,
    schemaNamespace,
    conditionId,
    Object.hashAllUnordered(
      arguments.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    expected,
    actual,
  );

  @override
  String toString() =>
      'StoryHostConditionExplanation($key, status: ${status.name})';
}

/// Why one entry-point candidate did or did not reach priority selection.
enum StoryEntryPointCandidateStatus {
  eligible,
  stateConditionRejected,
  hostConditionRejected,
  hostConditionMissing,
  notEvaluated,
}

/// Explanation of one authored entry point during one resolution operation.
final class StoryEntryPointExplanation {
  factory StoryEntryPointExplanation({
    required StoryEntryPointId entryPointId,
    required StoryEventId eventId,
    required bool isFallback,
    required int priority,
    required int weight,
    required StoryEntryPointCandidateStatus status,
    StoryConditionExplanation? eligibilityCondition,
    required int authoredHostConditionCount,
    Iterable<StoryHostConditionExplanation> evaluatedHostConditions = const [],
  }) {
    if (priority < StoryIntegerValue.minPortableValue ||
        priority > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        priority,
        'priority',
        'Entry-point explanation priority must be a portable Story Integer.',
      );
    }
    if (weight <= 0 || weight > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Entry-point explanation weight must be a positive portable Integer.',
      );
    }
    if (authoredHostConditionCount < 0) {
      throw ArgumentError.value(
        authoredHostConditionCount,
        'authoredHostConditionCount',
        'Host-condition count cannot be negative.',
      );
    }
    final hostConditions = List<StoryHostConditionExplanation>.unmodifiable(
      evaluatedHostConditions,
    );
    if (hostConditions.length > authoredHostConditionCount) {
      throw ArgumentError.value(
        evaluatedHostConditions,
        'evaluatedHostConditions',
        'Cannot explain more host conditions than were authored.',
      );
    }
    _validateEntryPointStatus(
      status: status,
      eligibilityCondition: eligibilityCondition,
      authoredHostConditionCount: authoredHostConditionCount,
      evaluatedHostConditions: hostConditions,
    );
    return StoryEntryPointExplanation._(
      entryPointId: entryPointId,
      eventId: eventId,
      isFallback: isFallback,
      priority: priority,
      weight: weight,
      status: status,
      eligibilityCondition: eligibilityCondition,
      authoredHostConditionCount: authoredHostConditionCount,
      evaluatedHostConditions: hostConditions,
    );
  }

  const StoryEntryPointExplanation._({
    required this.entryPointId,
    required this.eventId,
    required this.isFallback,
    required this.priority,
    required this.weight,
    required this.status,
    required this.eligibilityCondition,
    required this.authoredHostConditionCount,
    required this.evaluatedHostConditions,
  });

  final StoryEntryPointId entryPointId;
  final StoryEventId eventId;
  final bool isFallback;
  final int priority;
  final int weight;
  final StoryEntryPointCandidateStatus status;

  /// Null when there is no authored eligibility condition or this fallback
  /// candidate was not evaluated because the regular tier already succeeded.
  final StoryConditionExplanation? eligibilityCondition;

  final int authoredHostConditionCount;

  /// Host requirements actually inspected, in authored order.
  final List<StoryHostConditionExplanation> evaluatedHostConditions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEntryPointExplanation &&
          other.entryPointId == entryPointId &&
          other.eventId == eventId &&
          other.isFallback == isFallback &&
          other.priority == priority &&
          other.weight == weight &&
          other.status == status &&
          other.eligibilityCondition == eligibilityCondition &&
          other.authoredHostConditionCount == authoredHostConditionCount &&
          _orderedHostConditionsEqual(
            other.evaluatedHostConditions,
            evaluatedHostConditions,
          );

  @override
  int get hashCode => Object.hash(
    StoryEntryPointExplanation,
    entryPointId,
    eventId,
    isFallback,
    priority,
    weight,
    status,
    eligibilityCondition,
    authoredHostConditionCount,
    Object.hashAll(evaluatedHostConditions),
  );

  @override
  String toString() =>
      'StoryEntryPointExplanation($entryPointId, status: ${status.name})';
}

/// How the final entry point was selected after eligibility and priority.
enum StoryEntryPointSelectionMethod {
  /// No candidate survived eligibility/fallback filtering.
  none,

  /// Exactly one candidate remained at the winning priority; no RNG was used.
  soleFinalist,

  /// Multiple finalists remained and exactly one weighted RNG draw was used.
  weightedDraw,
}

/// One finalist participating in final entry-point selection.
final class StoryEntryPointFinalistExplanation {
  StoryEntryPointFinalistExplanation({
    required this.entryPointId,
    required this.weight,
  }) {
    if (weight <= 0 || weight > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Finalist weight must be a positive portable Story Integer.',
      );
    }
  }

  final StoryEntryPointId entryPointId;
  final int weight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEntryPointFinalistExplanation &&
          other.entryPointId == entryPointId &&
          other.weight == weight;

  @override
  int get hashCode =>
      Object.hash(StoryEntryPointFinalistExplanation, entryPointId, weight);
}

/// Explanation of one complete entry-point resolution pass.
final class StoryEntryPointResolutionExplanation {
  factory StoryEntryPointResolutionExplanation({
    required Iterable<StoryEntryPointExplanation> candidates,
    required StoryEntryPointSelectionMethod selectionMethod,
    StoryEntryPointId? selectedEntryPointId,
    bool? winningFallbackTier,
    int? winningPriority,
    Iterable<StoryEntryPointFinalistExplanation> finalists = const [],
    int? totalWeight,
    int? sampledWeightOffset,
  }) {
    final candidateList = List<StoryEntryPointExplanation>.unmodifiable(
      candidates,
    );
    final finalistList = List<StoryEntryPointFinalistExplanation>.unmodifiable(
      finalists,
    );
    _validateResolutionShape(
      candidates: candidateList,
      selectionMethod: selectionMethod,
      selectedEntryPointId: selectedEntryPointId,
      winningFallbackTier: winningFallbackTier,
      winningPriority: winningPriority,
      finalists: finalistList,
      totalWeight: totalWeight,
      sampledWeightOffset: sampledWeightOffset,
    );
    return StoryEntryPointResolutionExplanation._(
      candidates: candidateList,
      selectionMethod: selectionMethod,
      selectedEntryPointId: selectedEntryPointId,
      winningFallbackTier: winningFallbackTier,
      winningPriority: winningPriority,
      finalists: finalistList,
      totalWeight: totalWeight,
      sampledWeightOffset: sampledWeightOffset,
    );
  }

  const StoryEntryPointResolutionExplanation._({
    required this.candidates,
    required this.selectionMethod,
    required this.selectedEntryPointId,
    required this.winningFallbackTier,
    required this.winningPriority,
    required this.finalists,
    required this.totalWeight,
    required this.sampledWeightOffset,
  });

  /// Every authored candidate in declaration order. Fallback candidates that
  /// were not reached are represented with `notEvaluated` status.
  final List<StoryEntryPointExplanation> candidates;

  final StoryEntryPointSelectionMethod selectionMethod;
  final StoryEntryPointId? selectedEntryPointId;
  final bool? winningFallbackTier;
  final int? winningPriority;

  /// Candidates at the winning priority in authored order.
  final List<StoryEntryPointFinalistExplanation> finalists;

  /// Sum of finalist weights when [selectionMethod] is `weightedDraw`.
  final int? totalWeight;

  /// Actual zero-based sample from the orchestration RNG when a draw occurred.
  final int? sampledWeightOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEntryPointResolutionExplanation &&
          _orderedEntryPointsEqual(other.candidates, candidates) &&
          other.selectionMethod == selectionMethod &&
          other.selectedEntryPointId == selectedEntryPointId &&
          other.winningFallbackTier == winningFallbackTier &&
          other.winningPriority == winningPriority &&
          _orderedFinalistsEqual(other.finalists, finalists) &&
          other.totalWeight == totalWeight &&
          other.sampledWeightOffset == sampledWeightOffset;

  @override
  int get hashCode => Object.hash(
    StoryEntryPointResolutionExplanation,
    Object.hashAll(candidates),
    selectionMethod,
    selectedEntryPointId,
    winningFallbackTier,
    winningPriority,
    Object.hashAll(finalists),
    totalWeight,
    sampledWeightOffset,
  );

  @override
  String toString() =>
      'StoryEntryPointResolutionExplanation(method: ${selectionMethod.name}, '
      'selected: $selectedEntryPointId)';
}

void _validateEntryPointStatus({
  required StoryEntryPointCandidateStatus status,
  required StoryConditionExplanation? eligibilityCondition,
  required int authoredHostConditionCount,
  required List<StoryHostConditionExplanation> evaluatedHostConditions,
}) {
  switch (status) {
    case StoryEntryPointCandidateStatus.notEvaluated:
      if (eligibilityCondition != null || evaluatedHostConditions.isNotEmpty) {
        throw ArgumentError(
          'A not-evaluated entry point cannot contain evaluated condition data.',
        );
      }
      return;
    case StoryEntryPointCandidateStatus.stateConditionRejected:
      if (eligibilityCondition == null || eligibilityCondition.result) {
        throw ArgumentError(
          'stateConditionRejected requires a false eligibility explanation.',
        );
      }
      if (evaluatedHostConditions.isNotEmpty) {
        throw ArgumentError(
          'Host requirements are not evaluated after state rejection.',
        );
      }
      return;
    case StoryEntryPointCandidateStatus.hostConditionRejected:
      _validateHostFailurePrefix(
        eligibilityCondition: eligibilityCondition,
        evaluatedHostConditions: evaluatedHostConditions,
        expectedFinalStatus: StoryHostConditionExplanationStatus.mismatched,
        statusName: 'hostConditionRejected',
      );
      return;
    case StoryEntryPointCandidateStatus.hostConditionMissing:
      _validateHostFailurePrefix(
        eligibilityCondition: eligibilityCondition,
        evaluatedHostConditions: evaluatedHostConditions,
        expectedFinalStatus: StoryHostConditionExplanationStatus.missing,
        statusName: 'hostConditionMissing',
      );
      return;
    case StoryEntryPointCandidateStatus.eligible:
      if (eligibilityCondition != null && !eligibilityCondition.result) {
        throw ArgumentError(
          'An eligible entry point cannot have a false state condition.',
        );
      }
      if (evaluatedHostConditions.length != authoredHostConditionCount ||
          evaluatedHostConditions.any(
            (condition) =>
                condition.status != StoryHostConditionExplanationStatus.matched,
          )) {
        throw ArgumentError(
          'An eligible entry point requires every authored host condition to '
          'have been evaluated and matched.',
        );
      }
      return;
  }
}

void _validateHostFailurePrefix({
  required StoryConditionExplanation? eligibilityCondition,
  required List<StoryHostConditionExplanation> evaluatedHostConditions,
  required StoryHostConditionExplanationStatus expectedFinalStatus,
  required String statusName,
}) {
  if (eligibilityCondition != null && !eligibilityCondition.result) {
    throw ArgumentError(
      '$statusName cannot follow a false state eligibility result.',
    );
  }
  if (evaluatedHostConditions.isEmpty ||
      evaluatedHostConditions.last.status != expectedFinalStatus) {
    throw ArgumentError(
      '$statusName requires a final ${expectedFinalStatus.name} host result.',
    );
  }
  if (evaluatedHostConditions
      .take(evaluatedHostConditions.length - 1)
      .any(
        (condition) =>
            condition.status != StoryHostConditionExplanationStatus.matched,
      )) {
    throw ArgumentError(
      'Host evaluation cannot continue after a mismatch or missing fact.',
    );
  }
}

void _validateResolutionShape({
  required List<StoryEntryPointExplanation> candidates,
  required StoryEntryPointSelectionMethod selectionMethod,
  required StoryEntryPointId? selectedEntryPointId,
  required bool? winningFallbackTier,
  required int? winningPriority,
  required List<StoryEntryPointFinalistExplanation> finalists,
  required int? totalWeight,
  required int? sampledWeightOffset,
}) {
  _validateResolutionIdentities(candidates, finalists);

  switch (selectionMethod) {
    case StoryEntryPointSelectionMethod.none:
      _validateNoSelection(
        candidates: candidates,
        selectedEntryPointId: selectedEntryPointId,
        winningFallbackTier: winningFallbackTier,
        winningPriority: winningPriority,
        finalists: finalists,
        totalWeight: totalWeight,
        sampledWeightOffset: sampledWeightOffset,
      );
      return;
    case StoryEntryPointSelectionMethod.soleFinalist:
      if (selectedEntryPointId == null ||
          winningFallbackTier == null ||
          winningPriority == null ||
          finalists.length != 1 ||
          finalists.single.entryPointId != selectedEntryPointId ||
          totalWeight != null ||
          sampledWeightOffset != null) {
        throw ArgumentError(
          'soleFinalist requires exactly one selected finalist and no RNG draw.',
        );
      }
      _validateFinalistsAgainstCandidates(
        candidates: candidates,
        finalists: finalists,
        winningFallbackTier: winningFallbackTier,
        winningPriority: winningPriority,
      );
      return;
    case StoryEntryPointSelectionMethod.weightedDraw:
      if (selectedEntryPointId == null ||
          winningFallbackTier == null ||
          winningPriority == null ||
          finalists.length < 2 ||
          totalWeight == null ||
          sampledWeightOffset == null) {
        throw ArgumentError(
          'weightedDraw requires winner, tier, priority, multiple finalists, '
          'totalWeight, and sampledWeightOffset.',
        );
      }
      _validateFinalistsAgainstCandidates(
        candidates: candidates,
        finalists: finalists,
        winningFallbackTier: winningFallbackTier,
        winningPriority: winningPriority,
      );
      _validateWeightedDraw(
        finalists: finalists,
        totalWeight: totalWeight,
        sampledWeightOffset: sampledWeightOffset,
        selectedEntryPointId: selectedEntryPointId,
      );
      return;
  }
}

void _validateResolutionIdentities(
  List<StoryEntryPointExplanation> candidates,
  List<StoryEntryPointFinalistExplanation> finalists,
) {
  final candidateIds = <StoryEntryPointId>{};
  for (final candidate in candidates) {
    if (!candidateIds.add(candidate.entryPointId)) {
      throw ArgumentError.value(
        candidates,
        'candidates',
        'Entry-point resolution candidates must have unique identities.',
      );
    }
  }

  if (candidates.any(
    (candidate) =>
        candidate.status == StoryEntryPointCandidateStatus.hostConditionMissing,
  )) {
    throw ArgumentError(
      'A complete entry-point resolution cannot contain a missing required '
      'host fact because authoritative resolution throws instead.',
    );
  }

  final finalistIds = <StoryEntryPointId>{};
  for (final finalist in finalists) {
    if (!finalistIds.add(finalist.entryPointId)) {
      throw ArgumentError.value(
        finalists,
        'finalists',
        'Entry-point resolution finalists must have unique identities.',
      );
    }
    if (!candidateIds.contains(finalist.entryPointId)) {
      throw ArgumentError.value(
        finalists,
        'finalists',
        'Every finalist must refer to a recorded candidate.',
      );
    }
  }
}

void _validateNoSelection({
  required List<StoryEntryPointExplanation> candidates,
  required StoryEntryPointId? selectedEntryPointId,
  required bool? winningFallbackTier,
  required int? winningPriority,
  required List<StoryEntryPointFinalistExplanation> finalists,
  required int? totalWeight,
  required int? sampledWeightOffset,
}) {
  if (selectedEntryPointId != null ||
      winningFallbackTier != null ||
      winningPriority != null ||
      finalists.isNotEmpty ||
      totalWeight != null ||
      sampledWeightOffset != null) {
    throw ArgumentError(
      'A resolution with no selection cannot contain winner/draw data.',
    );
  }
  if (candidates.any(
    (candidate) => candidate.status == StoryEntryPointCandidateStatus.eligible,
  )) {
    throw ArgumentError(
      'A no-selection resolution cannot contain an eligible candidate.',
    );
  }
  if (candidates.any(
    (candidate) =>
        candidate.status == StoryEntryPointCandidateStatus.notEvaluated,
  )) {
    throw ArgumentError(
      'When no regular entry is eligible the fallback tier is evaluated; '
      'a complete no-selection resolution cannot contain notEvaluated '
      'candidates.',
    );
  }
}

void _validateWeightedDraw({
  required List<StoryEntryPointFinalistExplanation> finalists,
  required int totalWeight,
  required int sampledWeightOffset,
  required StoryEntryPointId selectedEntryPointId,
}) {
  var expectedTotal = 0;
  for (final finalist in finalists) {
    if (expectedTotal > StoryIntegerValue.maxPortableValue - finalist.weight) {
      throw ArgumentError(
        'Weighted finalist total exceeds the portable integer range.',
      );
    }
    expectedTotal += finalist.weight;
  }
  if (totalWeight != expectedTotal ||
      sampledWeightOffset < 0 ||
      sampledWeightOffset >= totalWeight) {
    throw ArgumentError(
      'Weighted draw total/sample does not match the finalist weights.',
    );
  }
  var upperExclusive = 0;
  StoryEntryPointId? sampledWinner;
  for (final finalist in finalists) {
    upperExclusive += finalist.weight;
    if (sampledWeightOffset < upperExclusive) {
      sampledWinner = finalist.entryPointId;
      break;
    }
  }
  if (sampledWinner != selectedEntryPointId) {
    throw ArgumentError(
      'Weighted draw sample does not map to selectedEntryPointId.',
    );
  }
}

void _validateFinalistsAgainstCandidates({
  required List<StoryEntryPointExplanation> candidates,
  required List<StoryEntryPointFinalistExplanation> finalists,
  required bool winningFallbackTier,
  required int winningPriority,
}) {
  if (winningFallbackTier) {
    if (candidates.any(
      (candidate) =>
          !candidate.isFallback &&
          candidate.status == StoryEntryPointCandidateStatus.eligible,
    )) {
      throw ArgumentError(
        'Fallback selection is impossible while a regular candidate is '
        'eligible.',
      );
    }
    if (candidates.any(
      (candidate) =>
          candidate.status == StoryEntryPointCandidateStatus.notEvaluated,
    )) {
      throw ArgumentError(
        'Fallback selection requires both regular and fallback tiers to have '
        'been evaluated.',
      );
    }
  } else {
    for (final candidate in candidates) {
      if (candidate.isFallback) {
        if (candidate.status != StoryEntryPointCandidateStatus.notEvaluated) {
          throw ArgumentError(
            'Fallback candidates must remain notEvaluated when a regular '
            'candidate wins.',
          );
        }
      } else if (candidate.status ==
          StoryEntryPointCandidateStatus.notEvaluated) {
        throw ArgumentError(
          'Every regular candidate is evaluated during entry resolution.',
        );
      }
    }
  }

  final eligibleInTier = <StoryEntryPointExplanation>[
    for (final candidate in candidates)
      if (candidate.isFallback == winningFallbackTier &&
          candidate.status == StoryEntryPointCandidateStatus.eligible)
        candidate,
  ];
  if (eligibleInTier.isEmpty) {
    throw ArgumentError('Winning entry-point tier has no eligible candidate.');
  }

  var actualWinningPriority = eligibleInTier.first.priority;
  for (final candidate in eligibleInTier.skip(1)) {
    if (candidate.priority > actualWinningPriority) {
      actualWinningPriority = candidate.priority;
    }
  }
  if (winningPriority != actualWinningPriority) {
    throw ArgumentError(
      'winningPriority must equal the highest priority in the winning tier.',
    );
  }

  final expectedFinalists = <StoryEntryPointExplanation>[
    for (final candidate in eligibleInTier)
      if (candidate.priority == winningPriority) candidate,
  ];
  if (finalists.length != expectedFinalists.length) {
    throw ArgumentError(
      'Finalists must contain every eligible candidate at winningPriority.',
    );
  }
  for (var index = 0; index < finalists.length; index++) {
    final finalist = finalists[index];
    final candidate = expectedFinalists[index];
    if (finalist.entryPointId != candidate.entryPointId ||
        finalist.weight != candidate.weight) {
      throw ArgumentError(
        'Finalists must match winning candidates in authored order.',
      );
    }
  }
}

bool _mapsEqual(Map<String, Object> left, Map<String, Object> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _orderedHostConditionsEqual(
  List<StoryHostConditionExplanation> left,
  List<StoryHostConditionExplanation> right,
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

bool _orderedEntryPointsEqual(
  List<StoryEntryPointExplanation> left,
  List<StoryEntryPointExplanation> right,
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

bool _orderedFinalistsEqual(
  List<StoryEntryPointFinalistExplanation> left,
  List<StoryEntryPointFinalistExplanation> right,
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
