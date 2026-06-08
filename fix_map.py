import re

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# Chunk 1: Imports
content = re.sub(
    r"import 'dart:math' as math;\n\nimport 'package:flutter/material.dart';",
    """import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'kakao_web_helper_stub.dart' if (dart.library.js) 'kakao_web_helper.dart' as web_helper;

import 'package:flutter/material.dart';""",
    content
)

# Chunk 2: state variables and methods
state_methods = """  final String _viewId = 'kakao-map-container';
  final String _kakaoJsKey = '949e657c37f55074dbb2a14ceb273e2b';
  bool _isMapInitialized = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      web_helper.registerKakaoWebViewFactory(_viewId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _initWebMap());
    } else {
      _initMobileController();
      _loadStoresInBounds(37.5665, 37.5665, 126.9780, 126.9780);
    }
  }

  void _initMobileController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'Print',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('WebView: ${message.message}');
          if (message.message.startsWith('BOUNDS:')) {
            _fetchAndAddMarkersForMobile(message.message.substring(7));
          }
        },
      )
      ..loadHtmlString(_getMobileMapHtml());
  }

  void _loadStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) {
      debugPrint('초기 로드 대기 중...');
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
      <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${_kakaoJsKey}&libraries=services,clusterer"></script>
    </head>
    <body>
      <div id="kakao-map-container"></div>
      <script>
        var map;
        var clusterer;

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

  void _initWebMap() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      try {
        web_helper.initKakaoWebMap(_viewId);
        setState(() { _isMapInitialized = true; });
      } catch (e) {
        debugPrint('지도 초기화 에러: ${e}');
      }
    });
  }

  Future<void> _searchInCurrentArea() async {
    if (kIsWeb) {
      try {
        final String? boundsJson = web_helper.getKakaoMapBoundsWeb(_viewId);
        if (boundsJson != null) _fetchAndAddMarkersWeb(boundsJson);
      } catch (e) {
        debugPrint('웹 범위 검색 에러: ${e}');
      }
    } else {
      _webViewController?.runJavaScript('requestBounds();');
    }
  }

  Future<void> _fetchAndAddMarkersForMobile(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);
    
    if (markerList.isNotEmpty && _webViewController != null) {
      final jsonString = json.encode(markerList).replaceAll("'", "\\\\'").replaceAll('"', '\\\\"');
      _webViewController!.runJavaScript('addMobileMarkers("' + jsonString + '");');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${markerList.length}개의 업소를 찾았습니다.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  Future<void> _fetchAndAddMarkersWeb(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);

    if (markerList.isNotEmpty) {
      web_helper.addKakaoMarkersWeb(_viewId, json.encode(markerList));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${markerList.length}개의 업소를 찾았습니다.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStoresFromBackend(Map<String, dynamic> bounds) async {
    final minLat = bounds['minLat'];
    final maxLat = bounds['maxLat'];
    final minLng = bounds['minLng'];
    final maxLng = bounds['maxLng'];

    String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final url = 'http://${host}:8081/api/test/bounds?minLat=${minLat}&maxLat=${maxLat}&minLng=${minLng}&maxLng=${maxLng}';

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
      debugPrint('백엔드 호출 에러: ${e}');
    }
    return [];
  }

  Widget _buildWebMap() {
    return Stack(
      children: [
        // ignore: undefined_prefixed_name
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

  @override
"""

content = re.sub(
    r"  @override\n  void didUpdateWidget\(covariant HomeMapScreen oldWidget\) \{",
    state_methods + "  void didUpdateWidget(covariant HomeMapScreen oldWidget) {",
    content
)

# Chunk 3: Replace dummy UI
content = re.sub(
    r"child: const _MapBackground\(\),",
    r"child: kIsWeb ? _buildWebMap() : _buildMobileMap(),",
    content
)

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)

