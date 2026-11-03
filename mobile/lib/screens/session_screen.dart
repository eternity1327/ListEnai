import 'dart:async';

import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/session.dart';
import '../services/api.dart';
import '../widgets/dialogs.dart';
import '../widgets/generate_sheet.dart';
import '../widgets/report_view.dart';
import 'ask_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.id});

  final int id;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const _pollEvery = Duration(seconds: 3);

  final _transcript = TextEditingController();
  Session? _session;
  String? _loadError;
  Timer? _poll;
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      _show(await Api.session(widget.id));
    } catch (error) {
      if (!mounted) return;
      if (_session == null) {
        setState(() => _loadError = '$error');
        return;
      }
      toast(context, '$error');
      if (_session!.isBusy) _poll = Timer(_pollEvery, _refresh);
    }
  }

  void _show(Session session) {
    if (!mounted) return;
    if (!_edited) _transcript.text = session.transcript ?? '';
    _poll?.cancel();
    if (session.isBusy) _poll = Timer(_pollEvery, _refresh);
    setState(() {
      _session = session;
      _loadError = null;
    });
  }

  Future<bool> _run(Future<Session> action) async {
    try {
      _show(await action);
      return true;
    } catch (error) {
      if (mounted) toast(context, '$error');
      return false;
    }
  }

  Future<bool> _saveTranscript() async {
    final saved = await _run(Api.saveTranscript(widget.id, _transcript.text));
    if (saved && mounted) setState(() => _edited = false);
    return saved;
  }

  Future<void> _generate() async {
    final options = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (_) => const GenerateSheet(),
    );
    if (options == null) return;
    if (_edited && !await _saveTranscript()) return;
    await _run(Api.generate(widget.id, options.$1, options.$2));
  }

  void _openQuiz(List<Question> questions) => _push(QuizScreen(questions: questions));

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  List<(String, String)> _cards(Map<String, dynamic> report) => [
        for (final term in report['key_terms'] as List? ?? [])
          ('${term['term']}', '${term['meaning']}'),
      ];

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(session?.title ?? 'Session'),
        actions: [
          if (session?.transcript != null)
            IconButton(
              onPressed: () => _push(AskScreen(id: widget.id)),
              icon: const Icon(Icons.question_answer_outlined),
              tooltip: 'Ask the lecture',
            ),
        ],
      ),
      body: session == null
          ? _center([_loadError == null ? const CircularProgressIndicator() : Text(_loadError!)])
          : Column(
              children: [
                if (session.error != null && !session.isBusy) _errorBox(session.error!),
                Expanded(child: _content(session)),
              ],
            ),
    );
  }

  Widget _content(Session session) {
    if (session.isBusy) {
      return _center([
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(session.busyLabel),
        const SizedBox(height: 8),
        const Text('Long recordings can take several minutes.'),
      ]);
    }
    if (session.transcript == null) {
      return _center([
        const Text('Turn this recording into text first.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _run(Api.transcribe(widget.id)),
          icon: const Icon(Icons.subtitles),
          label: const Text('Transcribe'),
        ),
      ]);
    }
    return DefaultTabController(
      length: 2,
      initialIndex: session.report == null ? 0 : 1,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Transcript'), Tab(text: 'Report')]),
          Expanded(
            child: TabBarView(children: [_transcriptTab(), _reportTab(session.report)]),
          ),
        ],
      ),
    );
  }

  Widget _transcriptTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _transcript,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) {
                if (!_edited) setState(() => _edited = true);
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _edited ? _saveTranscript : null,
                  child: const Text('Save changes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _generate, child: const Text('Generate')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportTab(Map<String, dynamic>? report) {
    if (report == null) {
      return _center([
        const Text('Create a lesson and quiz, or a meeting report.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _generate, child: const Text('Generate')),
      ]);
    }
    final questions = Question.fromReport(report);
    final cards = _cards(report);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ReportView(report: report),
        const SizedBox(height: 24),
        if (questions.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _openQuiz(questions),
            icon: const Icon(Icons.quiz),
            label: Text('Take quiz (${questions.length} questions)'),
          ),
        if (cards.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _push(FlashcardScreen(cards: cards)),
            icon: const Icon(Icons.style),
            label: Text('Flashcards (${cards.length} terms)'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _generate, child: const Text('Regenerate')),
      ],
    );
  }

  Widget _errorBox(String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }

  Widget _center(List<Widget> children) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}
