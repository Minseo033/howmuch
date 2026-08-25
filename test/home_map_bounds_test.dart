import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';

void main() {
  test('parses numeric Kakao bounds and normalizes integer values', () {
    expect(
      parseKakaoMapBounds(
        '{"minLat":37,"maxLat":38,"minLng":126,"maxLng":127}',
      ),
      {
        'minLat': 37.0,
        'maxLat': 38.0,
        'minLng': 126.0,
        'maxLng': 127.0,
      },
    );
  });

  test('rejects transient null, non-finite, out-of-range, and reversed bounds', () {
    expect(
      parseKakaoMapBounds(
        '{"minLat":null,"maxLat":38,"minLng":126,"maxLng":127}',
      ),
      isNull,
    );
    expect(
      parseKakaoMapBounds(
        '{"minLat":1e30,"maxLat":1e30,"minLng":126,"maxLng":127}',
      ),
      isNull,
    );
    expect(
      parseKakaoMapBounds(
        '{"minLat":38,"maxLat":37,"minLng":126,"maxLng":127}',
      ),
      isNull,
    );
  });
}
