import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../widgets/dialogs.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 32000,
    sampleRate: 16000,
    numChannels: 1,
  );

  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  RecordState _state = RecordState.stop;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) toast(context, 'Microphone permission is required to record.');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(_config, path: path);
    if (!mounted) return;
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() => _state = RecordState.record);
  }

  Future<void> _togglePause() async {
    if (_state == RecordState.record) {
      await _recorder.pause();
      _stopwatch.stop();
      setState(() => _state = RecordState.pause);
    } else {
      await _recorder.resume();
      _stopwatch.start();
      setState(() => _state = RecordState.record);
    }
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    _ticker?.cancel();
    if (mounted) Navigator.pop(context, path);
  }

  String get _elapsed {
    final time = _stopwatch.elapsed;
    final minutes = time.inMinutes.toString().padLeft(2, '0');
    final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
    return time.inHours > 0 ? '${time.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final idle = _state == RecordState.stop;
    final paused = _state == RecordState.pause;
    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_elapsed, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text(idle ? 'Ready' : paused ? 'Paused' : 'Recording'),
            const SizedBox(height: 32),
            if (idle)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic),
                label: const Text('Start'),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? 'Resume' : 'Pause'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & save'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
