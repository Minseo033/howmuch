import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/backend_warmup_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('상태 확인 요청이 성공하면 서비스 준비 완료로 판단한다', () async {
    final service = BackendWarmupService(
      client: MockClient((request) async => http.Response('{}', 200)),
    );
    addTearDown(service.close);

    expect(await service.ensureReady(), isTrue);
  });

  test('상태 확인 요청이 실패하면 준비되지 않은 상태로 판단한다', () async {
    final service = BackendWarmupService(
      client: MockClient((request) async => http.Response('{}', 503)),
    );
    addTearDown(service.close);

    expect(await service.ensureReady(), isFalse);
  });
}
