import 'dart:convert';

import 'package:http/http.dart' as http;

const String _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://printer-manager.com',
);

class PartRequestApi {
  PartRequestApi({http.Client? client, String baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _baseUri;
  String? _token;

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _resolve('/api/mobile/login'),
      headers: _headers(includeAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);

    final token = _readString(
      body['token'] ??
          body['access_token'] ??
          (body['data'] is Map ? body['data']['token'] : null) ??
          (body['data'] is Map ? body['data']['access_token'] : null),
    );

    if (token == null || token.isEmpty) {
      throw ApiException(
        'Login succeeded but no token was returned. Response keys: ${body.keys.join(', ')}',
      );
    }

    _token = token;
    return token;
  }

  Future<List<Map<String, dynamic>>> listPartRequests() async {
    final response = await _client.get(
      _resolve('/api/mobile/part-request'),
      headers: _headers(),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractList(body);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get(
      _resolve('/api/mobile/profile'),
      headers: _headers(),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractItem(body);
  }

  Future<Map<String, dynamic>> showPartRequest(int id) async {
    final response = await _client.get(
      _resolve('/api/mobile/part-request/$id'),
      headers: _headers(),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractItem(body);
  }

  Future<Map<String, dynamic>> createPartRequest(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      _resolve('/api/mobile/part-request'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractItem(body);
  }

  Future<Map<String, dynamic>> updatePartRequest(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.put(
      _resolve('/api/mobile/part-request/$id'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractItem(body);
  }

  Future<List<Map<String, dynamic>>> searchPartRequests(
    Map<String, dynamic> filters,
  ) async {
    final response = await _client.post(
      _resolve('/api/mobile/search/part-requests'),
      headers: _headers(),
      body: jsonEncode(filters),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractList(body);
  }

  Map<String, String> _headers({bool includeAuth = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (includeAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  Uri _resolve(String path) => _baseUri.resolve(path);

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is List) {
      return <String, dynamic>{'data': decoded};
    }

    return <String, dynamic>{'data': decoded};
  }

  void _ensureSuccess(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw ApiException(
      _extractMessage(body) ?? 'Request failed (${response.statusCode}).',
    );
  }

  String? _extractMessage(Map<String, dynamic> body) {
    return _readString(body['message']) ??
        _readString(body['error']) ??
        _readString(body['errors']);
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> body) {
    final dynamic candidate =
        body['data'] ?? body['results'] ?? body['items'] ?? body;
    if (candidate is List) {
      return candidate.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry('$key', value));
      }).toList();
    }

    if (candidate is Map<String, dynamic>) {
      final nested = candidate['data'];
      if (nested is List) {
        return nested.whereType<Map>().map((item) {
          return item.map((key, value) => MapEntry('$key', value));
        }).toList();
      }
    }

    return const [];
  }

  Map<String, dynamic> _extractItem(Map<String, dynamic> body) {
    final dynamic candidate = body['data'] ?? body['item'] ?? body;
    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
    return body;
  }
}

String? _readString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
