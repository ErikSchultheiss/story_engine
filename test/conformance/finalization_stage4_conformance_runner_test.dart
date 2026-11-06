import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/conformance/run_conformance.dart' as cli;
import '../../tool/conformance/support/conformance_runner.dart';

const _foundation = 'conformance/fixtures/runtime-core-v1/fixture-set.json';
const _hardening =
    'conformance/fixtures/runtime-finalization-v1/fixture-set.json';

void main() {
  for (final manifest in [_foundation, _hardening]) {
    final document = _read(manifest);
    for (final descriptor in document['cases'] as List<dynamic>) {
      final id = (descriptor as Map<String, dynamic>)['caseId'];
      test('portable corpus $id', () {
        final report = runFixtureSet(manifest);
        final result = (report['results']! as List).singleWhere(
          (r) => r['caseId'] == id,
        );
        expect(result, {
          'caseId': id,
          'status': 'pass',
          'failures': <Object?>[],
        });
        expect(report['summary'], {
          'total': (document['cases'] as List).length,
          'passed': (document['cases'] as List).length,
          'failed': 0,
          'skipped': 0,
        });
      });
    }
  }

  group('runner failure reporting', () {
    late Directory temporary;
    late String manifest;
    setUp(() {
      temporary = Directory.systemTemp.createTempSync('story_conformance_');
      _copy(Directory('conformance/fixtures/runtime-core-v1'), temporary);
      manifest = '${temporary.path}/fixture-set.json';
      final value = _read(manifest);
      value['cases'] = [(value['cases'] as List).first];
      _write(manifest, value);
    });
    tearDown(() => temporary.deleteSync(recursive: true));
    String caseFile(String name) =>
        '${temporary.path}/lantern-mystery/cases/canonical-good/$name';
    Map<String, dynamic> failure() {
      final report = runFixtureSet(manifest);
      expect(report['summary'], {
        'total': 1,
        'passed': 0,
        'failed': 1,
        'skipped': 0,
      });
      final result = (report['results']! as List).single;
      expect(result['status'], 'fail');
      return (result['failures'] as List).single as Map<String, dynamic>;
    }

    for (final entry in {
      'expected_trace.json': 'traceMismatch',
      'expected_final_state.json': 'finalStateMismatch',
      'expected_history.json': 'historyMismatch',
    }.entries) {
      test('reports ${entry.value} without changing the golden', () {
        final path = caseFile(entry.key);
        final value = _read(path);
        if (entry.key == 'expected_trace.json') {
          (value['observations'] as List).first['currentEventId'] =
              'deliberately_wrong';
        } else if (entry.key == 'expected_history.json') {
          (value['steps'] as List).first['eventId'] = 'deliberately_wrong';
        } else {
          (value['values'] as List).first['state'] = 'deliberately_wrong';
        }
        _write(path, value);
        final result = failure();
        expect(result['kind'], entry.value);
        expect(result['path'], startsWith(r'$.'));
        expect(result, containsPair('expected', 'deliberately_wrong'));
      });
    }
    test('unsupported profile is skipped and never passed', () {
      final value = _read(manifest)..['profile'] = 'unknown-profile';
      _write(manifest, value);
      final report = runFixtureSet(manifest);
      expect(report['summary'], {
        'total': 1,
        'passed': 0,
        'failed': 0,
        'skipped': 1,
      });
      expect(
        ((report['results']! as List).single['failures'] as List)
            .single['kind'],
        'unsupportedContract',
      );
    });
    test('future declared runtime contract is skipped', () {
      final value = _read(manifest);
      value['contracts']['runtimeSemantics']['coreRevision'] = 99;
      _write(manifest, value);
      expect((runFixtureSet(manifest)['summary']! as Map)['skipped'], 1);
    });
    test('duplicate IDs reject the manifest', () {
      final value = _read(manifest);
      (value['cases'] as List).add((value['cases'] as List).single);
      _write(manifest, value);
      expect(() => runFixtureSet(manifest), throwsFormatException);
    });
    test('missing fixture-set identity rejects the manifest', () {
      final value = _read(manifest)..remove('fixtureSetId');
      _write(manifest, value);
      expect(() => runFixtureSet(manifest), throwsFormatException);
    });
    test('empty corpus cannot produce a vacuous pass', () {
      final value = _read(manifest)..['cases'] = <Object?>[];
      _write(manifest, value);
      expect(() => runFixtureSet(manifest), throwsFormatException);
    });
    test('missing project is a project load failure', () {
      final value = _read(manifest);
      (value['cases'] as List).single['projectPath'] = 'missing.story';
      _write(manifest, value);
      expect(failure()['kind'], 'projectLoadFailure');
    });
    test('escaping case path is a runner failure', () {
      final value = _read(manifest);
      (value['cases'] as List).single['path'] = '../outside';
      _write(manifest, value);
      expect(failure()['kind'], 'runnerFailure');
    });
    test('missing expectation never passes', () {
      File(caseFile('expected_trace.json')).deleteSync();
      expect(failure()['kind'], 'runnerFailure');
    });
    test(
      'runtime input failure is reported separately from harness errors',
      () {
        final value = _read(caseFile('input_trace.json'));
        (value['inputs'] as List)[1] = {
          'kind': 'choose',
          'choiceId': 'missing',
        };
        _write(caseFile('input_trace.json'), value);
        expect(failure()['kind'], 'inputFailure');
      },
    );
    test('unknown input is a harness failure', () {
      final value = _read(caseFile('input_trace.json'));
      (value['inputs'] as List)[1] = {'kind': 'unknown'};
      _write(caseFile('input_trace.json'), value);
      expect(failure()['kind'], 'runnerFailure');
    });
    // Exercise the same command function used by the executable. VM startup
    // and source compilation belong to standalone smoke verification, not
    // each contract test's deadline.
    test('CLI writes a valid report file', () {
      final output = '${temporary.path}/reports/result.json';
      final success = _runCli(['--fixture-set=$manifest', '--output=$output']);
      expect(success.exitCode, 0, reason: success.stderr);
      expect(_read(output)['summary']['passed'], 1);
    });
    test('CLI returns exit 1 and a report for skipped contracts', () {
      final value = _read(manifest)..['profile'] = 'unsupported';
      _write(manifest, value);
      final skipped = _runCli(['--fixture-set=$manifest']);
      expect(skipped.exitCode, 1, reason: skipped.stderr);
      expect((jsonDecode(skipped.stdout) as Map)['summary']['skipped'], 1);
    });
    test('CLI returns exit 1 and a report for a golden mismatch', () {
      final path = caseFile('expected_trace.json');
      final value = _read(path);
      (value['observations'] as List).first['currentEventId'] =
          'deliberately_wrong';
      _write(path, value);
      final failed = _runCli(['--fixture-set=$manifest']);
      expect(failed.exitCode, 1, reason: failed.stderr);
      final report = jsonDecode(failed.stdout) as Map;
      expect(report['summary']['failed'], 1);
      expect(
        ((report['results'] as List).single['failures'] as List).single['kind'],
        'traceMismatch',
      );
    });
    test('CLI rejects unknown options with exit 2', () {
      final result = _runCli(['--unknown']);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('Unknown option'));
    });
    test('CLI help does not load the configured fixture', () {
      final result = _runCli(['--fixture-set=missing-fixture.json', '--help']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('--fixture-set=PATH'));
      expect(result.stderr, isEmpty);
    });
    test('CLI emits only valid report JSON to stdout on success', () {
      final result = _runCli(['--fixture-set=$manifest']);
      expect(result.exitCode, 0);
      expect(result.stderr, isEmpty);
      expect((jsonDecode(result.stdout) as Map)['summary']['passed'], 1);
    });
    test('CLI defaults to the complete foundation corpus', () {
      final result = _runCli([]);
      expect(result.exitCode, 0);
      expect(result.stderr, isEmpty);
      expect((jsonDecode(result.stdout) as Map)['summary'], {
        'total': 6,
        'passed': 6,
        'failed': 0,
        'skipped': 0,
      });
    });
    test('CLI writes a failed report file and keeps exit 1', () {
      final value = _read(manifest)..['profile'] = 'unsupported';
      _write(manifest, value);
      final output = '${temporary.path}/reports/skipped.json';
      final result = _runCli(['--fixture-set=$manifest', '--output=$output']);
      expect(result.exitCode, 1);
      expect(result.stderr, isEmpty);
      expect(_read(output)['summary']['skipped'], 1);
      expect(result.stdout, 'Conformance report: $output\n');
    });
    test('CLI rejects an unusable report destination with exit 2', () {
      final result = _runCli([
        '--fixture-set=$manifest',
        '--output=${temporary.path}',
      ]);
      expect(result.exitCode, 2);
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('Conformance runner failed'));
    });
    test('CLI return statuses do not mutate the caller process exit code', () {
      final original = exitCode;
      expect(_runCli(['--unknown']).exitCode, 2);
      expect(exitCode, original);
      final value = _read(manifest)..['profile'] = 'unsupported';
      _write(manifest, value);
      expect(_runCli(['--fixture-set=$manifest']).exitCode, 1);
      expect(exitCode, original);
      _write(manifest, value..['profile'] = 'runtime-core-v1');
      expect(_runCli(['--fixture-set=$manifest']).exitCode, 0);
      expect(exitCode, original);
    });
    test('CLI rejects malformed manifest JSON with exit 2', () {
      File(manifest).writeAsStringSync('invalid JSON');
      final result = _runCli(['--fixture-set=$manifest']);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('Conformance runner failed'));
    });
  });
}

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
void _write(String path, Object value) =>
    File(path).writeAsStringSync(jsonEncode(value));
void _copy(Directory source, Directory destination) {
  for (final file in source.listSync(recursive: true).whereType<File>()) {
    final target = File(
      '${destination.path}/${file.path.substring(source.path.length + 1)}',
    );
    target.parent.createSync(recursive: true);
    file.copySync(target.path);
  }
}

({int exitCode, String stdout, String stderr}) _runCli(List<String> arguments) {
  final output = StringBuffer();
  final errors = StringBuffer();
  final code = cli.runConformanceCli(arguments, output: output, errors: errors);
  return (exitCode: code, stdout: output.toString(), stderr: errors.toString());
}
