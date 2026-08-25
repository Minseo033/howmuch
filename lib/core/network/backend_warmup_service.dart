import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;

final backendWarmupServiceProvider = Provider<BackendWarmupService>((ref) {
  final service = BackendWarmupService();
  ref.onDispose(service.close);
  return service;
});

class BackendWarmupService {
  BackendWarmupService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  Future<bool>? _inFlight;

  Future<bool> ensureReady({Duration timeout = const Duration(seconds: 70)}) {
    final activeRequest = _inFlight;
    if (activeRequest != null) return activeRequest;

    final request = _runProbe(timeout);
    _inFlight = request;
    return request;
  }

  Future<bool> _runProbe(Duration timeout) async {
    try {
      final response = await _client
          .get(
            ApiClient.uri('/healthz'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      _inFlight = null;
    }
  }

  void close() => _client.close();
}
