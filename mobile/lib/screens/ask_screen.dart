import 'package:flutter/material.dart';

import '../services/api.dart';
import '../widgets/dialogs.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key, required this.id});

  final int id;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _input = TextEditingController();
  final List<(String, String?)> _chat = [];

  bool get _waiting => _chat.isNotEmpty && _chat.last.$2 == null;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await Api.questions(widget.id);
      if (mounted) setState(() => _chat.insertAll(0, history));
    } catch (error) {
      if (mounted) toast(context, '$error');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _waiting) return;
    _input.clear();
    setState(() => _chat.add((question, null)));
    try {
      final answer = await Api.ask(widget.id, question);
      if (mounted) setState(() => _chat.last = (question, answer));
    } catch (error) {
      if (!mounted) return;
      setState(() => _chat.removeLast());
      _input.text = question;
      toast(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask the lecture')),
      body: Column(
        children: [
          Expanded(
            child: _chat.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Ask anything about this recording. Answers come only from the transcript.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final (question, answer) in _chat) ...[
                        _bubble(question, mine: true),
                        _bubble(answer ?? 'Thinking...', mine: false),
                      ],
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _waiting ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, {required bool mine}) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }
}
