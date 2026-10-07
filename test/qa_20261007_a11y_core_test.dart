import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';
import 'package:howmuch/features/search/presentation/screens/search_filter_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/choice_semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_reader.dart';

/// QA 2026-10-07 screen reader items in the shared widgets, search,
/// recommendation and store screens (#50, #52, #54).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.setSearchCatalog([
      _store('near', '다 시청 칼국수', '5,000', 37.5663, 126.9779),
    ]);
    HomeMapScreen.globalUserPosition = _position(37.5665, 126.9780);
  });

  tearDown(() {
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.globalUserPosition = null;
    ChoiceSemantics.debugIsWebOverride = null;
  });

  group('selection state (#52)', () {
    for (final web in [false, true]) {
      final platform = web ? 'web' : 'app';
      testWidgets(
        'the radius sheet reads which distance is picked ($platform)',
        (tester) async {
          ChoiceSemantics.debugIsWebOverride = web;
          final semantics = tester.ensureSemantics();
          await _openRadiusSheet(tester);

          expect(readerElements('3km 이내'), findsOne);
          expect(
            readerElements('3km 이내'),
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: web ? null : true,
              isChecked: web ? true : null,
              isInMutuallyExclusiveGroup: web ? true : null,
            ),
          );
          expect(
            readerElements('2km 이내'),
            isSemantics(
              isSelected: web ? null : false,
              isChecked: web ? false : null,
            ),
          );
          // The picked state lives on the option itself, not on an empty node
          // around it.
          expect(_pickedElements(web), findsOne);
          semantics.dispose();
        },
      );
    }

    testWidgets('the radius sheet stays in the app column on a wide window', (
      tester,
    ) async {
      _setViewport(tester, const Size(1424, 900));
      await _openRadiusSheet(tester);

      // The sheet's surface, inside the full-width BottomSheet alignment.
      final sheet = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheet.width, lessThanOrEqualTo(430));
      expect(sheet.center.dx, closeTo(712, .1));
    });

    for (final web in [false, true]) {
      final platform = web ? 'web' : 'app';
      testWidgets('filter chips and switches read their state ($platform)', (
        tester,
      ) async {
        ChoiceSemantics.debugIsWebOverride = web;
        final semantics = tester.ensureSemantics();
        await _openFilterSheet(
          tester,
          const SearchFilter(
            maxPrice: 5000,
            sortOrder: '저렴한순',
            govCertified: true,
            userReported: false,
          ),
        );

        for (final (chip, picked) in [
          ('전체', true),
          ('카페', false),
          ('5,000원 이하', true),
          ('10,000원 이하', false),
          ('저렴한순', true),
          ('가까운순', false),
        ]) {
          expect(readerElements(chip), findsOne, reason: chip);
          expect(
            readerElements(chip),
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: web ? null : picked,
              isChecked: web ? picked : null,
              // Chips can be turned off again, so they are not radios.
              isInMutuallyExclusiveGroup: false,
            ),
            reason: chip,
          );
        }
        for (final (name, on) in [
          ('정부 인증 업소만 보기', true),
          ('사용자 제보 매장 포함', false),
        ]) {
          expect(readerElements(name), findsOne, reason: name);
          expect(
            readerElements(name),
            isSemantics(
              hasToggledState: true,
              isToggled: on,
              hasTapAction: true,
            ),
            reason: name,
          );
        }
        semantics.dispose();
      });
    }

    testWidgets('a chip announces its new state after a tap', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openFilterSheet(tester, const SearchFilter());

      expect(readerElements('카페'), isSemantics(isSelected: false));
      tester.semantics.tap(readerElements('카페'));
      await tester.pumpAndSettle();
      expect(readerElements('카페'), isSemantics(isSelected: true));
      expect(readerElements('전체'), isSemantics(isSelected: false));

      tester.semantics.tap(readerElements('사용자 제보 매장 포함'));
      await tester.pumpAndSettle();
      expect(readerElements('사용자 제보 매장 포함'), isSemantics(isToggled: false));
      semantics.dispose();
    });

    for (final web in [false, true]) {
      final platform = web ? 'web' : 'app';
      testWidgets('directions read the picked travel mode once ($platform)', (
        tester,
      ) async {
        ChoiceSemantics.debugIsWebOverride = web;
        final semantics = tester.ensureSemantics();
        await _openDirections(tester);

        for (final (mode, picked) in [
          ('도보 이동 방식', true),
          ('대중교통 이동 방식', false),
          ('자동차 이동 방식', false),
        ]) {
          final element = readerElements(mode);
          expect(element, findsOne, reason: mode);
          expect(spokenName(element.evaluate().single), mode);
          expect(
            element,
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: web ? null : picked,
              isChecked: web ? picked : null,
              isInMutuallyExclusiveGroup: web ? true : null,
            ),
            reason: mode,
          );
        }

        tester.semantics.tap(readerElements('대중교통 이동 방식'));
        await tester.pumpAndSettle();
        expect(
          readerElements('대중교통 이동 방식'),
          isSemantics(
            isSelected: web ? null : true,
            isChecked: web ? true : null,
          ),
        );
        semantics.dispose();
      });
    }
  });

  group('names and roles (#50, #51)', () {
    testWidgets('the filter sheet close button has a name and closes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openFilterSheet(tester, const SearchFilter());

      final close = readerElements('검색 필터 닫기');
      expect(close, findsOne);
      expect(close, isSemantics(isButton: true, hasTapAction: true));
      tester.semantics.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSheet), findsNothing);
      semantics.dispose();
    });

    testWidgets('directions read the back and map buttons once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openDirections(tester);

      expect(readerElements('뒤로가기'), findsOne);
      for (final app in ['네이버지도에서 열기', '카카오맵에서 열기']) {
        final element = readerElements(app);
        expect(element, findsOne, reason: app);
        expect(spokenName(element.evaluate().single), app);
        expect(element, isSemantics(isButton: true, hasTapAction: true));
      }
      semantics.dispose();
    });
  });
}

/// Elements that say they are picked: selected in the app, checked on the
/// web.
SemanticsFinder _pickedElements(bool web) => find.semantics.byPredicate((node) {
  if (node.isMergedIntoParent) return false;
  final flags = node.getSemanticsData().flagsCollection;
  return web
      ? flags.isChecked == CheckedState.isTrue
      : flags.isSelected == Tristate.isTrue;
});

Future<void> _openRadiusSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Center(child: RecommendationRadiusButton())),
      ),
    ),
  );
  await tester.tap(find.byType(RecommendationRadiusButton));
  await tester.pumpAndSettle();
}

Future<void> _openFilterSheet(WidgetTester tester, SearchFilter current) async {
  _setViewport(tester, const Size(430, 1400));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<SearchFilter>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SearchFilterSheet(current: current),
              ),
              child: const Text('필터 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('필터 열기'));
  await tester.pumpAndSettle();
}

Future<void> _openDirections(WidgetTester tester) async {
  _setViewport(tester, const Size(390, 1200));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DirectionsExternalAppScreen(
                    storeName: '미락칼국수',
                    address: '서울특별시 중구 세종대로 110',
                    latitude: 37.5663,
                    longitude: 126.9779,
                    startLatitude: 37.5665,
                    startLongitude: 126.978,
                  ),
                ),
              ),
              child: const Text('길찾기 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('길찾기 열기'));
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Store _store(
  String id,
  String name,
  String price,
  double latitude,
  double longitude,
) => Store.fromJson({
  'storeId': id,
  'storeName': name,
  'industry': '한식',
  'menu1': '칼국수',
  'price1': price,
  'latitude': latitude,
  'longitude': longitude,
  'source': 'GOV',
});

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
