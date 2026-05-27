import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/howmuch_app.dart';

void main() {
  testWidgets('shows the screen catalog', (tester) async {
    await tester.pumpWidget(const HowmuchApp());

    expect(find.text('얼마고? 화면 목록'), findsOneWidget);
    expect(find.text('전체 화면 58개'), findsOneWidget);
    expect(find.textContaining('2-1'), findsOneWidget);
  });
}
