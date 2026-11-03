import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Api {
  static const _urlKey = 'server_url';
  static const _appKey = String.fromEnvironment('APP_KEY');
  static const _headers = {'X-App-Key': _appKey};
  static const _jsonHeaders = {..._headers, 'Content-Type': 'application/json'};
  static const _wait = Duration(seconds: 90);
  static String baseUrl = const String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://192.168.1.62:8000',
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_urlKey) ?? baseUrl;
  }

  static Future<void> saveUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, baseUrl);
  }

  static Future<List<Session>> sessions() async {
    final data = await _send(() => http.get(_uri('/sessions'), headers: _headers)) as List;
    return data.map((item) => Session.fromJson(item as Map<String, dynamic>)).toList();
  }

  static Future<Session> session(int id) => _session(() => http.get(_uri('/sessions/$id'), headers: _headers));

  static Future<Session> upload(String title, String path) => _session(
        () async {
          final request = http.MultipartRequest('POST', _uri('/sessions'))
            ..headers.addAll(_headers)
            ..fields['title'] = title
            ..files.add(await http.MultipartFile.fromPath('file', path));
          return http.Response.fromStream(await request.send());
        },
        timeout: const Duration(minutes: 10),
      );

  static Future<Session> transcribe(int id) =>
      _session(() => http.post(_uri('/sessions/$id/transcribe'), headers: _headers));

  static Future<Session> saveTranscript(int id, String transcript) => _session(
        () => http.put(
          _uri('/sessions/$id/transcript'),
          headers: _jsonHeaders,
          body: jsonEncode({'transcript': transcript}),
        ),
      );

  static Future<Session> generate(int id, String mode, String level) => _session(
        () => http.post(
          _uri('/sessions/$id/generate'),
          headers: _jsonHeaders,
          body: jsonEncode({'mode': mode, 'level': level}),
        ),
      );

  static Future<List<(String, String)>> questions(int id) async {
    final data = await _send(() => http.get(_uri('/sessions/$id/questions'), headers: _headers)) as List;
    return [
      for (final item in data.cast<Map<String, dynamic>>())
        (item['question'] as String, item['answer'] as String),
    ];
  }

  static Future<String> ask(int id, String question) async {
    final data = await _send(
      () => http.post(
        _uri('/sessions/$id/ask'),
        headers: _jsonHeaders,
        body: jsonEncode({'question': question}),
      ),
      timeout: const Duration(minutes: 3),
    );
    return (data as Map<String, dynamic>)['answer'] as String;
  }

  static Future<void> delete(int id) => _send(() => http.delete(_uri('/sessions/$id'), headers: _headers));

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Future<Session> _session(
    Future<http.Response> Function() request, {
    Duration timeout = _wait,
  }) async {
    final data = await _send(request, timeout: timeout);
    return Session.fromJson(data as Map<String, dynamic>);
  }

  static Future<dynamic> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _wait,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on SocketException {
      throw ApiException('Cannot reach the ListenAI server at $baseUrl.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw ApiException('Cannot reach the ListenAI server at $baseUrl.');
    }
    final body = _decode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (response.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      throw ApiException(detail is String ? detail : 'Request failed (${response.statusCode}).');
    }
    return body;
  }

  static dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
