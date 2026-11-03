import 'package:flutter/material.dart';

class GenerateSheet extends StatefulWidget {
  const GenerateSheet({super.key});

  @override
  State<GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends State<GenerateSheet> {
  String _mode = 'student';
  String _level = 'detailed';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Generate report', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Lesson'), icon: Icon(Icons.school)),
                ButtonSegment(value: 'meeting', label: Text('Meeting'), icon: Icon(Icons.groups)),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() => _mode = value.first),
            ),
            if (_mode == 'student') ...[
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'beginner', label: Text('Beginner')),
                  ButtonSegment(value: 'detailed', label: Text('Detailed')),
                  ButtonSegment(value: 'exam', label: Text('Exam')),
                ],
                selected: {_level},
                onSelectionChanged: (value) => setState(() => _level = value.first),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, (_mode, _level)),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}
