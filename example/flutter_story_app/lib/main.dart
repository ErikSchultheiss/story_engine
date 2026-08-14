import 'package:flutter/material.dart';
import 'package:story_engine/story_engine.dart';

import 'example_story.dart';

void main() => runApp(const StoryEngineExampleApp());

/// Minimal Flutter host for the pure-Dart `story_engine` package.
class StoryEngineExampleApp extends StatelessWidget {
  const StoryEngineExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'story_engine Flutter example',
      theme: ThemeData(useMaterial3: true),
      home: const StoryPlayerScreen(),
    );
  }
}

/// Demonstrates how a Flutter widget owns presentation and input while the
/// engine owns narrative state, validation, transitions, and snapshots.
class StoryPlayerScreen extends StatefulWidget {
  const StoryPlayerScreen({super.key});

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> {
  final StoryRuntimeSnapshotCodec _snapshotCodec = StoryRuntimeSnapshotCodec();

  late final StoryProject _project;
  late final StoryValidationReport _validation;
  StoryEngine? _engine;
  String? _savedSnapshotJson;
  String? _message;
  String? _failure;

  @override
  void initState() {
    super.initState();

    // Story Format is storage-neutral. A production app can load the logical
    // bundle from assets/files/database/network and hand it to the same codec.
    const storyFormat = StoryFormatCodec();
    final authoredProject = buildFlutterExampleProject();
    _project = storyFormat.decodeProject(
      storyFormat.encodeProject(authoredProject),
    );
    _validation = StoryValidator.validate(_project);

    if (!_validation.hasErrors) {
      _engine = StoryEngine(project: _project)..start();
    }
  }

  void _choose(StoryChoice choice) {
    _runEngineOperation(() {
      _engine!.choose(choice.id);
      _message = 'Selected: ${_choiceText(choice)}';
    });
  }

  void _continueStory() {
    _runEngineOperation(() {
      _engine!.continueStory();
      _message = 'Continued story.';
    });
  }

  void _saveSnapshot() {
    _runEngineOperation(() {
      _savedSnapshotJson = _snapshotCodec.encodeJson(
        _engine!.createSnapshot(),
      );
      _message = 'Snapshot saved in memory.';
    });
  }

  void _restoreSnapshot() {
    final json = _savedSnapshotJson;
    if (json == null) {
      return;
    }

    try {
      final snapshot = _snapshotCodec.decodeJson(json, project: _project);
      final restored = StoryEngine.restore(
        project: _project,
        snapshot: snapshot,
      );
      setState(() {
        _engine = restored;
        _failure = null;
        _message = 'Snapshot restored.';
      });
    } on Object catch (error) {
      setState(() {
        _failure = error.toString();
      });
    }
  }

  void _restart() {
    if (_validation.hasErrors) {
      return;
    }
    try {
      final engine = StoryEngine(project: _project)..start();
      setState(() {
        _engine = engine;
        _failure = null;
        _message = 'Started a fresh run.';
      });
    } on Object catch (error) {
      setState(() {
        _failure = error.toString();
      });
    }
  }

  void _runEngineOperation(void Function() operation) {
    try {
      operation();
      setState(() {
        _failure = null;
      });
    } on Object catch (error) {
      setState(() {
        _failure = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;

    return Scaffold(
      appBar: AppBar(title: const Text('story_engine Flutter example')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ValidationCard(report: _validation),
            const SizedBox(height: 12),
            if (_failure != null) ...[
              _FailureCard(message: _failure!),
              const SizedBox(height: 12),
            ],
            if (_validation.hasErrors)
              const Text(
                'Fix validation errors before starting the runtime.',
                key: ValueKey<String>('validation-blocked'),
              )
            else if (engine != null) ...[
              _RuntimeCard(
                engine: engine,
                hasSavedSnapshot: _savedSnapshotJson != null,
              ),
              const SizedBox(height: 12),
              _EventCard(
                engine: engine,
                onChoose: _choose,
                onContinue: _continueStory,
              ),
              const SizedBox(height: 12),
              _PersistenceControls(
                canRestore: _savedSnapshotJson != null,
                onSave: _saveSnapshot,
                onRestore: _restoreSnapshot,
                onRestart: _restart,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                key: const ValueKey<String>('host-message'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.report});

  final StoryValidationReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Validation: ${report.summary}',
              key: const ValueKey<String>('validation-summary'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (report.diagnostics.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final diagnostic in report.diagnostics)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(diagnostic.format()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          message,
          key: const ValueKey<String>('runtime-failure'),
        ),
      ),
    );
  }
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({
    required this.engine,
    required this.hasSavedSnapshot,
  });

  final StoryEngine engine;
  final bool hasSavedSnapshot;

  @override
  Widget build(BuildContext context) {
    final lantern = engine.state?.rawValueOf(lanternLitId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Text(
              'Status: ${engine.status.name}',
              key: const ValueKey<String>('runtime-status'),
            ),
            Text(
              'lantern_lit: $lantern',
              key: const ValueKey<String>('lantern-state'),
            ),
            Text(
              'Saved snapshot: ${hasSavedSnapshot ? 'yes' : 'no'}',
              key: const ValueKey<String>('snapshot-state'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.engine,
    required this.onChoose,
    required this.onContinue,
  });

  final StoryEngine engine;
  final ValueChanged<StoryChoice> onChoose;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final event = engine.currentEvent;
    if (event == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No current event.'),
        ),
      );
    }

    final presentation = event.presentation;
    final title = presentation?.title?.value ?? event.id.value;
    final body = presentation?.body?.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              key: const ValueKey<String>('event-title'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body),
            ],
            const SizedBox(height: 16),
            if (engine.status == StoryEngineStatus.awaitingChoice)
              for (final choice in engine.availableChoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    key: ValueKey<String>('choice-${choice.id.value}'),
                    onPressed: () => onChoose(choice),
                    child: Text(_choiceText(choice)),
                  ),
                )
            else if (engine.status == StoryEngineStatus.awaitingContinue)
              FilledButton(
                key: const ValueKey<String>('continue-story'),
                onPressed: onContinue,
                child: const Text('Continue story'),
              )
            else if (engine.status == StoryEngineStatus.terminated)
              const Text(
                'Story finished.',
                key: ValueKey<String>('story-finished'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersistenceControls extends StatelessWidget {
  const _PersistenceControls({
    required this.canRestore,
    required this.onSave,
    required this.onRestore,
    required this.onRestart,
  });

  final bool canRestore;
  final VoidCallback onSave;
  final VoidCallback onRestore;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey<String>('save-snapshot'),
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save snapshot'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('restore-snapshot'),
          onPressed: canRestore ? onRestore : null,
          icon: const Icon(Icons.restore),
          label: const Text('Restore snapshot'),
        ),
        TextButton.icon(
          key: const ValueKey<String>('restart-story'),
          onPressed: onRestart,
          icon: const Icon(Icons.replay),
          label: const Text('Restart'),
        ),
      ],
    );
  }
}

String _choiceText(StoryChoice choice) =>
    choice.presentation?.text.value ?? choice.id.value;
