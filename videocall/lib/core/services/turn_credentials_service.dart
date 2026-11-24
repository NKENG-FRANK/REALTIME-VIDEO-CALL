import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class TurnCredentialsService {
  static Future<Map<String, dynamic>?> fetch({
    required String token,
    http.Client? client,
    Uri? endpoint,
  }) async {
    final requestClient = client ?? http.Client();
    try {
      final videoUri = Uri.parse(ApiConfig.videoCallsBaseUrl);
      final uri =
          endpoint ??
          videoUri.replace(
            scheme: videoUri.scheme == 'wss' ? 'https' : 'http',
            path: '/api/v1/video/turn-credentials',
          );
      final response = await requestClient
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final urls = data['urls'];
      final username = data['username'];
      final credential = data['credential'];
      final expiresAt = data['expiresAt'];
      if (urls is! List ||
          urls.isEmpty ||
          !urls.every(
            (url) =>
                url is String &&
                (url.startsWith('turn:') || url.startsWith('turns:')),
          ) ||
          username is! String ||
          username.isEmpty ||
          credential is! String ||
          credential.isEmpty ||
          expiresAt is! int ||
          expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        return null;
      }
      return {
        'urls': urls.cast<String>(),
        'username': username,
        'credential': credential,
      };
    } catch (_) {
      return null;
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
