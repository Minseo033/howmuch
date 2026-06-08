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
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'Print', // 디버깅 및 좌표 전달용 채널
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('WebView: ${message.message}');
          if (message.message.startsWith('BOUNDS:')) {
            _fetchAndAddMarkersForMobile(message.message.substring(7));
          }
        },
      )
      ..loadHtmlString(_getMobileMapHtml());
  }

  String _getMobileMapHtml() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
        #kakao-map-container { width: 100%; height: 100%; }
      </style>
      <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$_kakaoJsKey&libraries=services,clusterer"></script>
    </head>
    <body>
      <div id="kakao-map-container"></div>
      <script>
        var map;
        var clusterer;

        // 지도가 로드되면 초기화
        window.onload = function() {
          var container = document.getElementById('kakao-map-container');
          var options = { center: new kakao.maps.LatLng(37.5665, 126.9780), level: 3 };
          map = new kakao.maps.Map(container, options);
          
          clusterer = new kakao.maps.MarkerClusterer({
            map: map,
            averageCenter: true,
            minLevel: 6
          });
          Print.postMessage("Map Initialized on Mobile");
        };

        // Flutter에서 호출할 함수 (마커 추가)
        function addMobileMarkers(markerListJson) {
          var markerData = JSON.parse(markerListJson);
          var markers = markerData.map(function(item) {
            return new kakao.maps.Marker({
              position: new kakao.maps.LatLng(item.lat, item.lng),
              title: item.title
            });
          });
          clusterer.clear();
          clusterer.addMarkers(markers);
          Print.postMessage("Markers added: " + markerData.length);
        }

        // 범위 요청 시 Flutter로 범위 데이터 전송
        function requestBounds() {
          if(!map) return;
          var bounds = map.getBounds();
          var sw = bounds.getSouthWest();
          var ne = bounds.getNorthEast();
          var boundsData = JSON.stringify({
            minLat: sw.getLat(), maxLat: ne.getLat(),
            minLng: sw.getLng(), maxLng: ne.getLng()
          });
          Print.postMessage('BOUNDS:' + boundsData);
        }
      </script>
    </body>
    </html>
    ''';
  }

  // 💡 웹 전용 _initWebMap 유지
  void _initWebMap() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      try {
        js.context.callMethod('initKakaoMap', [_viewId, 37.5665, 126.9780]);
        setState(() { _isMapInitialized = true; });
      } catch (e) {
        debugPrint('지도 초기화 에러: $e');
      }
    });
  }

  // 💡 모바일/웹 공통 통합 검색 호출 버튼 트리거
  Future<void> _searchInCurrentArea() async {
    if (kIsWeb) {
      try {
        final String? boundsJson = js.context.callMethod('getKakaoMapBounds', [_viewId]);
        if (boundsJson != null) _fetchAndAddMarkersWeb(boundsJson);
      } catch (e) {
        debugPrint('웹 범위 검색 에러: $e');
      }
    } else {
      // 모바일: WebView 내의 requestBounds() 함수 호출 -> Print 채널을 통해 결과 회신
      _webViewController?.runJavaScript('requestBounds();');
    }
  }

  // 모바일: 전달받은 범위를 바탕으로 백엔드 호출 및 마커 생성
  Future<void> _fetchAndAddMarkersForMobile(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);
    
    if (markerList.isNotEmpty && _webViewController != null) {
      final jsonString = json.encode(markerList).replaceAll("'", "\\'").replaceAll('"', '\\"');
      _webViewController!.runJavaScript('addMobileMarkers("$jsonString");');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${markerList.length}개의 업소를 찾았습니다.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  // 웹: 전달받은 범위를 바탕으로 백엔드 호출 및 마커 생성
  Future<void> _fetchAndAddMarkersWeb(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);

    if (markerList.isNotEmpty) {
      js.context.callMethod('addKakaoMarkers', [_viewId, json.encode(markerList)]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${markerList.length}개의 업소를 찾았습니다.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  // 공통: 백엔드 API 통신
  Future<List<Map<String, dynamic>>> _fetchStoresFromBackend(Map<String, dynamic> bounds) async {
    final minLat = bounds['minLat'];
    final maxLat = bounds['maxLat'];
    final minLng = bounds['minLng'];
    final maxLng = bounds['maxLng'];

    // 💡 안드로이드 에뮬레이터에서는 localhost 대신 10.0.2.2 사용
    String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final url = 'http://$host:8081/api/test/bounds?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final stores = data.map((json) => Store.fromJson(json)).toList();
        return stores.where((s) => s.latitude != 0 && s.longitude != 0).map((s) => {
          'lat': s.latitude,
          'lng': s.longitude,
          'title': s.storeName,
        }).toList();
      }
    } catch (e) {
      debugPrint('백엔드 호출 에러: $e');
    }
    return [];
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
