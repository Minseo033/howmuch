import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/home_map_viewport_policy.dart';

void main() {
  test('initial centering happens once and only without a destination', () {
    final policy = HomeMapViewportPolicy();
    expect(policy.claimInitialCenter(hasDestination: true), isNull);
    expect(policy.claimInitialCenter(hasDestination: false), isNull);
    final normal = HomeMapViewportPolicy();
    expect(normal.claimInitialCenter(hasDestination: false), 0);
    expect(normal.claimInitialCenter(hasDestination: false), isNull);
  });
  test('delayed GPS cannot override a marker, swipe, search or drag', () {
    final policy = HomeMapViewportPolicy();
    final pending = policy.claimInitialCenter(hasDestination: false)!;
    policy.invalidate();
    expect(policy.canApply(pending), isFalse);
    final explicit = policy.beginExplicitCenter();
    expect(policy.canApply(explicit), isTrue);
    policy.invalidate();
    expect(policy.canApply(explicit), isFalse);
  });
}
