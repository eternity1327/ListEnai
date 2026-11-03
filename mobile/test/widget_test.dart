import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenai/models/question.dart';
import 'package:listenai/models/session.dart';
import 'package:listenai/screens/flashcard_screen.dart';

void main() {
  test('parses a session from the API', () {
    final session = Session.fromJson({
      'id': 1,
      'title': 'Java Recursion',
      'created_at': '2026-10-29T10:00:00',
      'status': 'generating',
      'progress': 'Reading part 2 of 5...',
    });
    expect(session.date, '2026-10-29');
    expect(session.isBusy, isTrue);
    expect(session.progress, 'Reading part 2 of 5...');
    expect(session.transcript, isNull);
  });

  test('reads quiz questions from a report', () {
    final questions = Question.fromReport({
      'quiz': [
        {
          'question': 'What stops recursion?',
          'choices': ['Base case', 'Loop', 'Return type', 'Stack'],
          'answer': 0,
          'explanation': 'The base case ends the calls.',
        },
      ],
    });
    expect(questions.single.choices[questions.single.answer], 'Base case');
  });

  testWidgets('flashcards repeat cards marked again', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FlashcardScreen(cards: [('BFS', 'Breadth-first search'), ('DFS', 'Depth-first search')]),
    ));
    expect(find.text('2 left'), findsOneWidget);
    await tester.tap(find.text('BFS'));
    await tester.pump();
    expect(find.text('Breadth-first search'), findsOneWidget);
    await tester.tap(find.text('Again'));
    await tester.pump();
    expect(find.text('DFS'), findsOneWidget);
    await tester.tap(find.text('DFS'));
    await tester.pump();
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.text('1 left'), findsOneWidget);
    expect(find.text('BFS'), findsOneWidget);
  });
}
