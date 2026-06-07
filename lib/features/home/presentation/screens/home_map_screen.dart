import 'dart:convert';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:howmuch/features/store/store_model.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final String _viewId = 'kakao-map-container';
  bool _isMapInitialized = false;
  List<Store> _stores = [];
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebViewFactory();
      WidgetsBinding.instance.addPostFrameCallback((_) => _initWebMap());
    } else {
      _initMobileController();
      _loadStoresInBounds(37.5665, 37.5665, 126.9780, 126.9780); // 초기 예시
    }
  }

  void _registerWebViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = _viewId;
        div.style.width = '100%';
        div.style.height = '100%';
        return div;
      },
    );
  }

  void _initMobileController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('about:blank'));
  }

  void _initWebMap() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      try {
        // 서울 시청 중심 초기화
        js.context.callMethod('initKakaoMap', [_viewId, 37.5665, 126.9780]);
        setState(() { _isMapInitialized = true; });
        
        // 초기화 직후에는 데이터를 바로 부르지 않고 사용자가 원할 때 버튼을 누르도록 유도
      } catch (e) {
        debugPrint('지도 초기화 에러: $e');
      }
    });
  }

  // 💡 더 이상 사용하지 않는 전체 조회 로직 주석 처리 (비용 보호)
  /*
  Future<void> _loadAllStoresAndCluster() async { ... }
  */

  // 💡 현재 지도 화면 범위(Bounds)를 JS에서 가져와 해당 범위의 데이터만 서버에 요청합니다.
  Future<void> _searchInCurrentArea() async {
    if (!kIsWeb) {
      // 모바일은 추후 웹뷰 브릿지를 통해 구현
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모바일 환경은 준비 중입니다.')));
      return;
    }

    try {
      final String? boundsJson = js.context.callMethod('getKakaoMapBounds', [_viewId]);
      if (boundsJson == null) return;

      final Map<String, dynamic> bounds = json.decode(boundsJson);
      final double minLat = bounds['minLat'];
      final double maxLat = bounds['maxLat'];
      final double minLng = bounds['minLng'];
      final double maxLng = bounds['maxLng'];

      debugPrint('요청 범위: Lat($minLat ~ $maxLat), Lng($minLng ~ $maxLng)');

      final url = 'http://localhost:8081/api/test/bounds?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final stores = data.map((json) => Store.fromJson(json)).toList();

        final markerList = stores.where((s) => s.latitude != 0 && s.longitude != 0).map((s) => {
          'lat': s.latitude,
          'lng': s.longitude,
          'title': s.storeName,
        }).toList();

        debugPrint('현재 범위 내 검색된 업소: ${markerList.length}개');

        if (markerList.isNotEmpty) {
          js.context.callMethod('addKakaoMarkers', [_viewId, json.encode(markerList)]);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${markerList.length}개의 업소를 찾았습니다.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
        }
      }
    } catch (e) {
      debugPrint('범위 검색 에러: $e');
    }
  }

  // (참고용) 나중에 사용할 범위 기반 로드 로직
  Future<void> _loadStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) async {
    // 내부적으로 사용 (모바일 등)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주변 착한가격업소 지도'),
        backgroundColor: Colors.blueAccent,
      ),
      body: kIsWeb ? _buildWebMap() : _buildMobileMap(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _searchInCurrentArea,
        label: const Text('이 지역에서 재검색'),
        icon: const Icon(Icons.search),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWebMap() {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewId),
        if (!_isMapInitialized)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildMobileMap() {
    if (_webViewController == null) return const Center(child: Text('초기화 중...'));
    return WebViewWidget(controller: _webViewController!);
  }
}
