import 'package:flutter/material.dart';

import '../models/question.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.questions});

  final List<Question> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<int, int> _answers = {};
  bool _submitted = false;

  int get _score {
    var score = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      if (_answers[i] == widget.questions[i].answer) score++;
    }
    return score;
  }

  List<Question> get _missed => [
        for (var i = 0; i < widget.questions.length; i++)
          if (_answers[i] != widget.questions[i].answer) widget.questions[i],
      ];

  void _retryMissed() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizScreen(questions: _missed)),
      );

  void _retake() => setState(() {
        _answers.clear();
        _submitted = false;
      });

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    final allAnswered = _answers.length == questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_submitted ? 'Score: $_score / ${questions.length}' : 'Quiz'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) => _card(index, questions[index]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _submitted
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _retake, child: const Text('Retake all')),
                    ),
                    if (_missed.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _retryMissed,
                          child: Text('Retry missed (${_missed.length})'),
                        ),
                      ),
                    ],
                  ],
                )
              : FilledButton(
                  onPressed: allAnswered ? () => setState(() => _submitted = true) : null,
                  child: Text(allAnswered ? 'Submit' : 'Answer all questions to submit'),
                ),
        ),
      ),
    );
  }

  Widget _card(int index, Question question) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. ${question.question}', style: theme.textTheme.titleMedium),
            for (var choice = 0; choice < question.choices.length; choice++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _icon(index, choice, question),
                  color: _color(index, choice, question, theme.colorScheme),
                ),
                title: Text(question.choices[choice]),
                onTap: _submitted ? null : () => setState(() => _answers[index] = choice),
              ),
            if (_submitted) Text(question.explanation, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  IconData _icon(int index, int choice, Question question) {
    final picked = _answers[index] == choice;
    if (_submitted && choice == question.answer) return Icons.check_circle;
    if (_submitted && picked) return Icons.cancel;
    return picked ? Icons.radio_button_checked : Icons.radio_button_unchecked;
  }

  Color? _color(int index, int choice, Question question, ColorScheme colors) {
    if (!_submitted) return null;
    if (choice == question.answer) return Colors.green;
    if (_answers[index] == choice) return colors.error;
    return null;
  }
}
