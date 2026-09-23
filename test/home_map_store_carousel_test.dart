import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';

void main() {
  testWidgets('horizontal swipe on the store card advances the carousel', (
    tester,
  ) async {
    final controller = PageController(viewportFraction: 0.88);
    addTearDown(controller.dispose);
    var selectedPage = -1;
    var detailTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 180,
              child: HomeMapStoreCarousel(
                controller: controller,
                itemCount: 3,
                onPageChanged: (index) => selectedPage = index,
                itemBuilder: (context, index) => Card(
                  key: ValueKey('store-$index'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('매장 $index'),
                      GestureDetector(
                        key: ValueKey('detail-button-$index'),
                        onTap: () => detailTapCount++,
                        child: Container(
                          width: double.infinity,
                          height: 40,
                          alignment: Alignment.center,
                          color: Colors.blue,
                          child: const Text('상세보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('detail-button-0')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(selectedPage, 1);
    expect(find.text('매장 1'), findsOneWidget);
    expect(detailTapCount, 0);
    expect(tester.takeException(), isNull);
  });
}
