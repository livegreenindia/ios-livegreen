import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for the backend API (change to your deployed functions URL)
  // Example: https://us-central1-yourproject.cloudfunctions.net/api
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }
  
  // Small helper to build headers and optionally log the Authorization header
  Map<String, String> _buildHeaders({bool jsonContent = false, String? token, String method = '', String url = ''}) {
    final headers = <String, String>{};
    if (jsonContent) headers['Content-Type'] = 'application/json';
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      // Lightweight debug: print presence and truncated token for developer troubleshooting
      assert(() {
        final t = token;
        final preview = t.length > 16 ? '${t.substring(0, 8)}...${t.substring(t.length - 8)}' : t;
        debugPrint('[ApiService] $method $url Authorization present (token preview: $preview)');
        return true;
      }());
    }
    return headers;
  }

  Future<List<Map<String, dynamic>>> getProgressSeries(String range) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/summary/series?range=$range');
    final resp = await http.get(
      uri,
      headers: _buildHeaders(jsonContent: false, token: token, method: 'GET', url: uri.toString()),
    );
    if (resp.statusCode == 200) {
      final parsed = json.decode(resp.body);
      if (parsed is Map && parsed['series'] is List) {
        return List<Map<String, dynamic>>.from(
          parsed['series'].map((e) => Map<String, dynamic>.from(e)),
        );
      }
      throw Exception('Unexpected progress series payload');
    }
    throw Exception(
      'Failed to load progress series (${resp.statusCode}): ${resp.body}',
    );
  }

  Future<List<dynamic>> getActivities() async {
    final token = await _getIdToken();
    // include localDate so server can return per-activity completed flags for the correct local day
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$baseUrl/activities?date=$localDate');
    final resp = await http.get(
      uri,
      headers: _buildHeaders(jsonContent: false, token: token, method: 'GET', url: uri.toString()),
    );
    if (resp.statusCode == 200) {
      try {
        final parsed = json.decode(resp.body);
        // backend may return either an array or an object { activities: [...] }
        List<dynamic> rawList;
        if (parsed is List) {
          rawList = parsed;
        } else if (parsed is Map && parsed['activities'] is List) {
          rawList = parsed['activities'] as List<dynamic>;
        } else {
          throw Exception('Unexpected activities payload');
        }

        // normalize each activity into a simple map with id, title, subtitle, icon, weight
        return rawList.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          // backend uses 'name' for display name
          final title = map['title'] ?? map['name'] ?? map['id'];
          return {
            'id': map['id'] ?? map['activityId'] ?? title,
            'title': title,
            'subtitle': map['subtitle'] ?? map['description'] ?? '',
            'icon': map['icon'],
            'weight': map['weight'] ?? 1,
            ...map,
          };
        }).toList();
      } catch (e) {
        throw Exception('Failed to parse activities: $e');
      }
    }

    throw Exception(
      'Failed to load activities (${resp.statusCode}): ${resp.body}',
    );
  }

  Future<void> completeActivity(
    String activityId,
    Map<String, dynamic> payload,
  ) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/activities/$activityId/complete');
    // ensure localDate is present so server groups this completion into the correct local day
    if (!payload.containsKey('localDate')) {
      final now = DateTime.now();
      payload['localDate'] =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: true, token: token, method: 'POST', url: uri.toString()),
      body: json.encode(payload),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Failed to mark complete (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  Future<void> postHappiness(int score, {String? date}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/happiness');
    final body = {'score': score, if (date != null) 'date': date};
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: true, token: token, method: 'POST', url: uri.toString()),
      body: json.encode(body),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to post happiness (${resp.statusCode})');
    }
  }

  // Forum
  Future<List<dynamic>> getPosts() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/forum');
    final resp = await http.get(
      uri,
      headers: _buildHeaders(jsonContent: false, token: token, method: 'GET', url: uri.toString()),
    );
    if (resp.statusCode == 200) {
      final parsed = json.decode(resp.body);
      return parsed['posts'] as List<dynamic>;
    }
    throw Exception('Failed to load posts (${resp.statusCode}): ${resp.body}');
  }

  Future<void> createPost(String text, {String? imageUrl}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/forum');
    final body = {'text': text, if (imageUrl != null) 'imageUrl': imageUrl};
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: true, token: token, method: 'POST', url: uri.toString()),
      body: json.encode(body),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201)
      throw Exception('Failed to create post (${resp.statusCode})');
  }

  Future<void> likePost(String postId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/forum/$postId/like');
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: false, token: token, method: 'POST', url: uri.toString()),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201)
      throw Exception('Failed to like post (${resp.statusCode})');
  }

  Future<void> postComment(String postId, String text) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/forum/$postId/comments');
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: true, token: token, method: 'POST', url: uri.toString()),
      body: json.encode({'text': text}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201)
      throw Exception('Failed to post comment (${resp.statusCode})');
  }

  Future<String> uploadImage(String filename, String base64Data) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/forum/upload');
    final resp = await http.post(
      uri,
      headers: _buildHeaders(jsonContent: true, token: token, method: 'POST', url: uri.toString()),
      body: json.encode({'filename': filename, 'data': base64Data}),
    );
    if (resp.statusCode == 200) {
      final parsed = json.decode(resp.body) as Map<String, dynamic>;
      return parsed['url'] as String;
    }
    throw Exception(
      'Failed to upload image (${resp.statusCode}): ${resp.body}',
    );
  }

  // Profile
  Future<Map<String, dynamic>> getProfile() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/profile');
    final resp = await http.get(
      uri,
      headers: _buildHeaders(jsonContent: false, token: token, method: 'GET', url: uri.toString()),
    );
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load profile (${resp.statusCode})');
  }

  // ---- Razorpay Payment APIs ---- //

  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/payments/create');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({'amount': amount}),
    );

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      // Normalize expected keys for frontend compatibility
      return {
        'orderId': data['orderId'] ?? data['id'],
        'key': data['key'], // backend should include key or use config fallback
      };
    }
    // If backend returned HTML (for example a hosting/static error page),
    // present a short, helpful message instead of raw HTML.
    final contentType = resp.headers['content-type'] ?? '';
    String bodyPreview = resp.body;
    if (contentType.contains('text/html')) {
      // strip HTML tags for preview and limit length
      bodyPreview = RegExp(r'<[^>]*>').allMatches(resp.body).isEmpty
          ? resp.body
          : resp.body.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    }
    final msg = 'Failed to create Razorpay order (${resp.statusCode}) at ${uri.toString()}: ${bodyPreview.length > 400 ? bodyPreview.substring(0, 400) + "..." : bodyPreview}';
    throw Exception(msg);
  }

  Future<void> verifyRazorpayPayment(
    String orderId,
    String paymentId,
    String signature,
  ) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/payments/verify');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      }),
    );

    if (resp.statusCode != 200) {
      final contentType = resp.headers['content-type'] ?? '';
      String bodyPreview = resp.body;
      if (contentType.contains('text/html')) {
        bodyPreview = RegExp(r'<[^>]*>').allMatches(resp.body).isEmpty
            ? resp.body
            : resp.body.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
      }
      throw Exception('Payment verification failed (${resp.statusCode}) at ${uri.toString()}: ${bodyPreview.length > 400 ? bodyPreview.substring(0, 400) + "..." : bodyPreview}');
    }
  }
}
