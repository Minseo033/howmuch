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
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key, this.showAiSpotlight = false});

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

class _HomeMapScreenState extends State<HomeMapScreen> {
  bool _showStoreSummary = false;
  late bool _showAiSpotlight = widget.showAiSpotlight;

  final String _viewId = 'kakao-map-container';
  final String _kakaoJsKey = '949e657c37f55074dbb2a14ceb273e2b';
  bool _isMapInitialized = false;
  WebViewController? _webViewController;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Position? _lastKnownPosition;

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
          if (message.message == 'Map Initialized on Mobile') {
            _moveToCurrentLocation();
          }
          if (message.message.startsWith('BOUNDS:')) {
            _fetchAndAddMarkersForMobile(message.message.substring(7));
          }
        },
      )
      ..loadHtmlString(_getMobileMapHtml());
  }

  void _loadStoresInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
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
        var clusterer;
        var userLocationOverlay;

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
            timeLimit: const Duration(seconds: 3),
          );
        } catch (e) {
          position = await Geolocator.getLastKnownPosition();
        }
        if (position != null) {
          _lastKnownPosition = position;
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
          _webViewController?.runJavaScript(
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
    _webViewController?.runJavaScript('updateUserHeading($heading);');
  }

  void _updateLocationMarker(double lat, double lng) {
    if (kIsWeb) {
      web_helper.updateUserLocationMarkerWeb(_viewId, lat, lng);
    } else {
      _webViewController?.runJavaScript(
        'updateUserLocationMarker(${lat}, ${lng});',
      );
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
      _webViewController?.runJavaScript('requestBounds();');
    }
  }

  Future<void> _fetchAndAddMarkersForMobile(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);

    if (markerList.isNotEmpty && _webViewController != null) {
      final jsonString = json
          .encode(markerList)
          .replaceAll("'", "\'")
          .replaceAll('"', '\"');
      _webViewController!.runJavaScript(
        'addMobileMarkers("' + jsonString + '");',
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${markerList.length}개의 업소를 찾았습니다.')),
        );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  Future<void> _fetchAndAddMarkersWeb(String boundsJson) async {
    final Map<String, dynamic> bounds = json.decode(boundsJson);
    final markerList = await _fetchStoresFromBackend(bounds);

    if (markerList.isNotEmpty) {
      web_helper.addKakaoMarkersWeb(_viewId, json.encode(markerList));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${markerList.length}개의 업소를 찾았습니다.')),
        );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 주변에는 착한가격업소가 없습니다.')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStoresFromBackend(
    Map<String, dynamic> bounds,
  ) async {
    final minLat = bounds['minLat'];
    final maxLat = bounds['maxLat'];
    final minLng = bounds['minLng'];
    final maxLng = bounds['maxLng'];

    String host = kIsWeb ? 'localhost' : '10.0.2.2';
    final url =
        'http://${host}:8081/api/test/bounds?minLat=${minLat}&maxLat=${maxLat}&minLng=${minLng}&maxLng=${maxLng}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final stores = data.map((json) => Store.fromJson(json)).toList();
        return stores
            .where((s) => s.latitude != 0 && s.longitude != 0)
            .map(
              (s) => {
                'lat': s.latitude,
                'lng': s.longitude,
                'title': s.storeName,
              },
            )
            .toList();
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
    if (_webViewController == null)
      return const Center(child: Text('초기화 중...'));
    return WebViewWidget(controller: _webViewController!);
  }

  @override
  void didUpdateWidget(covariant HomeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showAiSpotlight != widget.showAiSpotlight) {
      _showAiSpotlight = widget.showAiSpotlight;
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
    const storeCardHeight = 150.44033813476562;
    const storeCardBottomGap = 94.0;
    final storeCardTop =
        FigmaMobileCanvas.height - storeCardBottomGap - storeCardHeight;
    final aiControlLeft = FigmaMobileCanvas.width - 15.99432373046875 - 143;
    final spotlightAiLeft = FigmaMobileCanvas.width - 2 - 157;
    final homeChromeOpacity = _showAiSpotlight ? 0.0 : 1.0;
    final bottomBase = FigmaMobileCanvas.height - bottomNavHeight;
    final floatingLocationTop = _showStoreSummary
        ? storeCardTop - 132.0
        : bottomBase - 132.0;
    final floatingAiTop = _showStoreSummary
        ? storeCardTop - 68.0
        : bottomBase - 68.0;
    final spotlightAiTop = bottomBase - 77.0;
    final spotlightCoachTop = spotlightAiTop - 48.0;

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

          // TODO(박지환 BE): 매장/가격/좌표 DB API가 붙으면 아래 더미 마커들을 API 응답 기반으로 렌더링하세요.
          Positioned(
            left: 139,
            top: 401.03265380859375,
            child: _StoreTapTarget(
              onTap: _showStore,
              child: const _PriceMarker(),
            ),
          ),

          Positioned(
            left: 15.99432373046875,
            top: 10 + topOffset,
            width: 343.4659118652344,
            height: 52,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: _SearchBar(
                onTap: () => context.push(AppRoutes.searchEmpty),
              ),
            ),
          ),
          Positioned(
            left: 15.99432373046875,
            top: 67.98297119140625 + topOffset,
            width: 183.67897033691406,
            height: 28.480112075805664,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: const _SourceLegend(),
            ),
          ),
          Positioned(
            left: 15.99432373046875,
            top: 106.46307373046875 + topOffset,
            width: 343.4659118652344,
            height: 55.80965805053711,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: const _TodayPickCard(),
            ),
          ),
          Positioned(
            left: 307.0,
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
            left: aiControlLeft,
            top: floatingAiTop,
            width: 143,
            height: 51.9886360168457,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: _AiRecommendControl(
                onTap: () => context.push(AppRoutes.aiRecommend),
              ),
            ),
          ),
          if (_showStoreSummary)
            Positioned(
              left: 15.99432373046875,
              top: storeCardTop,
              width: 343.4659118652344,
              height: storeCardHeight,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: const _StoreSummaryCard(),
              ),
            ),
          Positioned(
            left: 0,
            bottom: 0,
            width: FigmaMobileCanvas.width,
            height: bottomNavHeight,
            child: Opacity(
              opacity: homeChromeOpacity,
              child: HowmuchBottomNav(
                safeBottom: bottomOffset,
                activeTab: HowmuchBottomTab.home,
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
              left: (FigmaMobileCanvas.width - 265) / 2,
              top: spotlightCoachTop,
              width: 265,
              height: 38,
              child: _AiCoachTip(
                onTap: () => context.push(AppRoutes.aiRecommend),
              ),
            ),
            Positioned(
              left: spotlightAiLeft,
              top: spotlightAiTop,
              width: 157,
              height: 70,
              child: _AiRecommendControl(
                onTap: () => context.push(AppRoutes.aiRecommend),
                spotlight: true,
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
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.99432373046875),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 19,
                      ),
                      SizedBox(width: 7.997158050537109),
                      Text(
                        '가게명, 메뉴, 지역 검색',
                        style: TextStyle(
                          color: HomeMapScreen.hint,
                          fontFamily: HomeMapScreen.fontFamily,
                          fontFamilyFallback: HomeMapScreen.fontFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
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
        const _SquareButton(icon: Icons.tune_rounded),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 7,
      shadowColor: const Color(0x140F172A),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, color: HomeMapScreen.ink, size: 19),
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
    return DecoratedBox(
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
      children: const [
        Row(
          children: [
            Text(
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
            SizedBox(width: 5.994),
            Text(
              '· 05.16 토',
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
  const _StoreSummaryCard();

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
        padding: const EdgeInsets.all(15.99432373046875),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StoreInfo()),
                  _StorePrice(),
                ],
              ),
            ),
            SizedBox(height: 11.5),
            Row(children: [_SavingBadge(), Spacer(), _DetailButton()]),
          ],
        ),
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(left: 0, top: 0, child: _GovernmentBadge()),
        Positioned(
          left: 77.5,
          top: 2.2442626953125,
          child: Text('· 320m', style: _muted11),
        ),
        Positioned(
          left: 0,
          top: 28.991455078125,
          child: Text(
            '착한분식',
            style: TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 58.4801025390625,
          child: Text('한식 · 분식', style: _muted12),
        ),
        Positioned(
          left: 67.05963134765625,
          top: 61.974365234375,
          child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 11),
        ),
        Positioned(
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
  const _StorePrice();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Text('대표 메뉴', style: _muted10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '5,500', style: TextStyle(fontSize: 17)),
                TextSpan(text: '원', style: TextStyle(fontSize: 12)),
              ],
            ),
            textAlign: TextAlign.right,
            style: TextStyle(
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
  const _DetailButton();

  @override
  Widget build(BuildContext context) {
    return Container(
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

const _muted12 = TextStyle(
  color: HomeMapScreen.muted,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);
