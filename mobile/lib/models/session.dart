class Session {
  const Session({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.status,
    this.error,
    this.progress,
    this.transcript,
    this.report,
  });

  final int id;
  final String title;
  final String createdAt;
  final String status;
  final String? error;
  final String? progress;
  final String? transcript;
  final Map<String, dynamic>? report;

  bool get isBusy => status == 'transcribing' || status == 'generating';

  String get busyLabel =>
      progress ?? (status == 'transcribing' ? 'Transcribing audio...' : 'Creating your report...');

  String get date => createdAt.split('T').first;

  String get statusLabel => switch (status) {
        'uploaded' => 'Not transcribed',
        'transcribing' => 'Transcribing...',
        'transcribed' => 'Transcript ready',
        'generating' => 'Generating...',
        'ready' => 'Report ready',
        _ => status,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as int,
        title: json['title'] as String,
        createdAt: json['created_at'] as String,
        status: json['status'] as String,
        error: json['error'] as String?,
        progress: json['progress'] as String?,
        transcript: json['transcript'] as String?,
        report: json['report'] as Map<String, dynamic>?,
      );
}
