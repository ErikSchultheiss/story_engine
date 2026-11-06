import 'dart:convert';
import 'dart:io';

import 'support/conformance_runner.dart';

/// Run the data-only corpus without the test framework or private runtime APIs.
void main(List<String> arguments) {
  exitCode = runConformanceCli(arguments, output: stdout, errors: stderr);
}

/// Execute the command using the supplied output/error sinks and return its
/// process exit status. File output still uses the real filesystem.
///
/// Kept in tooling so tests can cover the executable's argument, report and
/// failure paths without starting a fresh Dart VM for each assertion.
int runConformanceCli(
  List<String> arguments, {
  required StringSink output,
  required StringSink errors,
}) {
  var fixture = 'conformance/fixtures/runtime-core-v1/fixture-set.json';
  String? outputPath;
  try {
    for (final argument in arguments) {
      if (argument == '--help') {
        output.writeln(
          'dart run tool/conformance/run_conformance.dart [--fixture-set=PATH] [--output=PATH]',
        );
        return 0;
      } else if (argument.startsWith('--fixture-set=')) {
        fixture = argument.substring(14);
      } else if (argument.startsWith('--output=')) {
        outputPath = argument.substring(9);
      } else {
        throw ArgumentError('Unknown option: $argument');
      }
    }
    final report = runFixtureSet(fixture);
    final text = '${const JsonEncoder.withIndent('  ').convert(report)}\n';
    if (outputPath == null) {
      output.write(text);
    } else {
      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
      output.writeln('Conformance report: ${file.path}');
    }
    final summary = report['summary']! as Map<String, Object?>;
    return summary['failed'] != 0 || summary['skipped'] != 0 ? 1 : 0;
  } catch (error) {
    errors.writeln('Conformance runner failed: $error');
    return 2;
  }
}
