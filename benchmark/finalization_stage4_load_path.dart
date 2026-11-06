import 'dart:convert';
import 'dart:io';

import 'support/finalization_stage4_load_path.dart';

/// End-to-end aggregate loading measurements; no machine-specific timing gate.
void main(List<String> arguments) {
  var samples = 5;
  var warmups = 2;
  String? selected;
  String? output;
  for (final arg in arguments) {
    if (arg.startsWith('--samples=')) {
      samples = int.parse(arg.substring(10));
    } else if (arg.startsWith('--warmups=')) {
      warmups = int.parse(arg.substring(10));
    } else if (arg.startsWith('--scenario=')) {
      selected = arg.substring(11);
    } else if (arg.startsWith('--output=')) {
      output = arg.substring(9);
    } else {
      throw ArgumentError('Unknown option: $arg');
    }
  }
  if (samples < 1 || warmups < 0) {
    throw ArgumentError('Samples must be positive and warmups nonnegative.');
  }
  final scenarios = aggregateLoadScenarios
      .where((s) => selected == null || s.id == selected)
      .toList();
  if (scenarios.isEmpty) {
    throw ArgumentError('Unknown scenario: $selected');
  }
  final report = <String, Object?>{
    'schema': 'story_engine.aggregate_load_path.v1',
    'dartVersion': Platform.version,
    'platform': Platform.operatingSystem,
    'samples': samples,
    'warmups': warmups,
    'timingUnit': 'microseconds',
    'timingGate': false,
    'scope':
        'Already available immutable project/configuration; JSON parse, typed decode/validation and aggregate restore. Fixture creation, fingerprint checks, content preflight, storage I/O and observer dispatch excluded.',
    'results': [
      for (final scenario in scenarios)
        measureAggregateLoad(scenario, samples: samples, warmups: warmups),
    ],
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  if (output == null) {
    stdout.writeln(encoded);
  } else {
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$encoded\n');
    stdout.writeln('Aggregate load-path report: ${file.path}');
  }
}
