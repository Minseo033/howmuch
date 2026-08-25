import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/utils/latest_request_tracker.dart';

void main() {
  test('가장 최근 요청만 현재 요청으로 인정한다', () {
    final tracker = LatestRequestTracker();
    final first = tracker.next();
    final second = tracker.next();

    expect(tracker.isCurrent(first), isFalse);
    expect(tracker.isCurrent(second), isTrue);
  });

  test('화면 종료 시 진행 중인 요청을 모두 무효화한다', () {
    final tracker = LatestRequestTracker();
    final request = tracker.next();

    tracker.invalidate();

    expect(tracker.isCurrent(request), isFalse);
  });
}
