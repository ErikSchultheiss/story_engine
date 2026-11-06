import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    '1D diagnostic paths retain empty, prefix, field and numeric ordering',
    () {
      final paths = <List<StoryDiagnosticPathSegment>>[
        [],
        [const StoryDiagnosticPathSegment.field('a')],
        [
          const StoryDiagnosticPathSegment.field('a'),
          const StoryDiagnosticPathSegment.index(2),
        ],
        [
          const StoryDiagnosticPathSegment.field('a'),
          const StoryDiagnosticPathSegment.index(10),
        ],
        [const StoryDiagnosticPathSegment.field('b')],
        [const StoryDiagnosticPathSegment.index(0)],
      ];
      final locations = paths.map(_location).toList();
      for (var i = 0; i < locations.length; i++) {
        expect(locations[i].compareTo(_location(paths[i])), 0);
        for (var j = i + 1; j < locations.length; j++) {
          expect(locations[i].compareTo(locations[j]), lessThan(0));
          expect(locations[j].compareTo(locations[i]), greaterThan(0));
        }
      }
      final shuffled = locations.reversed.toList()..sort();
      expect(shuffled, locations);
    },
  );

  test(
    '1D report order retains reference and related-location prefix precedence',
    () {
      final a = StoryDiagnosticReference.event(StoryEventId('a'));
      final b = StoryDiagnosticReference.event(StoryEventId('b'));
      final pathA = _location([const StoryDiagnosticPathSegment.field('a')]);
      final pathB = _location([const StoryDiagnosticPathSegment.field('b')]);
      final pathZ = _location([const StoryDiagnosticPathSegment.field('z')]);
      final ordered = [
        _diagnostic('empty references', related: [pathZ]),
        _diagnostic('a without related', references: [a]),
        _diagnostic('a with related prefix', references: [a], related: [pathA]),
        _diagnostic(
          'a with longer related',
          references: [a],
          related: [pathB, pathA],
        ),
        _diagnostic('longer references', references: [b, a]),
        _diagnostic('b reference', references: [b]),
      ];
      final report = StoryValidationReport(
        projectId: _projectId,
        diagnostics: ordered.reversed,
      );
      expect(report.diagnostics.map((d) => d.message), [
        'empty references',
        'a without related',
        'a with related prefix',
        'a with longer related',
        'longer references',
        'b reference',
      ]);
      expect(report.diagnostics, ordered);
      expect(report.diagnostics[3].relatedLocations, [pathA, pathB]);
      expect(report.diagnostics[4].references, [a, b]);
    },
  );
}

final _projectId = StoryProjectId('ordering_1d');
final _eventId = StoryEventId('root');
StoryDiagnosticLocation _location(List<StoryDiagnosticPathSegment> path) =>
    StoryDiagnosticLocation.event(
      projectId: _projectId,
      eventId: _eventId,
      path: path,
    );

StoryDiagnostic _diagnostic(
  String message, {
  List<StoryDiagnosticReference> references = const [],
  List<StoryDiagnosticLocation> related = const [],
}) => StoryDiagnostic(
  code: const StoryDiagnosticCode('extension.order'),
  severity: StoryDiagnosticSeverity.warning,
  message: message,
  location: _location(const []),
  references: references,
  relatedLocations: related,
);
