import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Directions external URL policy', () {
    test('encodes store name cleanly without address concatenation for map search', () {
      const storeName = '구백년짜장';
      final query = Uri.encodeComponent(storeName);
      expect(Uri.decodeComponent(query), '구백년짜장');
      expect(query, isNot(contains('경기도')));
    });

    test('formats Naver Map mobile route URL with coordinates', () {
      const storeName = '구백년짜장';
      const lat = 36.987;
      const lng = 126.921;
      final encoded = Uri.encodeComponent(storeName);
      final url = Uri.parse(
        'https://m.map.naver.com/route.nhn?menu=route&ename=$encoded&ex=$lng&ey=$lat&pathType=1',
      );

      expect(url.queryParameters['menu'], 'route');
      expect(url.queryParameters['ename'], storeName);
      expect(url.queryParameters['ex'], '126.921');
      expect(url.queryParameters['ey'], '36.987');
    });

    test('formats Kakao Map mobile link-to route URL with coordinates', () {
      const storeName = '구백년짜장';
      const lat = 36.987;
      const lng = 126.921;
      final encoded = Uri.encodeComponent(storeName);
      final url = Uri.parse(
        'https://map.kakao.com/link/to/$encoded,$lat,$lng',
      );

      expect(Uri.decodeComponent(url.path), '/link/to/$storeName,$lat,$lng');
    });
  });
}
