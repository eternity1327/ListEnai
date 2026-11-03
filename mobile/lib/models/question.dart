class Question {
  const Question({
    required this.question,
    required this.choices,
    required this.answer,
    required this.explanation,
  });

  final String question;
  final List<String> choices;
  final int answer;
  final String explanation;

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        question: json['question'] as String,
        choices: List<String>.from(json['choices'] as List),
        answer: json['answer'] as int,
        explanation: json['explanation'] as String,
      );

  static List<Question> fromReport(Map<String, dynamic> report) =>
      (report['quiz'] as List? ?? [])
          .map((item) => Question.fromJson(item as Map<String, dynamic>))
          .toList();
}
