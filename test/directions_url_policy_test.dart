import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/store/presentation/state/directions_urls.dart';

void main() {
  for (final transport in DirectionsTransport.values) {
    test(
      'production Kakao builder preserves origin, destination and $transport',
      () {
        final urls = buildKakaoDirectionsUrls(
          destinationName: '가게 이름/테스트 &점',
          startName: '첫 번째 매장',
          transport: transport,
          startLatitude: 37.1,
          startLongitude: 127.1,
          destinationLatitude: 37.2,
          destinationLongitude: 127.2,
        );
        final mode = switch (transport) {
          DirectionsTransport.walk => 'walk',
          DirectionsTransport.transit => 'traffic',
          DirectionsTransport.car => 'car',
        };
        expect(urls.web.pathSegments.take(3), ['link', 'by', mode]);
        expect(urls.web.pathSegments[3], '첫 번째 매장,37.1,127.1');
        expect(urls.web.pathSegments[4], '가게 이름/테스트 &점,37.2,127.2');
        expect(urls.native.queryParameters['sp'], '37.1,127.1');
        expect(urls.native.queryParameters['ep'], '37.2,127.2');
      },
    );
    test(
      'production Naver builder preserves origin, destination and $transport',
      () {
        final urls = buildNaverDirectionsUrls(
          destinationName: '구백년짜장',
          startName: '이전 매장',
          transport: transport,
          startLatitude: 37.1,
          startLongitude: 127.1,
          destinationLatitude: 37.2,
          destinationLongitude: 127.2,
        );
        expect(urls.web.queryParameters['sname'], '이전 매장');
        expect(urls.web.queryParameters['sx'], '127.1');
        expect(urls.web.queryParameters['sy'], '37.1');
        expect(urls.web.queryParameters['ename'], '구백년짜장');
        expect(urls.web.queryParameters['ex'], '127.2');
        expect(urls.web.queryParameters['ey'], '37.2');
        expect(urls.web.queryParameters['pathType'], switch (transport) {
          DirectionsTransport.walk => '2',
          DirectionsTransport.transit => '1',
          DirectionsTransport.car => '0',
        });
      },
    );
  }
  test(
    'missing origin explicitly falls back without fabricating current position',
    () {
      final urls = buildKakaoDirectionsUrls(
        destinationName: '가게',
        transport: DirectionsTransport.walk,
        destinationLatitude: 37.2,
        destinationLongitude: 127.2,
      );
      expect(urls.web.pathSegments.take(2), ['link', 'to']);
      expect(urls.native.queryParameters.containsKey('sp'), isFalse);
    },
  );
  test(
    'invalid destination uses a name search without invalid coordinates',
    () {
      final urls = buildKakaoDirectionsUrls(
        destinationName: '가게',
        transport: DirectionsTransport.walk,
        destinationLatitude: double.nan,
        destinationLongitude: 127.2,
      );
      expect(urls.web.pathSegments.take(2), ['link', 'search']);
      expect(urls.web.toString(), isNot(contains('NaN')));
    },
  );
}
