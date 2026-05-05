// Ce fichier encapsule les appels HTTP bas niveau.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException({
    required this.method,
    required this.path,
    required this.statusCode,
    this.detail,
  });

  final String method;
  final String path;
  final int statusCode;
  final dynamic detail;

  String get message {
    if (detail is String && (detail as String).trim().isNotEmpty) {
      return detail as String;
    }
    if (detail is Map) {
      final detailMap = Map<String, dynamic>.from(detail as Map);
      final payloadMessage = detailMap['message'];
      if (payloadMessage is String && payloadMessage.trim().isNotEmpty) {
        return payloadMessage;
      }
    }
    return '$method $path failed with $statusCode';
  }

  @override
  String toString() => message;
}

/// Client HTTP minimal chargé des appels API bas niveau.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<dynamic> get(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        method: 'GET',
        path: path,
        statusCode: response.statusCode,
        detail: _decodeErrorDetail(response.body),
      );
    }
    return _decodeSuccessBody(response.body);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    _ensureSuccess(method: 'GET', path: path, response: response);
    return response.bodyBytes;
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureSuccess(method: 'POST', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureSuccess(method: 'PUT', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(Uri.parse('$baseUrl$path'));
    _ensureSuccess(method: 'DELETE', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  Future<dynamic> uploadBytes(
    String path,
    Uint8List bytes,
    String filename, {
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _ensureSuccess(method: 'POST', path: path, response: response);
    return _decodeSuccessBody(response.body);
  }

  void _ensureSuccess({
    required String method,
    required String path,
    required http.Response response,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(
      method: method,
      path: path,
      statusCode: response.statusCode,
      detail: _decodeErrorDetail(response.body),
    );
  }

  dynamic _decodeSuccessBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  dynamic _decodeErrorDetail(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        return decoded['detail'];
      }
      return decoded;
    } catch (_) {
      return body;
    }
  }
}
