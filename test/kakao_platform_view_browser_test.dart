@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/kakao_web_helper.dart';
import 'package:web/web.dart' as web;

/// Exercises the production factory and real DOM elements, with Flutter's
/// platform channel simulated as in its own HtmlElementView widget tests.
/// This is not an end-to-end Kakao SDK/gesture check; that requires actual UI QA.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final registry = _WidgetPlatformRegistry();
    ui_web.debugOverridePlatformViewRegistry(registry);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          registry.handle,
        );
  });
  tearDownAll(() {
    ui_web.debugOverridePlatformViewRegistry(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
  setUp(() {
    globalContext.setProperty('kakaoMapCallbacks'.toJS, JSObject());
  });

  testWidgets(
    'production factory retains DOM across widget rebuilds and resize',
    (tester) async {
      registerKakaoWebViewFactory('browser-map-a');
      // Registering another map must keep the same parameterized factory, not
      // a closure holding the first screen's DOM ID.
      registerKakaoWebViewFactory('browser-map-b');
      final first = HtmlElementView(
        key: const ValueKey('browser-map-a'),
        viewType: kakaoWebViewType,
        creationParams: 'browser-map-a',
      );
      final second = HtmlElementView(
        key: const ValueKey('browser-map-b'),
        viewType: kakaoWebViewType,
        creationParams: 'browser-map-b',
      );
      var iteration = 0;
      Widget shell() => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('선택 $iteration'),
              SizedBox(width: 300 + iteration % 20, height: 180, child: first),
              SizedBox(width: 300, height: 180, child: second),
            ],
          ),
        ),
      );
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      final a = globalContext.getProperty<web.HTMLDivElement>(
        'browser-map-a'.toJS,
      );
      final b = globalContext.getProperty<web.HTMLDivElement>(
        'browser-map-b'.toJS,
      );
      expect(a.id, 'browser-map-a');
      expect(b.id, 'browser-map-b');
      expect(a.isSameNode(b), isFalse);
      for (iteration = 1; iteration <= 100; iteration++) {
        await tester.pumpWidget(shell());
        await tester.pump();
        final current = globalContext.getProperty<web.HTMLDivElement>(
          'browser-map-a'.toJS,
        );
        expect(
          current.isSameNode(a),
          isTrue,
          reason: 'selection/resize must not replace platform DOM',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      globalContext.delete('browser-map-a'.toJS);
      globalContext.delete('browser-map-b'.toJS);
    },
  );

  test(
    'callbacks stay attached to their own view and preserve stable store IDs',
    () {
      final selected = <String>[];
      registerWebCallbacks(
        'browser-callback-a',
        () {},
        () {},
        (_, id) => selected.add('a:$id'),
        () {},
        (_) {},
      );
      registerWebCallbacks(
        'browser-callback-b',
        () {},
        () {},
        (_, id) => selected.add('b:$id'),
        () {},
        (_) {},
      );
      final registry = globalContext.getProperty<JSObject>(
        'kakaoMapCallbacks'.toJS,
      );
      for (final (id, index, store) in [
        ('browser-callback-a', 1, 'exact-a'),
        ('browser-callback-b', 2, 'exact-b'),
      ]) {
        registry
            .getProperty<JSObject>(id.toJS)
            .getProperty<JSFunction>('onMarkerClick'.toJS)
            .callAsFunction(null, index.toJS, store.toJS);
      }
      expect(selected, ['a:exact-a', 'b:exact-b']);
    },
  );
}

class _WidgetPlatformRegistry implements ui_web.PlatformViewRegistry {
  final factories = <String, Function>{};
  final views = <int, Object>{};

  @override
  bool registerViewFactory(
    String type,
    Function factory, {
    bool isVisible = true,
  }) {
    if (factories.containsKey(type)) return false;
    factories[type] = factory;
    return true;
  }

  @override
  Object getViewById(int id) => views[id]!;

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'create') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final id = args['id'] as int;
      if (views.containsKey(id)) throw StateError('Duplicate platform view');
      final factory =
          factories[args['viewType']]
              as ui_web.ParameterizedPlatformViewFactory;
      views[id] = factory(id, params: args['params']);
    } else if (call.method == 'dispose') {
      views.remove(call.arguments as int);
    }
    return null;
  }
}
