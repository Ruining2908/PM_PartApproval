import 'dart:convert';

import 'package:http/http.dart' as http;

const String _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://sit.printer-manager.com/',
);
const bool _demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

class PartRequestApi {
  PartRequestApi({http.Client? client, String baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client(),
      _baseUri = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _baseUri;
  String? _token;
  final List<Map<String, dynamic>> _demoRequests = _buildDemoRequests();

  Future<String> login({
    required String email,
    required String password,
  }) async {
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _token = 'demo-token';
      return _token!;
    }

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
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _cloneList(_demoRequests);
    }

    final response = await _client.get(
      _resolve('/api/mobile/part-request'),
      headers: _headers(),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractList(body);
  }

  Future<Map<String, dynamic>> getProfile() async {
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return <String, dynamic>{
        'id': 1,
        'name': 'Demo Approver',
        'email': 'demo.approver@printer-manager.com',
        'profile_photo_url': null,
      };
    }

    final response = await _client.get(
      _resolve('/api/mobile/profile'),
      headers: _headers(),
    );

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return _extractItem(body);
  }

  Future<Map<String, dynamic>> showPartRequest(int id) async {
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _findDemoRequest(id);
    }

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
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final nextId =
          _demoRequests
              .map((item) => item['id'] as int)
              .fold<int>(
                5000,
                (current, value) => value > current ? value : current,
              ) +
          1;
      final item = <String, dynamic>{
        'id': nextId,
        ...payload,
        'created_at':
            payload['created_at']?.toString() ??
            DateTime.now().toIso8601String().split('T').first,
      };
      _demoRequests.insert(0, item);
      return _cloneMap(item);
    }

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
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final index = _demoRequests.indexWhere((item) => item['id'] == id);
      if (index == -1) {
        throw const ApiException('Demo request not found.');
      }

      final merged = <String, dynamic>{..._demoRequests[index], ...payload};
      _demoRequests[index] = merged;
      return _cloneMap(merged);
    }

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
    if (_demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _cloneList(_demoRequests);
    }

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

  Map<String, dynamic> _findDemoRequest(int id) {
    final match = _demoRequests.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == id,
      orElse: () => null,
    );

    if (match == null) {
      throw const ApiException('Demo request not found.');
    }

    return _cloneMap(match);
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

List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>> source) {
  return source.map(_cloneMap).toList();
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
  return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _buildDemoRequests() {
  return [
    <String, dynamic>{
      'id': 5001,
      'part_name': 'Cyan Drum Kit',
      'brand_id': 1,
      'brand': <String, dynamic>{'id': 1, 'name': 'Canon'},
      'brand_model_id': 11,
      'brand_model': <String, dynamic>{'id': 11, 'name': 'iR ADV DX C3926'},
      'machine_id': 101,
      'machine': <String, dynamic>{'id': 101, 'name': 'HQ Printer A'},
      'part_category_id': 201,
      'part_category': <String, dynamic>{'id': 201, 'name': 'Drum Unit'},
      'user': <String, dynamic>{'id': 7, 'name': 'Aisyah'},
      'cost': 780.0,
      'created_at': '2026-04-02',
      'description':
          'Drum count is high and print quality shows repeated marks.',
      'remark': 'Need urgent approval before next PM cycle.',
      'status': 1,
      'status_id': 1,
    },
    <String, dynamic>{
      'id': 5002,
      'part_name': 'Upper Fuser Roller',
      'brand_id': 2,
      'brand': <String, dynamic>{'id': 2, 'name': 'Fuji Xerox'},
      'brand_model_id': 21,
      'brand_model': <String, dynamic>{'id': 21, 'name': 'Apeos C7070'},
      'machine_id': 102,
      'machine': <String, dynamic>{'id': 102, 'name': 'Branch Copier 02'},
      'part_category_id': 202,
      'part_category': <String, dynamic>{'id': 202, 'name': 'Fuser Assembly'},
      'user': <String, dynamic>{'id': 8, 'name': 'Farhan'},
      'cost': 1260.0,
      'created_at': '2026-04-01',
      'description':
          'Temperature inconsistency causing wrinkled output during long runs.',
      'remark': 'Approved for store processing after quote verification.',
      'status': 2,
      'status_id': 2,
    },
    <String, dynamic>{
      'id': 5003,
      'part_name': 'Pickup Roller Set',
      'brand_id': 3,
      'brand': <String, dynamic>{'id': 3, 'name': 'Ricoh'},
      'brand_model_id': 31,
      'brand_model': <String, dynamic>{'id': 31, 'name': 'IM C3000'},
      'machine_id': 103,
      'machine': <String, dynamic>{'id': 103, 'name': 'Warehouse Unit 4'},
      'part_category_id': 204,
      'part_category': <String, dynamic>{'id': 204, 'name': 'Paper Feed'},
      'user': <String, dynamic>{'id': 9, 'name': 'Nina'},
      'cost': 180.0,
      'created_at': '2026-03-29',
      'description':
          'Waiting for warehouse allocation before the technician can collect it.',
      'remark': 'Pending stock release from central store.',
      'status': 3,
      'status_id': 3,
    },
    <String, dynamic>{
      'id': 5004,
      'part_name': 'Magenta Toner Bottle',
      'brand_id': 1,
      'brand': <String, dynamic>{'id': 1, 'name': 'Canon'},
      'brand_model_id': 12,
      'brand_model': <String, dynamic>{'id': 12, 'name': 'imagePRESS C270'},
      'machine_id': 101,
      'machine': <String, dynamic>{'id': 101, 'name': 'HQ Printer A'},
      'part_category_id': 203,
      'part_category': <String, dynamic>{'id': 203, 'name': 'Toner Supply'},
      'user': <String, dynamic>{'id': 7, 'name': 'Aisyah'},
      'cost': 0.0,
      'created_at': '2026-03-28',
      'description':
          'Collected from store and prepared for the next preventive maintenance visit.',
      'remark': 'Technician collection logged at service counter.',
      'status': 4,
      'status_id': 4,
    },
    <String, dynamic>{
      'id': 5005,
      'part_name': 'Black Toner Cartridge',
      'brand_id': 2,
      'brand': <String, dynamic>{'id': 2, 'name': 'Fuji Xerox'},
      'brand_model_id': 21,
      'brand_model': <String, dynamic>{'id': 21, 'name': 'Apeos C7070'},
      'machine_id': 102,
      'machine': <String, dynamic>{'id': 102, 'name': 'Branch Copier 02'},
      'part_category_id': 203,
      'part_category': <String, dynamic>{'id': 203, 'name': 'Toner Supply'},
      'user': <String, dynamic>{'id': 8, 'name': 'Farhan'},
      'cost': 340.0,
      'created_at': '2026-03-27',
      'description':
          'Requested quantity does not match actual machine consumption history.',
      'remark': 'Returned to technician for revised justification.',
      'status': 5,
      'status_id': 5,
    },
    <String, dynamic>{
      'id': 5006,
      'part_name': 'Waste Toner Bottle',
      'brand_id': 3,
      'brand': <String, dynamic>{'id': 3, 'name': 'Ricoh'},
      'brand_model_id': 31,
      'brand_model': <String, dynamic>{'id': 31, 'name': 'IM C3000'},
      'machine_id': 103,
      'machine': <String, dynamic>{'id': 103, 'name': 'Warehouse Unit 4'},
      'part_category_id': 201,
      'part_category': <String, dynamic>{'id': 201, 'name': 'Drum Unit'},
      'user': <String, dynamic>{'id': 9, 'name': 'Nina'},
      'cost': 95.0,
      'created_at': '2026-03-26',
      'description':
          'Collected part was installed successfully during the scheduled visit.',
      'remark': 'Used on-site and job sheet updated.',
      'status': 6,
      'status_id': 6,
    },
    <String, dynamic>{
      'id': 5007,
      'part_name': 'Waste Toner Bottle',
      'brand_id': 3,
      'brand': <String, dynamic>{'id': 3, 'name': 'Ricoh'},
      'brand_model_id': 31,
      'brand_model': <String, dynamic>{'id': 31, 'name': 'IM C3000'},
      'machine_id': 103,
      'machine': <String, dynamic>{'id': 103, 'name': 'Warehouse Unit 4'},
      'part_category_id': 201,
      'part_category': <String, dynamic>{'id': 201, 'name': 'Drum Unit'},
      'user': <String, dynamic>{'id': 9, 'name': 'Nina'},
      'cost': 95.0,
      'created_at': '2026-03-25',
      'description':
          'Old consumable was removed after replacement and marked for disposal.',
      'remark': 'Disposed according to site handling procedure.',
      'status': 7,
      'status_id': 7,
    },
  ];
}
