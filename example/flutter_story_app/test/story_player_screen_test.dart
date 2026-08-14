import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_engine_flutter_example/main.dart';

void main() {
  testWidgets(
    'Flutter host can play, save, restore, continue, and restart',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StoryEngineExampleApp());

      expect(
        find.text('Validation: 0 errors, 0 warnings, 0 information'),
        findsOneWidget,
      );
      expect(find.text('Forest Gate'), findsOneWidget);
      expect(find.text('Status: awaitingChoice'), findsOneWidget);
      expect(find.text('lantern_lit: false'), findsOneWidget);
      expect(find.text('Saved snapshot: no'), findsOneWidget);

      final lightLantern = find.byKey(
        const ValueKey<String>('choice-light_lantern'),
      );
      await tester.ensureVisible(lightLantern);
      await tester.tap(lightLantern);
      await tester.pump();

      expect(find.text('Old Tunnel'), findsOneWidget);
      expect(find.text('Status: awaitingContinue'), findsOneWidget);
      expect(find.text('lantern_lit: true'), findsOneWidget);

      final save = find.byKey(const ValueKey<String>('save-snapshot'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();

      expect(find.text('Snapshot saved in memory.'), findsOneWidget);
      expect(find.text('Saved snapshot: yes'), findsOneWidget);

      final continueStory = find.byKey(
        const ValueKey<String>('continue-story'),
      );
      await tester.ensureVisible(continueStory);
      await tester.tap(continueStory);
      await tester.pump();

      expect(find.text('Story finished.'), findsOneWidget);
      expect(find.text('Status: terminated'), findsOneWidget);

      final restore = find.byKey(
        const ValueKey<String>('restore-snapshot'),
      );
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pump();

      expect(find.text('Snapshot restored.'), findsOneWidget);
      expect(find.text('Old Tunnel'), findsOneWidget);
      expect(find.text('Status: awaitingContinue'), findsOneWidget);
      expect(find.text('lantern_lit: true'), findsOneWidget);

      final restart = find.byKey(
        const ValueKey<String>('restart-story'),
      );
      await tester.ensureVisible(restart);
      await tester.tap(restart);
      await tester.pump();

      expect(find.text('Started a fresh run.'), findsOneWidget);
      expect(find.text('Forest Gate'), findsOneWidget);
      expect(find.text('Status: awaitingChoice'), findsOneWidget);
      expect(find.text('lantern_lit: false'), findsOneWidget);
    },
  );
}
