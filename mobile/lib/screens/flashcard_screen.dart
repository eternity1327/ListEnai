import 'package:flutter/material.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key, required this.cards});

  final List<(String, String)> cards;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<(String, String)> _deck = [...widget.cards];
  bool _flipped = false;

  void _next({required bool known}) => setState(() {
        final card = _deck.removeAt(0);
        if (!known) _deck.add(card);
        _flipped = false;
      });

  void _restart() => setState(() {
        _deck = [...widget.cards]..shuffle();
        _flipped = false;
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_deck.isEmpty ? 'Flashcards' : '${_deck.length} left')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _deck.isEmpty ? _done(text) : _card(text),
      ),
    );
  }

  Widget _card(TextTheme text) {
    final (term, meaning) = _deck.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            child: InkWell(
              onTap: () => setState(() => _flipped = !_flipped),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _flipped ? meaning : term,
                    textAlign: TextAlign.center,
                    style: _flipped ? text.titleMedium : text.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(_flipped ? 'Did you know it?' : 'Tap the card to flip', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _flipped ? () => _next(known: false) : null,
                child: const Text('Again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _flipped ? () => _next(known: true) : null,
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done(TextTheme text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('All cards done!', style: text.headlineSmall),
            const SizedBox(height: 16),
            FilledButton(onPressed: _restart, child: const Text('Study again')),
          ],
        ),
      );
}
