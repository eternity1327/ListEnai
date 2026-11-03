import 'package:flutter/material.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${report['title']}', style: text.headlineSmall),
        const SizedBox(height: 8),
        ...(report['type'] == 'meeting' ? _meeting(text) : _lesson(text)),
      ],
    );
  }

  List<Widget> _lesson(TextTheme text) => [
        Text('${report['level']} level', style: text.labelLarge),
        const SizedBox(height: 8),
        Text('${report['overview']}'),
        ..._bullets(text, 'Objectives', _strings('objectives')),
        for (final section in _maps('sections')) ...[
          _heading(text, '${section['heading']}'),
          Text('${section['explanation']}'),
          if ('${section['example']}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Example: ${section['example']}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
        ..._bullets(text, 'Key terms', [
          for (final term in _maps('key_terms')) '${term['term']}: ${term['meaning']}',
        ]),
        ..._bullets(text, 'Remember', _strings('remember')),
      ];

  List<Widget> _meeting(TextTheme text) => [
        Text('${report['summary']}'),
        ..._bullets(text, 'Key points', _strings('points')),
        ..._bullets(text, 'Decisions', _strings('decisions')),
        ..._bullets(text, 'Action items', _strings('action_items')),
        ..._bullets(text, 'Needs confirmation', _strings('to_confirm')),
      ];

  List<String> _strings(String key) => List<String>.from(report[key] as List? ?? []);

  List<Map<String, dynamic>> _maps(String key) =>
      List<Map<String, dynamic>>.from(report[key] as List? ?? []);

  Widget _heading(TextTheme text, String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(title, style: text.titleMedium),
      );

  List<Widget> _bullets(TextTheme text, String title, List<String> items) => [
        if (items.isNotEmpty) _heading(text, title),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('•  $item'),
          ),
      ];
}
