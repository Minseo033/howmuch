import 'package:geolocator/geolocator.dart';

bool get isAppleMobileBrowser => false;

Future<Position> requestBrowserLocation() =>
    throw UnsupportedError('Browser location is only available on the web.');
