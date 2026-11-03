import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/session.dart';
import '../services/api.dart';
import '../widgets/dialogs.dart';
import 'record_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Session> _sessions = [];
  String? _error;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    Api.load().then((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final sessions = await Api.sessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _editServer() async {
    final url = await askText(
      context,
      title: 'Server address',
      initial: Api.baseUrl,
      hint: 'http://192.168.1.10:8000',
    );
    if (url == null || url.isEmpty) return;
    await Api.saveUrl(url);
    await _refresh();
  }

  Future<void> _record() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RecordScreen()),
    );
    if (path == null) return;
    final today = DateTime.now().toString().split(' ').first;
    await _upload(path, 'Lecture $today', deleteAfter: true);
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    await _upload(file.path!, file.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
  }

  Future<void> _upload(String path, String suggestedTitle, {bool deleteAfter = false}) async {
    if (!mounted) return;
    final title = await askText(context, title: 'Session title', initial: suggestedTitle);
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final session = await Api.upload(title, path);
      if (deleteAfter) File(path).delete().ignore();
      if (mounted) setState(() => _uploading = false);
      await _open(session.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$error'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _upload(path, title, deleteAfter: deleteAfter),
        ),
      ));
    }
  }

  Future<void> _open(int id) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(id: id)));
    await _refresh();
  }

  Future<void> _delete(Session session) async {
    if (!await confirm(context, 'Delete "${session.title}" and its audio?')) return;
    try {
      await Api.delete(session.id);
      await _refresh();
    } catch (error) {
      if (mounted) toast(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ListenAI'),
        actions: [
          IconButton(
            onPressed: _editServer,
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Server address',
          ),
        ],
        bottom: _uploading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _body()),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _record,
                  icon: const Icon(Icons.mic),
                  label: const Text('Record'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload audio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) return _message(_error!);
    if (_sessions.isEmpty) return _message('No sessions yet. Record or upload a lecture to begin.');
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Recent sessions'),
        ),
        for (final session in _sessions)
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: Text(session.title),
            subtitle: Text('${session.date} · ${session.statusLabel}'),
            trailing: IconButton(
              onPressed: () => _delete(session),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
            onTap: () => _open(session.id),
          ),
      ],
    );
  }

  Widget _message(String text) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ],
      );
}
