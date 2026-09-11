import 'dart:async';
import 'dart:js_interop';

import 'package:geolocator/geolocator.dart';
import 'package:web/web.dart' as web;

Future<Position>? _pendingRequest;

// iPad Safari can identify itself as a Mac in desktop website mode.
bool get isAppleMobileBrowser {
  final navigator = web.window.navigator;
  return RegExp(r'iPad|iPhone|iPod').hasMatch(navigator.userAgent) ||
      (navigator.userAgent.contains('Macintosh') &&
          navigator.maxTouchPoints > 1);
}

/// Start the browser request synchronously in the user's tap handler. Do not
/// await a Permissions API query first: Safari may not support it, and a prior
/// query result must not prevent an explicit request after settings change.
Future<Position> requestBrowserLocation() {
  if (_pendingRequest != null) return _pendingRequest!;

  final completer = Completer<Position>();
  final request = completer.future.whenComplete(() => _pendingRequest = null);
  _pendingRequest = request;
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      (web.GeolocationPosition value) {
        final coords = value.coords;
        completer.complete(
          Position(
            latitude: coords.latitude.toDouble(),
            longitude: coords.longitude.toDouble(),
            timestamp: DateTime.fromMillisecondsSinceEpoch(value.timestamp),
            accuracy: coords.accuracy.toDouble(),
            altitude: coords.altitude?.toDouble() ?? 0,
            altitudeAccuracy: coords.altitudeAccuracy?.toDouble() ?? 0,
            heading: coords.heading?.toDouble() ?? 0,
            headingAccuracy: 0,
            speed: coords.speed?.toDouble() ?? 0,
            speedAccuracy: 0,
          ),
        );
      }.toJS,
      (web.GeolocationPositionError error) {
        // Only PERMISSION_DENIED means access was refused. Wi-Fi/GPS failures
        // and timeouts must not be reported as permanently denied permission.
        completer.completeError(switch (error.code) {
          1 => PermissionDeniedException(error.message),
          3 => TimeoutException(error.message),
          _ => PositionUpdateException(error.message),
        });
      }.toJS,
      // Browser timeouts are milliseconds and exclude time spent answering the
      // permission prompt. A Dart Future.timeout would cut that prompt short.
      web.PositionOptions(
        enableHighAccuracy: true,
        maximumAge: const Duration(minutes: 2).inMilliseconds,
        timeout: const Duration(seconds: 15).inMilliseconds,
      ),
    );
  } catch (error, stack) {
    completer.completeError(error, stack);
  }
  return request;
}
