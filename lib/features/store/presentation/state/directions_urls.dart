enum DirectionsTransport { walk, transit, car }

class DirectionsUrls {
  const DirectionsUrls({required this.native, required this.web});
  final Uri native;
  final Uri web;
}

DirectionsUrls buildKakaoDirectionsUrls({
  required String destinationName,
  required DirectionsTransport transport,
  String startName = '현재 위치',
  double? startLatitude,
  double? startLongitude,
  double? destinationLatitude,
  double? destinationLongitude,
}) {
  final destination = _valid(destinationLatitude, destinationLongitude);
  final start = _valid(startLatitude, startLongitude);
  final mode = switch (transport) {
    DirectionsTransport.walk => 'FOOT',
    DirectionsTransport.transit => 'PUBLIC',
    DirectionsTransport.car => 'CAR',
  };
  final webMode = switch (transport) {
    DirectionsTransport.walk => 'walk',
    DirectionsTransport.transit => 'traffic',
    DirectionsTransport.car => 'car',
  };
  final name = Uri.encodeComponent(destinationName);
  if (!destination) {
    return DirectionsUrls(
      native: Uri.parse('kakaomap://search?q=$name'),
      web: Uri.parse('https://map.kakao.com/link/search/$name'),
    );
  }
  final native = Uri.parse(
    'kakaomap://route?${start ? 'sp=$startLatitude,$startLongitude&' : ''}ep=$destinationLatitude,$destinationLongitude&by=$mode',
  );
  final web = start
      ? Uri.parse(
          'https://map.kakao.com/link/by/$webMode/${Uri.encodeComponent(startName)},$startLatitude,$startLongitude/$name,$destinationLatitude,$destinationLongitude',
        )
      : Uri.parse(
          'https://map.kakao.com/link/to/$name,$destinationLatitude,$destinationLongitude',
        );
  return DirectionsUrls(native: native, web: web);
}

DirectionsUrls buildNaverDirectionsUrls({
  required String destinationName,
  required DirectionsTransport transport,
  String startName = '현재 위치',
  double? startLatitude,
  double? startLongitude,
  double? destinationLatitude,
  double? destinationLongitude,
}) {
  final destination = _valid(destinationLatitude, destinationLongitude);
  final start = _valid(startLatitude, startLongitude);
  final mode = switch (transport) {
    DirectionsTransport.walk => 'walk',
    DirectionsTransport.transit => 'public',
    DirectionsTransport.car => 'car',
  };
  final pathType = switch (transport) {
    DirectionsTransport.walk => '3',
    DirectionsTransport.transit => '1',
    DirectionsTransport.car => '0',
  };
  if (!destination) {
    return DirectionsUrls(
      native: Uri(
        scheme: 'nmap',
        host: 'search',
        queryParameters: {
          'query': destinationName,
          'appname': 'com.howmuch.app',
        },
      ),
      web: Uri.https('m.map.naver.com', '/search2/search.naver', {
        'query': destinationName,
      }),
    );
  }
  return DirectionsUrls(
    native: Uri.parse('nmap://route/$mode').replace(
      queryParameters: {
        if (start) ...{
          'slat': '$startLatitude',
          'slng': '$startLongitude',
          'sname': startName,
        },
        'dlat': '$destinationLatitude',
        'dlng': '$destinationLongitude',
        'dname': destinationName,
        'appname': 'com.howmuch.app',
      },
    ),
    web: Uri.https('m.map.naver.com', '/route.nhn', {
      'menu': 'route',
      'pathType': pathType,
      if (start) ...{
        'sx': '$startLongitude',
        'sy': '$startLatitude',
        'sname': startName,
      },
      'ex': '$destinationLongitude',
      'ey': '$destinationLatitude',
      'ename': destinationName,
    }),
  );
}

bool _valid(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    !(latitude == 0 && longitude == 0);
