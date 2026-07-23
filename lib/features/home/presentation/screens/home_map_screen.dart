import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'kakao_web_helper_stub.dart'
    if (dart.library.js) 'kakao_web_helper.dart'
    as web_helper;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:howmuch/core/constants/app_sizes.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key, this.showAiSpotlight = false});

  static List<Store> globalAllStores = [];
  static Position? globalUserPosition;

  final bool showAiSpotlight;

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const fontFamily = 'Inter';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with WidgetsBindingObserver {
  bool _showStoreSummary = false;
  late bool _showAiSpotlight = widget.showAiSpotlight;

  final String _viewId = 'kakao-map-container';
  final String _kakaoJsKey = '949e657c37f55074dbb2a14ceb273e2b';
  bool _isMapInitialized = false;
  WebViewController? _webViewController;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Position? _lastKnownPosition;
  List<Store> _allStores = [];
  bool _isAllStoresLoaded = false;
  bool _hasLoadError = false;
  List<Store> _currentStores = [];
  Store? _selectedStore;
  bool _isFetching = false;
  final PageController _pageController = PageController(viewportFraction: 0.88);

  String _searchQuery = '';
  SearchFilter _searchFilter = const SearchFilter();

  // ── 필터 UI 업종 → 실제 DB industry 키워드 매핑 ──
  static const _industryKeywords = <String, List<String>>{
    '음식점': [
      '한식',
      '중식',
      '일식',
      '양식',
      '분식',
      '패스트푸드',
      '음식',
      '식당',
      '반찬',
      '도시락',
      '국수',
      '치킨',
      '피자',
      '족발',
      '감자탕',
      '삼겹살',
      '고깃집',
      '정육',
      '떡볶이',
      '김밥',
    ],
    '카페': [
      '카페',
      '커피',
      '음료',
      '베이커리',
      '빵',
      '제과',
      '디저트',
      '차(음료)',
      '주스',
      '스무디',
      '아이스크림',
    ],
    '미용': ['미용', '헤어', '네일', '피부', '뷰티', '화장', '미용실', '이발'],
    '세탁': ['세탁', '빨래', '클리닝', '드라이'],
    '생활서비스': [
      '수선',
      '열쇠',
      '인쇄',
      '복사',
      '사진',
      '촬영',
      '스튜디오',
      '생활',
      '서비스',
      '수리',
      '기타',
    ],
  };

  bool _matchesIndustryFilter(Store store, String filterIndustry) {
    if (filterIndustry.isEmpty || filterIndustry == '전체') return true;
    final keywords = _industryKeywords[filterIndustry];
    if (keywords == null) {
      // 매핑에 없으면 단순 포함 비교
      return store.industry.contains(filterIndustry);
    }
    final lowerIndustry = store.industry.toLowerCase();
    final lowerName = store.storeName.toLowerCase();
    final lowerMenu = store.menu1.toLowerCase();

    return keywords.any((kw) {
      final k = kw.toLowerCase();
      return lowerIndustry.contains(k) ||
          lowerName.contains(k) ||
          lowerMenu.contains(k);
    });
  }

  Future<void> _openSearch({bool openFilter = false}) async {
    final result = await context.push<Map<String, dynamic>>(
      AppRoutes.searchResult,
      extra: {'query': _searchQuery, 'openFilter': openFilter},
    );

    if (result != null) {
      setState(() {
        _searchQuery = result['query'] as String? ?? _searchQuery;
        _searchFilter = result['filter'] as SearchFilter? ?? _searchFilter;
      });
      _isFetching = false; // 필터 변경 후 마커 재조회를 위해 플래그 리셋
      _searchInCurrentArea();
    }
  }

  Timer? _boundsDebouncer;

  void _onMarkerClicked(int index) {
    if (index == -1) {
      setState(() {
        _showStoreSummary = false;
      });
    } else if (index >= 0 && index < _currentStores.length) {
      setState(() {
        _selectedStore = _currentStores[index];
        _showStoreSummary = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAllStores(); // 앱 구동 시 한 번만 전체 데이터 로드
    WidgetsBinding.instance.addObserver(this); // 앱 생명주기 감지 등록
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveToCurrentLocation());
    if (kIsWeb) {
      web_helper.registerKakaoWebViewFactory(_viewId);
      web_helper.registerWebCallbacks(_searchInCurrentArea, _onMarkerClicked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _initWebMap());
    } else {
      _initMobileController();
    }
  }

  Future<void> _fetchAllStores() async {
    // 💡 백엔드 베이스 URL은 ApiClient에서 일원 관리합니다.
    final url = ApiClient.uri('/api/stores/all');
    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        debugPrint('JSON decode 시작');
        final decodedString = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(decodedString);
        debugPrint('JSON decode 완료, data length: ${data.length}');

        final List<Store> parsedStores = [];
        for (var i = 0; i < data.length; i++) {
          try {
            final store = Store.fromJson(data[i]);
            if (store.latitude != 0 && store.longitude != 0) {
              parsedStores.add(store);
            }
          } catch (e) {
            debugPrint('Store parse error at index $i: $e');
          }
        }
        debugPrint('Store 객체 파싱 완료: ${parsedStores.length}개');

        if (mounted) {
          setState(() {
            _allStores = parsedStores;
            HomeMapScreen.globalAllStores = _allStores;
            _isAllStoresLoaded = true;
          });
          debugPrint('setState(_isAllStoresLoaded = true) 완료. UI가 곧 업데이트됩니다.');

          if (kIsWeb) {
            debugPrint('웹: 전체 데이터를 로드했습니다. onKakaoMapIdle 이벤트로 bounds 로딩을 진행합니다.');
          } else {
            debugPrint('모바일: requestBounds() 자동 호출에 맡깁니다.');
          }
        }
      } else {
        throw Exception('API responded with status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('전체 매장 로드 실패: $e');
      if (mounted) {
        setState(() {
          _hasLoadError = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isFetching = false;
      _positionStream?.resume();
      _compassStream?.resume();
    } else if (state == AppLifecycleState.paused) {
      _positionStream?.pause();
      _compassStream?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _compassStream?.cancel();
    _pageController.dispose();
    _boundsDebouncer?.cancel();
    super.dispose();
  }

  void _initMobileController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'Print',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('WebView: ${message.message}');
          if (message.message == 'Map Initialized on Mobile') {
            _moveToCurrentLocation();
          }
          if (message.message.startsWith('BOUNDS:')) {
            _boundsDebouncer?.cancel();
            _boundsDebouncer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                _fetchAndAddMarkersForMobile(message.message.substring(7));
              }
            });
          }
          if (message.message.startsWith('CLICK:')) {
            final indexStr = message.message.substring(6);
            final index = int.tryParse(indexStr);
            if (index != null && index < _currentStores.length) {
              setState(() {
                _selectedStore = _currentStores[index];
                _showStoreSummary = true;
              });
            }
          }
          if (message.message == 'MAP_CLICK') {
            _hideStore();
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
        .my-location-wrapper {
          width: 40px;
          height: 40px;
          position: relative;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: transform 0.1s ease-out;
        }
        .my-location-dot {
          width: 16px;
          height: 16px;
          background-color: #2563EB;
          border: 3px solid #FFFFFF;
          border-radius: 50%;
          box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
          z-index: 2;
        }
        .my-location-direction {
          position: absolute;
          width: 0;
          height: 0;
          border-left: 8px solid transparent;
          border-right: 8px solid transparent;
          border-bottom: 20px solid rgba(37, 99, 235, 0.4);
          top: 0px;
          z-index: 1;
        }
      </style>
      <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${_kakaoJsKey}&libraries=services,clusterer"></script>
    </head>
    <body>
      <div id="kakao-map-container"></div>
      <script>
        var map;
        var userLocationOverlay;
        var boundsTimer = null;
        var ignoreBoundsUntil = 0;

        window.onload = function() {
          var container = document.getElementById('kakao-map-container');
          var options = { center: new kakao.maps.LatLng(37.5665, 126.9780), level: 3 };
          map = new kakao.maps.Map(container, options);
          
          kakao.maps.event.addListener(map, 'idle', function() {
            if (Date.now() < ignoreBoundsUntil) {
              return;
            }
            if (boundsTimer) clearTimeout(boundsTimer);
            boundsTimer = setTimeout(function() {
              requestBounds();
            }, 600);
          });

          kakao.maps.event.addListener(map, 'click', function(mouseEvent) {
            Print.postMessage('MAP_CLICK');
          });

          Print.postMessage("Map Initialized on Mobile");
        };

        var customOverlays = [];
        var markerDataCache = [];

        function onMarkerClick(index) {
          Print.postMessage('CLICK:' + index);
        }

        function addMobileMarkers(markerListJson) {
          var markerData = JSON.parse(markerListJson);
          markerDataCache = markerData;
          
          for (var i = 0; i < customOverlays.length; i++) {
            customOverlays[i].setMap(null);
          }
          customOverlays = [];

          for (var i = 0; i < markerData.length; i++) {
            (function(idx) {
              var item = markerData[idx];

              var wrapper = document.createElement('div');
              wrapper.id = 'marker-wrapper-' + idx;
              wrapper.style.cssText = 'display:flex;flex-direction:column;align-items:center;transition:transform 0.2s ease;';

              var bubble = document.createElement('div');
              var bgColor = item.source === 'USER' ? '#F97316' : '#1D4ED8';
              bubble.style.cssText = [
                'cursor:pointer',
                'background:' + bgColor,
                'color:#fff',
                'border-radius:20px',
                'padding:5px 10px',
                'font-size:12px',
                'font-weight:700',
                'box-shadow:0 2px 8px rgba(0,0,0,0.25)',
                'white-space:nowrap',
                'display:flex',
                'flex-direction:column',
                'align-items:center',
                'gap:1px',
                'line-height:1.3',
                'border:1.5px solid rgba(255,255,255,0.3)',
                'transition:background 0.2s ease'
              ].join(';');

              var nameEl = document.createElement('span');
              nameEl.style.cssText = 'font-size:11px;font-weight:800;letter-spacing:-0.3px;';
              nameEl.innerText = item.title;

              var priceEl = document.createElement('span');
              priceEl.style.cssText = 'font-size:10px;font-weight:500;opacity:0.88;';
              priceEl.innerText = item.menu + '  ' + item.price;

              var tail = document.createElement('div');
              tail.style.cssText = [
                'width:0',
                'height:0',
                'border-left:5px solid transparent',
                'border-right:5px solid transparent',
                'border-top:6px solid ' + bgColor,
                'margin-top:-1px',
                'transition:border-top-color 0.2s ease'
              ].join(';');

              bubble.appendChild(nameEl);
              bubble.appendChild(priceEl);
              bubble.onclick = function() { onMarkerClick(idx); };
              wrapper.appendChild(bubble);
              wrapper.appendChild(tail);

              var customOverlay = new kakao.maps.CustomOverlay({
                  position: new kakao.maps.LatLng(item.lat, item.lng),
                  content: wrapper,
                  yAnchor: 1.0,
                  zIndex: 3
              });
              customOverlay.setMap(map);
              customOverlays.push(customOverlay);
            })(i);
          }
          Print.postMessage('Markers added: ' + markerData.length);
        }

        function highlightMarker(selectedIndex) {
          for (var i = 0; i < markerDataCache.length; i++) {
            var wrapper = document.getElementById('marker-wrapper-' + i);
            if (!wrapper) continue;
            var bubble = wrapper.children[0];
            var tail = wrapper.children[1];
            
            if (i === selectedIndex) {
              bubble.style.background = '#EF4444'; // Red
              tail.style.borderTopColor = '#EF4444';
              wrapper.style.transform = 'scale(1.2)';
              if (customOverlays[i]) customOverlays[i].setZIndex(10);
            } else {
              bubble.style.background = '#1D4ED8'; // Blue
              tail.style.borderTopColor = '#1D4ED8';
              wrapper.style.transform = 'scale(1.0)';
              if (customOverlays[i]) customOverlays[i].setZIndex(3);
            }
          }
        }

        function setMapCenter(lat, lng) {
          if (map) {
            var moveLatLon = new kakao.maps.LatLng(lat, lng);
            map.panTo(moveLatLon);
            if (map.getLevel() !== 3) {
              setTimeout(function() {
                map.setLevel(3, {animate: { duration: 300 }});
              }, 400);
            }
          }
        }

        function setMapCenterFromSwipe(lat, lng) {
          if (map) {
            ignoreBoundsUntil = Date.now() + 1000;
            var moveLatLon = new kakao.maps.LatLng(lat, lng);
            map.panTo(moveLatLon);
            if (map.getLevel() !== 3) {
              setTimeout(function() {
                map.setLevel(3, {animate: { duration: 300 }});
              }, 400);
            }
          }
        }

        var userHeading = 0;
        var userLocationWrapper;

        function updateUserLocationMarker(lat, lng) {
          if (!map) return;
          var position = new kakao.maps.LatLng(lat, lng);
          if (!userLocationOverlay) {
            userLocationWrapper = document.createElement('div');
            userLocationWrapper.className = 'my-location-wrapper';
            
            var dot = document.createElement('div');
            dot.className = 'my-location-dot';
            
            var direction = document.createElement('div');
            direction.className = 'my-location-direction';
            
            userLocationWrapper.appendChild(direction);
            userLocationWrapper.appendChild(dot);
            
            userLocationOverlay = new kakao.maps.CustomOverlay({
              position: position,
              content: userLocationWrapper,
              map: map
            });
          } else {
            userLocationOverlay.setPosition(position);
          }
        }

        function updateUserHeading(degree) {
          if (userLocationWrapper) {
            userHeading = degree;
            userLocationWrapper.style.transform = 'rotate(' + degree + 'deg)';
          }
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
        setState(() {
          _isMapInitialized = true;
        });
        _moveToCurrentLocation();
        // 💡 카카오맵 SDK 로드는 비동기라, 맵 객체 등록 전에 호출된
        // 중심 이동/위치 마커 갱신이 무시될 수 있습니다.
        // 맵 준비 완료 후를 겨냥해 지연 재시도합니다.
        for (final delay in [3, 8]) {
          Future.delayed(Duration(seconds: delay), () {
            if (mounted) _moveToCurrentLocation();
          });
        }
      } catch (e) {
        debugPrint('지도 초기화 에러: ${e}');
      }
    });
  }

  Future<void> _moveToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 서비스를 활성화해주세요.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.')),
        );
      return;
    }

    _startLocationTracking();

    try {
      Position? position = _lastKnownPosition;
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 3),
          );
        } catch (e) {
          position = await Geolocator.getLastKnownPosition();
        }
        if (position != null) {
          _lastKnownPosition = position;
          HomeMapScreen.globalUserPosition = position;
          _updateLocationMarker(position.latitude, position.longitude);
        }
      } else {
        _updateLocationMarker(position.latitude, position.longitude);
      }

      if (position != null) {
        if (kIsWeb) {
          web_helper.setKakaoMapCenterWeb(
            _viewId,
            position.latitude,
            position.longitude,
          );
        } else {
          _safeRunJavaScript(
            'setMapCenter(${position.latitude}, ${position.longitude});',
          );
        }
      }
    } catch (e) {
      debugPrint('위치 가져오기 에러: ${e}');
    }
  }

  void _updateUserHeading(double heading) {
    if (kIsWeb) return; // 웹에서는 나침반 제외
    _safeRunJavaScript('updateUserHeading($heading);');
  }

  void _updateLocationMarker(double lat, double lng) {
    if (kIsWeb) {
      web_helper.updateUserLocationMarkerWeb(_viewId, lat, lng);
    } else {
      _safeRunJavaScript(
        'updateUserLocationMarker(${lat}, ${lng});',
      );
    }
  }

  void _safeRunJavaScript(String script) {
    try {
      _webViewController?.runJavaScript(script);
    } catch (e) {
      debugPrint('WebView JS 실행 에러 (무시됨): $e');
    }
  }

  void _startLocationTracking() {
    if (_positionStream != null) return;

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2, // 2미터 이상 이동 시 갱신
          ),
        ).listen((Position position) {
          _lastKnownPosition = position;
          HomeMapScreen.globalUserPosition = position;
          _updateLocationMarker(position.latitude, position.longitude);
        });

    if (!kIsWeb) {
      _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
        if (event.heading != null) {
          _updateUserHeading(event.heading!);
        }
      });
    }
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
      _safeRunJavaScript('requestBounds();');
    }
  }

  Future<void> _fetchAndAddMarkersForMobile(String boundsJson) async {
    if (_isFetching) return; // 이미 요청 중이면 무시
    _isFetching = true;
    try {
      final Map<String, dynamic> bounds = json.decode(boundsJson);
      final markerList = await _fetchStoresFromBackend(bounds);

      if (_webViewController != null) {
        final jsStringLiteral = jsonEncode(jsonEncode(markerList));
        _safeRunJavaScript(
          'addMobileMarkers($jsStringLiteral);',
        );
      }

      if (markerList.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이 주변에는 조건에 맞는 업소가 없습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _fetchAndAddMarkersWeb(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);

    web_helper.addMobileMarkersWeb(_viewId, json.encode(markerList));

    if (markerList.isEmpty && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 주변에는 조건에 맞는 업소가 없습니다.')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStoresFromBackend(
    Map<String, dynamic> bounds,
  ) async {
    if (!_isAllStoresLoaded) {
      return []; // 전체 데이터가 로드될 때까지 빈 배열 반환
    }

    final minLat = bounds['minLat'] as double;
    final maxLat = bounds['maxLat'] as double;
    final minLng = bounds['minLng'] as double;
    final maxLng = bounds['maxLng'] as double;

    try {
      // 💡 백엔드 베이스 URL은 ApiClient에서 일원 관리합니다.
      final url = ApiClient.uri('/api/stores/bounds', {
        'minLat': '$minLat',
        'maxLat': '$maxLat',
        'minLng': '$minLng',
        'maxLng': '$maxLng',
      });

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      List<Store> fetchedStores = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        fetchedStores = data.map((json) => Store.fromJson(json)).toList();
      } else {
        // Fallback to local _allStores if backend fails
        fetchedStores = _allStores;
      }
      
      var stores = fetchedStores
          .where(
            (s) =>
                s.latitude >= minLat &&
                s.latitude <= maxLat &&
                s.longitude >= minLng &&
                s.longitude <= maxLng,
          )
          .toList();

      // ─── 검색 및 필터 적용 ───
      if (_searchQuery.trim().isNotEmpty) {
        stores = stores
            .where(
              (s) =>
                  s.storeName.contains(_searchQuery) ||
                  s.menu1.contains(_searchQuery) ||
                  s.industry.contains(_searchQuery),
            )
            .toList();
      }

      if (_searchFilter.maxPrice != null) {
        stores = stores.where((s) {
          final p = int.tryParse(s.price1.replaceAll(RegExp(r'[^0-9]'), ''));
          return p == null || p <= _searchFilter.maxPrice!;
        }).toList();
      }

      if (_searchFilter.industries.isNotEmpty) {
        stores = stores
            .where(
              (s) => _searchFilter.industries.any(
                (ind) => SearchFilter.matchesIndustry(s, ind),
              ),
            )
            .toList();
      }

      if (_searchFilter.govCertified) {
        stores = stores.where((s) => s.source == 'GOV').toList();
      } else if (!_searchFilter.userReported) {
        stores = stores.where((s) => s.source != 'USER').toList();
      }

      if (_searchFilter.distance != null && _lastKnownPosition != null) {
        double maxDist = 0;
        if (_searchFilter.distance == '500m 이내')
          maxDist = 500;
        else if (_searchFilter.distance == '1km 이내')
          maxDist = 1000;
        else if (_searchFilter.distance == '3km 이내')
          maxDist = 3000;

        if (maxDist > 0) {
          stores = stores.where((s) {
            final d = Geolocator.distanceBetween(
              _lastKnownPosition!.latitude,
              _lastKnownPosition!.longitude,
              s.latitude,
              s.longitude,
            );
            return d <= maxDist;
          }).toList();
        }
      }

      if (_searchFilter.sortOrder == '저렴한순') {
        stores.sort((a, b) {
          final pa = int.tryParse(a.price1.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
          final pb = int.tryParse(b.price1.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
          return pa.compareTo(pb);
        });
      } else {
        if (_lastKnownPosition != null) {
          stores.sort((a, b) {
            final da = Geolocator.distanceBetween(
              _lastKnownPosition!.latitude,
              _lastKnownPosition!.longitude,
              a.latitude,
              a.longitude,
            );
            final db = Geolocator.distanceBetween(
              _lastKnownPosition!.latitude,
              _lastKnownPosition!.longitude,
              b.latitude,
              b.longitude,
            );
            return da.compareTo(db);
          });
        }
      }

      // 💥 너무 많은 마커가 렌더링되어 앱이 멈추는 것을 방지 (최대 100개)
      if (stores.length > 100) {
        stores = stores.take(100).toList();
      }

      _currentStores = stores;

      return _currentStores.map((s) {
        final p = s.price1.replaceAll(RegExp(r'[^0-9]'), '');
        final priceStr = p.isEmpty
            ? s.price1
            : '${p.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
        return {
          'lat': s.latitude,
          'lng': s.longitude,
          'title': s.storeName,
          'menu': s.menu1.isNotEmpty ? s.menu1 : s.industry,
          'price': priceStr,
          'source': s.source,
        };
      }).toList();
    } catch (e) {
      debugPrint('필터링 에러: ${e}');
      return [];
    }
  }

  Widget _buildWebMap() {
    return Stack(
      children: [
        Positioned.fill(
          child: HtmlElementView(key: const ValueKey('kakao-map-web'), viewType: _viewId),
        ),
        if (!_isMapInitialized)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildMobileMap() {
    if (_webViewController == null)
      return const Center(child: Text('초기화 중...'));
    return WebViewWidget(
      key: const ValueKey('kakao-map-mobile'),
      controller: _webViewController!,
    );
  }

  @override
  void didUpdateWidget(covariant HomeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showAiSpotlight != widget.showAiSpotlight) {
      _showAiSpotlight = widget.showAiSpotlight;
    }
  }

  void _handleMarkerClick(String storeId) {
    try {
      final store = _currentStores.firstWhere(
        (s) => s.storeName + s.address == storeId,
      );
      setState(() {
        _selectedStore = store;
        _showStoreSummary = true;
      });
    } catch (e) {
      debugPrint('가게 찾기 실패: $e');
    }
  }

  void _showStore() {
    setState(() {
      _showStoreSummary = true;
    });
  }

  void _hideStore() {
    if (!_showStoreSummary) {
      return;
    }

    setState(() {
      _showStoreSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = HowmuchBottomNav.heightFor(bottomOffset);
    const storeCardHeight = 158.0;
    const storeCardBottomGap = 94.0;

    // Use actual screen dimensions for responsive layout
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = kIsWeb
        ? screenSize.width.clamp(320.0, FigmaMobileCanvas.maxWebWidth)
        : FigmaMobileCanvas.width;
    final screenHeight = kIsWeb ? screenSize.height : FigmaMobileCanvas.height;

    final storeCardTop = screenHeight - storeCardBottomGap - storeCardHeight;
    final aiControlLeft = screenWidth - AppSizes.horizontalPadding - 143;
    final spotlightAiLeft = screenWidth - 2 - 157;
    final homeChromeOpacity = _showAiSpotlight ? 0.0 : 1.0;
    final bottomBase = screenHeight - bottomNavHeight;
    final floatingLocationTop = _showStoreSummary
        ? storeCardTop - 132.0
        : bottomBase - 132.0;
    final floatingAiTop = _showStoreSummary
        ? storeCardTop - 68.0
        : bottomBase - 68.0;
    final spotlightAiTop = bottomBase - 77.0;
    final spotlightCoachTop = spotlightAiTop - 48.0;

    debugPrint(
      'HomeMapScreen build called! _isAllStoresLoaded: $_isAllStoresLoaded',
    );
    final activeFilters = _searchFilter.activeLabels;
    final hasFilters = activeFilters.isNotEmpty;
    final isSearching = _searchQuery.isNotEmpty || hasFilters;
    final topOffsetPush = hasFilters ? 44.0 : 0.0;

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFDDE6F0),
      child: Stack(
        children: [
          // TODO(박지환 BE): 여기를 지우고 실제 지도 API 위젯으로 교체하세요.
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideStore,
              behavior: HitTestBehavior.opaque,
              child: kIsWeb ? _buildWebMap() : _buildMobileMap(),
            ),
          ),

          if (!_isAllStoresLoaded)
            Positioned.fill(
              child: Container(
                color: Colors.white.withAlpha(230), // 0.9 opacity approx
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                          image: const DecorationImage(
                            image: AssetImage('assets/images/app_logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _hasLoadError
                            ? '데이터를 불러오지 못했어요.\n서버 연결을 확인해주세요.'
                            : '가성비 식당 데이터를\n열심히 불러오고 있어요...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _hasLoadError
                              ? Colors.red
                              : const Color(0xFF2563EB),
                          fontFamily: 'Inter',
                          fontFamilyFallback: const [
                            'Apple SD Gothic Neo',
                            'Noto Sans KR',
                          ],
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSizes.largeSpacing),
                      if (_hasLoadError)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _hasLoadError = false;
                            });
                            _fetchAllStores();
                          },
                          child: const Text('다시 시도'),
                        )
                      else
                        const CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            left: AppSizes.horizontalPadding,
            right: AppSizes.horizontalPadding,
            top: 10 + topOffset,
            height: 52,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _SearchBar(
                  query: _searchQuery,
                  onTap: _openSearch,
                  onFilterTap: () => _openSearch(openFilter: true),
                ),
              ),
            ),
          ),

          if (hasFilters)
            Positioned(
              left: 0,
              right: 0,
              top: 10 + topOffset + 52 + 10, // _SearchBar below
              height: 32,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.horizontalPadding,
                  ),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: activeFilters.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSizes.smallSpacing),
                  itemBuilder: (context, i) {
                    final label = activeFilters[i];
                    return Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF2563EB),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontFamily: HomeMapScreen.fontFamily,
                              fontFamilyFallback: HomeMapScreen.fontFallback,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(
                                () =>
                                    _searchFilter = _searchFilter.remove(label),
                              );
                              _searchInCurrentArea();
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          if (!isSearching) ...[
            Positioned(
              left: AppSizes.horizontalPadding,
              top: 67.98297119140625 + topOffset + topOffsetPush,
              width: 183.67897033691406,
              height: 28.480112075805664,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: const _SourceLegend(),
              ),
            ),
            Positioned(
              left: AppSizes.horizontalPadding,
              right: AppSizes.horizontalPadding,
              top: 106.46307373046875 + topOffset + topOffsetPush,
              height: 55.80965805053711,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: const _TodayPickCard(),
              ),
            ),
          ],
          Positioned(
            right: 16,
            top: floatingLocationTop,
            width: 52.0,
            height: 52.0,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: GestureDetector(
                onTap: _moveToCurrentLocation,
                child: const _RoundIconButton(
                  icon: Icons.near_me_rounded,
                  color: HomeMapScreen.blue,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: floatingAiTop,
            height: 51.9886360168457,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _AiRecommendControl(
                  onTap: () => context.push(AppRoutes.aiRecommend),
                ),
              ),
            ),
          ),
          if (isSearching && _currentStores.isNotEmpty) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomNavHeight + 10 + storeCardHeight + 4,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: Center(
                  child: _FloatingSearchSummary(count: _currentStores.length),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomNavHeight + 10,
              height: storeCardHeight,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _currentStores.length,
                  onPageChanged: (index) {
                    if (index < _currentStores.length) {
                      final store = _currentStores[index];
                      if (kIsWeb) {
                        web_helper.setKakaoMapCenterFromSwipeWeb(
                          _viewId,
                          store.latitude,
                          store.longitude,
                        );
                      } else {
                        _safeRunJavaScript(
                          'setMapCenterFromSwipe(${store.latitude}, ${store.longitude}); highlightMarker($index);',
                        );
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index >= _currentStores.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (_) {},
                        onHorizontalDragUpdate: (_) {},
                        child: _StoreSummaryCard(store: _currentStores[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else if (isSearching && _currentStores.isEmpty) ...[
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomNavHeight + 20,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: Center(child: _FloatingSearchSummary(count: 0)),
              ),
            ),
          ] else if (_showStoreSummary && _selectedStore != null) ...[
            Positioned(
              left: AppSizes.horizontalPadding,
              right: AppSizes.horizontalPadding,
              top: storeCardTop,
              height: storeCardHeight,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  child: _StoreSummaryCard(store: _selectedStore!),
                ),
              ),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomNavHeight,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: HowmuchBottomNav(
                  safeBottom: bottomOffset,
                  activeTab: HowmuchBottomTab.home,
                ),
              ),
            ),
          ),
          if (_showAiSpotlight) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showAiSpotlight = false;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .22),
                  ),
                ),
              ),
            ),
            Positioned(
              left: (screenWidth - 265) / 2,
              top: spotlightCoachTop,
              width: 265,
              height: 38,
              child: _AiCoachTip(
                onTap: () => context.push(AppRoutes.aiRecommend),
              ),
            ),
            Positioned(
              right: 16,
              top: spotlightAiTop,
              height: 70,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _AiRecommendControl(
                  onTap: () => context.push(AppRoutes.aiRecommend),
                  spotlight: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreTapTarget extends StatelessWidget {
  const _StoreTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, this.onFilterTap, this.query = ''});

  final VoidCallback onTap;
  final VoidCallback? onFilterTap;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 7,
              shadowColor: const Color(0x140F172A),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 19,
                      ),
                      const SizedBox(width: 7.997158050537109),
                      Expanded(
                        child: Text(
                          query.isNotEmpty ? query : '가게명, 메뉴, 지역 검색',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: query.isNotEmpty
                                ? HomeMapScreen.ink
                                : HomeMapScreen.hint,
                            fontFamily: HomeMapScreen.fontFamily,
                            fontFamilyFallback: HomeMapScreen.fontFallback,
                            fontSize: 14,
                            fontWeight: query.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7.997158050537109),
        _SquareButton(icon: Icons.tune_rounded, onTap: onFilterTap),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 7,
      shadowColor: const Color(0x140F172A),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: HomeMapScreen.ink, size: 19),
        ),
      ),
    );
  }
}

class _SourceLegend extends StatelessWidget {
  const _SourceLegend();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: const [
            SizedBox(width: 11.988616943359375),
            _Dot(color: HomeMapScreen.blue),
            SizedBox(width: 5.994326591491699),
            Text('정부 인증', style: _smallText),
            SizedBox(width: 10),
            SizedBox(
              height: 10,
              child: VerticalDivider(color: Color(0xFFE5E7EB), width: 1),
            ),
            SizedBox(width: 10),
            _Dot(color: HomeMapScreen.orange),
            SizedBox(width: 5.994326591491699),
            Text('사용자 제보', style: _smallText),
            SizedBox(width: 11.988616943359375),
          ],
        ),
      ),
    );
  }
}

class _TodayPickCard extends StatelessWidget {
  const _TodayPickCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.todaysPick),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: .909),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 55.99431610107422,
              height: 53.99147415161133,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thunderstorm_outlined,
                      color: HomeMapScreen.blue,
                      size: 20,
                    ),
                    SizedBox(height: 1.989),
                    Text(
                      '18°',
                      style: TextStyle(
                        color: HomeMapScreen.blue,
                        fontFamily: HomeMapScreen.fontFamily,
                        fontFamilyFallback: HomeMapScreen.fontFallback,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 11.988616943359375),
            Expanded(child: _TodayPickText()),
            _RankDot(label: '1', color: HomeMapScreen.blue),
            _RankDot(label: '2', color: HomeMapScreen.orange),
            _RankDot(label: '3', color: HomeMapScreen.green),
            SizedBox(width: 9.985779),
            Icon(
              Icons.chevron_right_rounded,
              color: HomeMapScreen.muted,
              size: 17,
            ),
            SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _TodayPickText extends StatelessWidget {
  const _TodayPickText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const Text(
              '오늘의 픽',
              style: TextStyle(
                color: HomeMapScreen.blue,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.5,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(width: 5.994),
            Text(
              '· ${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')} ${['월','화','수','목','금','토','일'][DateTime.now().weekday - 1]}',
              style: TextStyle(
                color: HomeMapScreen.muted,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: .994),
        Text(
          '따뜻한 국물 메뉴 3곳',
          style: TextStyle(
            color: HomeMapScreen.ink,
            fontFamily: HomeMapScreen.fontFamily,
            fontFamilyFallback: HomeMapScreen.fontFallback,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StoreSummaryCard extends StatelessWidget {
  final Store store;
  const _StoreSummaryCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F172A),
            blurRadius: 16,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StoreInfo(store: store)),
                  _StorePrice(store: store),
                ],
              ),
            ),
            const SizedBox(height: 11.5),
            Row(
              children: [
                const _SavingBadge(),
                const Spacer(),
                _DetailButton(store: store),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  final Store store;
  const _StoreInfo({required this.store});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(left: 0, top: 0, child: _GovernmentBadge()),
        Positioned(
          left: 77.5,
          top: 2.2442626953125,
          child: Text(
            '· ${store.address.split(' ').take(3).join(' ')}',
            style: _muted11,
          ),
        ),
        Positioned(
          left: 0,
          top: 28.991455078125,
          child: Text(
            store.storeName,
            style: const TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Positioned(
          left: 0,
          top: 58.4801025390625,
          child: Text(store.industry, style: _muted12),
        ),
        const Positioned(
          left: 67.05963134765625,
          top: 61.974365234375,
          child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 11),
        ),
        const Positioned(
          left: 86.05111694335938,
          top: 58.4801025390625,
          child: Text(
            '4.6',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _StorePrice extends StatelessWidget {
  final Store store;
  const _StorePrice({required this.store});

  @override
  Widget build(BuildContext context) {
    final p = store.price1.replaceAll(RegExp(r'[^0-9]'), '');
    final priceStr = p.isEmpty
        ? store.price1
        : p.replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    final menuStr = store.menu1.isNotEmpty ? store.menu1 : '대표 메뉴';

    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            menuStr,
            style: _muted10,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: priceStr, style: const TextStyle(fontSize: 17)),
                if (p.isNotEmpty)
                  const TextSpan(text: '원', style: TextStyle(fontSize: 12)),
              ],
            ),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingBadge extends StatelessWidget {
  const _SavingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24.474430084228516,
      padding: const EdgeInsets.symmetric(horizontal: 7.997161865234375),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        '평균 대비 2,000원 절약',
        style: TextStyle(
          color: HomeMapScreen.green,
          fontFamily: HomeMapScreen.fontFamily,
          fontFamilyFallback: HomeMapScreen.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}

class _DetailButton extends StatelessWidget {
  final Store store;
  const _DetailButton({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storeDetail, extra: store),
      child: Container(
        width: 88.9772720336914,
        height: 29.985794067382812,
        decoration: BoxDecoration(
          color: HomeMapScreen.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '상세보기',
              style: TextStyle(
                color: Colors.white,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 13),
          ],
        ),
      ),
    );
  }
}

class _HomeMapPainter extends CustomPainter {
  const _HomeMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // TODO(박지환 BE): 실제 지도 API 연결 후 이 더미 지도 그림은 삭제하세요.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;
    final roadDashed = Paint()
      ..color = const Color(0xFFD9E2EE)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    final park = Paint()..color = const Color(0xFFD7EED5);
    final water = Paint()..color = const Color(0x1F2563EB);

    canvas.drawLine(Offset(0, 258), Offset(size.width, 225), road);
    canvas.drawLine(Offset(0, 496), Offset(size.width, 530), road);
    canvas.drawLine(Offset(132, 0), Offset(126, size.height), road);
    canvas.drawLine(Offset(250, 0), Offset(273, size.height), road);

    for (var i = 0; i < 30; i++) {
      final x = i * 14.0;
      canvas.drawLine(
        Offset(x, 252 - i * .9),
        Offset(x + 7, 251 - i * .9),
        roadDashed,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(200, 304, 115, 114),
        const Radius.circular(12),
      ),
      park,
    );
    canvas.drawCircle(
      const Offset(238, 351),
      10,
      Paint()..color = const Color(0xFFB7DDB6),
    );
    canvas.drawCircle(
      const Offset(276, 379),
      14,
      Paint()..color = const Color(0xFFB7DDB6),
    );
    canvas.drawCircle(const Offset(187, 728), 42, water);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      height: 29,
      child: Column(
        children: [
          Container(
            width: 122,
            height: 24,
            decoration: BoxDecoration(
              color: HomeMapScreen.blue,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '●  착한분식 5,500원',
              style: TextStyle(
                color: Colors.white,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(9, 5),
            painter: _TrianglePainter(HomeMapScreen.blue),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _AiRecommendControl extends StatelessWidget {
  const _AiRecommendControl({required this.onTap, this.spotlight = false});

  final VoidCallback onTap;
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    if (spotlight) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 78,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'AI',
                      style: TextStyle(color: HomeMapScreen.blue),
                    ),
                    TextSpan(text: ' 추천받기'),
                  ],
                ),
                style: TextStyle(
                  color: HomeMapScreen.ink,
                  fontFamily: HomeMapScreen.fontFamily,
                  fontFamilyFallback: HomeMapScreen.fontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 70,
              height: 70,
              child: CustomPaint(
                painter: const _DashedCirclePainter(),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [HomeMapScreen.blue, Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x662563EB),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 82,
            height: 22.982954025268555,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: HomeMapScreen.blue),
                  ),
                  TextSpan(text: ' 추천받기'),
                ],
              ),
              style: TextStyle(
                color: HomeMapScreen.ink,
                fontFamily: HomeMapScreen.fontFamily,
                fontFamilyFallback: HomeMapScreen.fontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 7.5),
          Container(
            width: 51.9886360168457,
            height: 51.9886360168457,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeMapScreen.blue, Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.818),
              boxShadow: [
                BoxShadow(
                  color: spotlight
                      ? const Color(0x997C3AED)
                      : const Color(0x592563EB),
                  blurRadius: spotlight ? 26 : 10,
                  spreadRadius: spotlight ? 7 : 0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCoachTip extends StatelessWidget {
  const _AiCoachTip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF2563EB),
              size: 14,
            ),
            SizedBox(width: 7),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '오늘 뭐 먹을지 모르겠다면? '),
                    TextSpan(
                      text: 'AI에게 물어보기',
                      style: TextStyle(color: HomeMapScreen.blue),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeMapScreen.ink,
                  fontFamily: HomeMapScreen.fontFamily,
                  fontFamilyFallback: HomeMapScreen.fontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HomeMapScreen.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    const dashCount = 22;
    const gapRadians = .08;
    final sweep = (math.pi * 2 / dashCount) - gapRadians;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        rect.deflate(3),
        i * math.pi * 2 / dashCount,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RankDot extends StatelessWidget {
  const _RankDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21.988636016845703,
      height: 21.988636016845703,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.818),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: HomeMapScreen.fontFamily,
          fontFamilyFallback: HomeMapScreen.fontFallback,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
    );
  }
}

class _GovernmentBadge extends StatelessWidget {
  const _GovernmentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20.99431800842285,
      padding: const EdgeInsets.symmetric(horizontal: 7.997161865234375),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(color: HomeMapScreen.blue, size: 5.994318008422852),
          SizedBox(width: 5.994),
          Text(
            '정부 인증',
            style: TextStyle(
              color: HomeMapScreen.blue,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 7.997159004211426});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox(width: size, height: size),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _smallText = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted10 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _muted11 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

// ──────────────────────────────────────────────────────────────
//  검색 안내 칩
// ──────────────────────────────────────────────────────────────
class _FloatingSearchSummary extends StatelessWidget {
  const _FloatingSearchSummary({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 14),
          const SizedBox(width: 6),
          const Text(
            '주변 1km 안에 ',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$count개 매장',
            style: const TextStyle(
              color: HomeMapScreen.blue,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            ' 이 있어요',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

const _muted12 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);
