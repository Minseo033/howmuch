import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/home/home_map_store_loader.dart';
import 'package:howmuch/features/home/home_map_viewport_policy.dart';
import 'kakao_web_helper_stub.dart'
    if (dart.library.js_interop) 'kakao_web_helper.dart'
    as web_helper;

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'dart:async';
import 'package:howmuch/core/utils/price_formatter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_price.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/search/presentation/state/search_filter_policy.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:howmuch/core/constants/kakao_map_constants.dart';
import 'package:howmuch/core/theme/app_tokens.dart' show AppTextScale;
import 'package:howmuch/core/location/browser_location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

const Duration maxHomeLocationCacheAge = Duration(minutes: 2);
const double maxHomeMapBoundsSpanDegrees = 10;

/// The plain map's zoom-out limit. Search results may zoom out to 14.
const int maxHomeMapLevel = 10;

bool isHomeMapBoundsWithinBackendLimit(Map<String, double> bounds) {
  return bounds['maxLat']! - bounds['minLat']! <= maxHomeMapBoundsSpanDegrees &&
      bounds['maxLng']! - bounds['minLng']! <= maxHomeMapBoundsSpanDegrees;
}

bool isFreshHomeLocation(DateTime timestamp, DateTime now) {
  final age = now.toUtc().difference(timestamp.toUtc());
  return !age.isNegative && age <= maxHomeLocationCacheAge;
}

/// A marker tap from the native map WebView. [index] is the position in the
/// rendered marker list, which can differ from the card list (search draws at
/// most 100 markers inside the viewport), so callers resolve [storeId].
typedef MobileMarkerClick = ({int index, String storeId});

/// Parses CLICK payloads such as {"index":3,"storeId":"abc"}, or a bare index
/// from an older page that has not been reloaded yet.
MobileMarkerClick? parseMobileMarkerClick(String payload) {
  final legacyIndex = int.tryParse(payload.trim());
  if (legacyIndex != null) return (index: legacyIndex, storeId: '');
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    final index = decoded['index'];
    if (index is! num || !index.isFinite || index != index.roundToDouble()) {
      return null;
    }
    final storeId = decoded['storeId'];
    return (index: index.toInt(), storeId: storeId is String ? storeId : '');
  } catch (_) {
    return null;
  }
}

/// Center and zoom level reported with native map bounds. A reloaded WebView
/// (for example after iOS ends its content process) starts from here.
typedef MobileMapViewport = ({double lat, double lng, int level});

MobileMapViewport? parseMobileMapViewport(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final lat = decoded['centerLat'];
    final lng = decoded['centerLng'];
    final level = decoded['level'];
    if (lat is! num || lng is! num || level is! num) return null;
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return (
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      level: level.toInt().clamp(1, 14),
    );
  } catch (_) {
    return null;
  }
}

/// Kakao WebView bounds can briefly be null or out of range while the map is
/// being relaid out. Ignore those transient messages instead of letting a
/// dynamic JSON value crash the marker request with an unchecked cast.
Map<String, double>? parseKakaoMapBounds(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    double? readNumber(String key) {
      final value = decoded[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final minLat = readNumber('minLat');
    final maxLat = readNumber('maxLat');
    final minLng = readNumber('minLng');
    final maxLng = readNumber('maxLng');
    final values = [minLat, maxLat, minLng, maxLng];
    if (values.any((value) => value == null || !value.isFinite)) {
      return null;
    }
    if (minLat! < -90 || maxLat! > 90 || minLat >= maxLat) return null;
    if (minLng! < -180 || maxLng! > 180 || minLng >= maxLng) return null;

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  } catch (_) {
    return null;
  }
}

typedef LocationSettingsLauncher = Future<bool> Function();

Future<bool> openLocationSettingsForStatus({
  required bool serviceDisabled,
  LocationSettingsLauncher? openLocationServices,
  LocationSettingsLauncher? openAppPermissions,
  LocationSettingsLauncher? openFallbackAppSettings,
}) async {
  final locationServicesLauncher =
      openLocationServices ?? Geolocator.openLocationSettings;
  final appPermissionsLauncher =
      openAppPermissions ?? Geolocator.openAppSettings;
  final fallbackLauncher =
      openFallbackAppSettings ?? permission_handler.openAppSettings;

  Future<bool> tryOpen(LocationSettingsLauncher launcher) async {
    try {
      return await launcher();
    } catch (_) {
      return false;
    }
  }

  if (serviceDisabled && await tryOpen(locationServicesLauncher)) return true;
  if (await tryOpen(appPermissionsLauncher)) return true;
  return tryOpen(fallbackLauncher);
}

class _StoreWithDistance {
  const _StoreWithDistance(this.store, this.distanceMeters);

  final Store store;
  final double? distanceMeters;
}

/// Horizontally swipeable store cards. The card wrapper intentionally claims
/// vertical drags only, leaving horizontal gestures to [PageView].
class HomeMapStoreCarousel extends StatelessWidget {
  const HomeMapStoreCarousel({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onPageChanged,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const ValueKey('home-store-card-pages'),
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (_) {},
          child: itemBuilder(context, index),
        ),
      ),
    );
  }
}

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({
    super.key,
    this.showAiSpotlight = false,
    this.initialRecommendation,
    this.initialSearchResult,
    this.storeLoader,
  });

  // `globalAllStores` is the current map/viewport result. It must not be used
  // as the nationwide search catalog: the bounds endpoint intentionally
  // returns only a subset of stores.
  static List<Store> globalAllStores = [];
  static List<Store> _globalSearchCatalog = [];

  /// Full nationwide catalog loaded by search (never a map-bounds response).
  static List<Store> get globalSearchCatalog => _globalSearchCatalog;

  static void setMapStores(List<Store> stores) {
    globalAllStores = stores;
  }

  static void setSearchCatalog(List<Store> stores) {
    _globalSearchCatalog = stores;
  }

  static Position? globalUserPosition;
  static bool hasRequestedLocationWeb = false;
  static bool hasDismissedLocationNotice = false;

  // A tab switch replaces this screen. The next one reopens the spot and the
  // store card the user left instead of jumping back to the user's position
  // (QA 10/7 #7). Store detail keeps this screen alive and needs neither.
  static MobileMapViewport? _savedViewport;
  static Store? _savedSelectedStore;

  @visibleForTesting
  static void clearSavedMapState() {
    _savedViewport = null;
    _savedSelectedStore = null;
  }

  final bool showAiSpotlight;
  final AiMapRecommendationResult? initialRecommendation;
  final Map<String, dynamic>? initialSearchResult;

  /// Loads stores for a map viewport. Defaults to the bounds endpoint.
  final HomeMapStoreLoader? storeLoader;

  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFFCBD5E1);
  static const fontFamily = 'Noto Sans KR';
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

  static int _nextMapInstance = 0;
  final String _viewId = 'kakao-map-${_nextMapInstance++}';
  late final Widget _webMapView;
  final String _kakaoJsKey = kakaoMapJavaScriptKey;
  bool _isMapInitialized = false;
  WebViewController? _webViewController;
  bool _isMapReady = false;
  String? _mapErrorMessage;
  Position? _pendingMapPosition;
  int? _pendingMapCenterGeneration;
  final _viewportPolicy = HomeMapViewportPolicy();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Position? _lastKnownPosition;
  List<Store> _allStores = [];
  bool _isAllStoresLoaded = false;
  bool _hasLoadError = false;
  bool _usingCachedStores = false;
  bool _hasFreshStoreResponse = false;
  List<Store> _currentStores = [];
  List<String> _renderedMarkerStoreIds = [];
  List<Store>? _searchResultStores;
  int _searchViewportCount = 0;
  Store? _selectedStore;
  bool _isFetching = false;
  String? _pendingBoundsJson;
  int _boundsRequestGeneration = 0;
  String _lastRenderedMarkerSignature = '';
  bool _isCenteringLocation = false;
  _LocationNoticeData? _locationNotice;
  Future<void>? _freshLocationRequest;
  final PageController _pageController = PageController(viewportFraction: 0.88);

  String _searchQuery = '';
  SearchFilter _searchFilter = const SearchFilter();
  bool _isAiRecommendationActive = false;
  List<Store> _aiRecommendedStores = [];
  AiMapRecommendationResult? _activeAiRecommendation;
  AiMapRecommendationResult? _pendingAiResult;
  Map<String, dynamic>? _pendingSearchResult;
  // Native map bookkeeping.
  MobileMapViewport? _lastMobileViewport;
  Timer? _markerTapGuard;
  double? _lastSentHeading;
  double? _pendingHeading;
  Timer? _headingThrottle;
  // Location tracking runs only while this route is visible in the foreground.
  bool _routeIsCurrent = true;
  bool _appInForeground = true;
  bool _trackingSuspended = false;
  bool _awaitingLocationSettingsReturn = false;
  // Non-blocking map notices are shown once per streak.
  bool _boundsFailureNoticeShown = false;
  bool _truncationNoticeShown = false;
  // The viewport whose stores are loading right now.
  String? _inFlightBoundsKey;
  int? _inFlightBoundsGeneration;
  // The viewport became the user's: they moved the map, chose a store or a
  // result was shown. Only then is it kept for the next home screen.
  bool _keepsViewport = false;
  // Where the previous home screen left the map. It opens there instead of
  // at the user's position.
  MobileMapViewport? _restoredViewport;

  Future<void> _openAiRecommend() async {
    // The server answers AI questions only for an account, so a guest is
    // asked before the chat opens instead of after the first question.
    final loggedIn = await requireLogin(
      context,
      message: 'AI 추천은 로그인 후 이용할 수 있어요.',
    );
    if (!loggedIn || !mounted) return;
    final result = await context.push<dynamic>(AppRoutes.aiRecommend);
    if (result is AiMapRecommendationResult && mounted) {
      _applyAiRecommendationResult(result);
    }
  }

  void _applyAiRecommendationResult(AiMapRecommendationResult result) {
    if (!_isMapReady) {
      _pendingAiResult = result;
      return;
    }

    List<Store> matchingStores = [];
    if (result.stores.isNotEmpty) {
      matchingStores = result.stores
          .where((store) => !store.isClosed && store.hasValidCoordinates)
          .toList();
    }
    if (matchingStores.isEmpty && result.storeIds.isNotEmpty) {
      matchingStores = _allStores
          .where(
            (store) =>
                store.hasValidCoordinates && result.storeIds.contains(store.id),
          )
          .toList();
    }

    if (matchingStores.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          HowmuchSnackBar(
            content: Text('지도에 표시할 매장 위치 정보를 찾을 수 없어요.'),
            aboveNavigation: true,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _invalidatePendingMapRequest();
    _setMapSearchMode(false);
    _keepViewport();

    setState(() {
      _isAiRecommendationActive = true;
      // The AI result replaces any search. Its query and filters no longer
      // describe the cards and must not filter the map once AI is cleared.
      _searchQuery = '';
      _searchFilter = const SearchFilter();
      _searchResultStores = null;
      _searchViewportCount = 0;
      _activeAiRecommendation = result;
      _aiRecommendedStores = matchingStores;
      _currentStores = matchingStores;
      _selectedStore = matchingStores.first;
      _showStoreSummary = true;
    });
    _resetStoreCarouselToFirst();

    _renderMarkers(
      matchingStores
          .map((store) => _storeMarker(store, result.selectionFor(store)))
          .toList(),
    );
    // The AI screen is still covering home when its result arrives. The web
    // bridge keeps this move until the map is visible again (P1-19).
    _panMapTo(matchingStores.first);
  }

  void _clearAiRecommendation() {
    _invalidatePendingMapRequest();
    _lastRenderedMarkerSignature = '';
    setState(() {
      _isAiRecommendationActive = false;
      _activeAiRecommendation = null;
      _aiRecommendedStores = [];
      // The next viewport response replaces the AI cards and markers.
      _currentStores = const [];
      _showStoreSummary = false;
      _selectedStore = null;
    });
    _resetStoreCarouselToFirst();
    _setMapSearchMode(false);
    _searchInCurrentArea();
  }

  Map<String, dynamic> _storeMarker(
    Store store,
    RecommendationMenuSelection? selection,
  ) {
    // A selected menu with an unknown price must not borrow another menu's price.
    final price = selection == null ? store.price1 : selection.price;
    return {
      'storeId': _mapStoreKey(store),
      'lat': store.latitude,
      'lng': store.longitude,
      'title': store.storeName,
      'menu': selection?.menu.isNotEmpty == true
          ? selection!.menu
          : (store.menu1.isNotEmpty ? store.menu1 : store.industry),
      'price': formatMenuPrice(price, free: selection?.free ?? store.free1),
      'source': store.source,
      'selected':
          _selectedStore != null &&
          (_selectedStore!.id.isNotEmpty
              ? _selectedStore!.id == store.id
              : identical(_selectedStore, store)),
    };
  }

  String _mapStoreKey(Store store) => store.id.isNotEmpty
      ? store.id
      : '${store.storeName}|${store.latitude}|${store.longitude}';

  RecommendationMenuSelection? _selectionFor(Store store) =>
      _activeAiRecommendation?.selectionFor(store);

  RecommendationMenuSelection? _searchSelectionFor(Store store) {
    final menu = SearchFilterPolicy.displayMenuFor(store, _searchQuery);
    if (menu == null) return null;
    return RecommendationMenuSelection(
      storeId: store.id,
      storeName: store.storeName,
      menu: menu.name,
      price: menu.price,
      free: store.freeAt(menu.index),
    );
  }

  Future<void> _openSearch({bool openFilter = false}) async {
    final result = await context.push<Map<String, dynamic>>(
      AppRoutes.searchResult,
      extra: {
        'query': _searchQuery,
        'openFilter': openFilter,
        'filter': _searchFilter,
        // Search pops its result back to this map instead of opening a new one.
        'returnToMap': true,
      },
    );

    if (mounted && result != null) _applySearchResult(result);
  }

  void _applySearchResult(Map<String, dynamic> result) {
    if (!mounted) return;
    if (!_isMapReady) {
      _pendingSearchResult = result;
      return;
    }
    _keepViewport();
    setState(() {
      _isAiRecommendationActive = false;
      _activeAiRecommendation = null;
      _aiRecommendedStores = [];
      _searchQuery = result['query'] as String? ?? _searchQuery;
      _searchFilter = result['filter'] as SearchFilter? ?? _searchFilter;
      final stores = result['stores'];
      _searchResultStores = stores is List<Store>
          ? List.unmodifiable(stores)
          : null;
      // The map route can still be offstage while a pushed search route is
      // popping. Its delayed bounds callback must not leave unrelated cards
      // visible in the meantime.
      if (_searchResultStores != null) {
        _currentStores = _searchResultStores!;
        _searchViewportCount = 0;
      }
      _selectedStore = null;
      _showStoreSummary = false;
    });
    _invalidatePendingMapRequest();
    _setMapSearchMode(_searchResultStores != null);
    _resetStoreCarouselToFirst();
    final validStores =
        _searchResultStores
            ?.where((store) => store.hasValidCoordinates)
            .toList() ??
        const <Store>[];
    if (validStores.isNotEmpty) {
      final points = jsonEncode(
        validStores
            .map((store) => {'lat': store.latitude, 'lng': store.longitude})
            .toList(),
      );
      if (kIsWeb) {
        web_helper.fitKakaoMapStoresWeb(_viewId, points);
      } else {
        _safeRunJavaScript('fitMapStores(${jsonEncode(points)});');
      }
    }
    _searchInCurrentArea();
  }

  Timer? _boundsDebouncer;
  Timer? _webBoundsRetryTimer;
  int _webBoundsRetryCount = 0;
  int _suppressMarkerClicksUntil = 0;

  void _refreshTransferredSearchResults() {
    if (_searchResultStores == null) return;
    if (_searchQuery.isEmpty && _searchFilter.activeLabels.isEmpty) {
      _searchResultStores = null;
      _setMapSearchMode(false);
      return;
    }
    final distanceLimit = switch (_searchFilter.distance) {
      '500m 이내' => 500,
      '1km 이내' => 1000,
      '3km 이내' => 3000,
      _ => null,
    };
    final results = HomeMapScreen.globalSearchCatalog.where((store) {
      if (store.isClosed) return false;
      if (_searchQuery.isNotEmpty &&
          !SearchFilterPolicy.matchesQuery(store, _searchQuery)) {
        return false;
      }
      if (_searchFilter.maxPrice != null &&
          !SearchFilterPolicy.matchesMaxPrice(
            store,
            _searchFilter.maxPrice!,
            query: _searchQuery,
          )) {
        return false;
      }
      if (_searchFilter.industries.isNotEmpty &&
          !_searchFilter.industries.any(
            (industry) => SearchFilter.matchesIndustry(store, industry),
          )) {
        return false;
      }
      if (_searchFilter.govCertified && store.source != 'GOV') return false;
      if (!_searchFilter.govCertified &&
          !_searchFilter.userReported &&
          store.source == 'USER') {
        return false;
      }
      if (distanceLimit != null &&
          (_distanceFromUser(store) ?? double.infinity) > distanceLimit) {
        return false;
      }
      return true;
    }).toList();
    if (_searchFilter.sortOrder == '저렴한순') {
      results.sort(
        (a, b) => SearchFilterPolicy.compareByPrice(
          a,
          b,
          query: _searchQuery,
          distanceOf: _priceTieDistance,
        ),
      );
    } else {
      results.sort(
        (a, b) => (_distanceFromUser(a) ?? double.infinity).compareTo(
          _distanceFromUser(b) ?? double.infinity,
        ),
      );
    }
    _searchResultStores = results;
  }

  void _onWebMapIdle() {
    _webBoundsRetryTimer?.cancel();
    _webBoundsRetryCount = 0;
    unawaited(_searchInCurrentArea());
  }

  /// The user dragged or zoomed the map (or a result zoomed it).
  void _onMapMoveStart() {
    _keepViewport();
    _invalidatePendingMapRequest();
  }

  /// From now on the viewport is the user's choice. Keep it for the next home
  /// screen, starting with the viewport shown right now.
  void _keepViewport() {
    if (_keepsViewport) return;
    _keepsViewport = true;
    _rememberViewport(_currentViewport());
  }

  MobileMapViewport? _currentViewport() {
    if (!kIsWeb) return _lastMobileViewport;
    final boundsJson = web_helper.getKakaoMapBoundsWeb(_viewId);
    return boundsJson == null ? null : parseMobileMapViewport(boundsJson);
  }

  /// Keeps the latest viewport for the next home screen once it is the
  /// user's. Search can zoom out past the plain map's limit; such a view is
  /// not kept because the plain map cannot show it.
  void _rememberViewport(MobileMapViewport? viewport) {
    if (viewport == null || !_keepsViewport) return;
    if (viewport.level > maxHomeMapLevel) return;
    HomeMapScreen._savedViewport = viewport;
  }

  void _invalidatePendingMapRequest() {
    _viewportPolicy.invalidate();
    _pendingMapCenterGeneration = null;
    _boundsRequestGeneration++;
    _pendingBoundsJson = null;
    _webBoundsRetryTimer?.cancel();
  }

  void _scheduleWebBoundsRetry() {
    if (!mounted || _webBoundsRetryCount >= 5) return;
    _webBoundsRetryCount++;
    _webBoundsRetryTimer?.cancel();
    _webBoundsRetryTimer = Timer(
      Duration(milliseconds: 120 * _webBoundsRetryCount),
      () {
        if (mounted) unawaited(_searchInCurrentArea());
      },
    );
  }

  void _suppressMarkerClicks([
    Duration duration = const Duration(milliseconds: 700),
  ]) {
    _suppressMarkerClicksUntil =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    if (kIsWeb) {
      web_helper.suppressMarkerClicksWeb(_viewId, duration.inMilliseconds);
    }
  }

  void _onMarkerClicked(int index) {
    if (!mounted) return;
    if (_isCenteringLocation ||
        DateTime.now().millisecondsSinceEpoch < _suppressMarkerClicksUntil) {
      // The map raised the tapped marker before asking. Put the highlight
      // back on the store that is actually selected.
      _restoreMarkerHighlight();
      return;
    }
    if (index == -1) {
      setState(() {
        _showStoreSummary = false;
        _selectedStore = null;
      });
      _highlightMapMarker(-1);
    } else if (index >= 0 && index < _currentStores.length) {
      _viewportPolicy.invalidate();
      final store = _currentStores[index];
      _keepViewport();
      setState(() {
        _selectedStore = store;
        _showStoreSummary = true;
      });
      _highlightMapMarker(index);

      final hasStoreCarousel =
          _isAiRecommendationActive ||
          _searchQuery.trim().isNotEmpty ||
          _searchFilter.activeLabels.isNotEmpty;
      final currentPage = _pageController.hasClients
          ? _pageController.page?.round()
          : null;
      if (hasStoreCarousel &&
          _pageController.hasClients &&
          currentPage != index) {
        if (currentPage == null || (index - currentPage).abs() > 1) {
          // Animating across several cards reports every card in between,
          // and each report would pan the map to that store.
          _pageController.jumpToPage(index);
        } else {
          unawaited(
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      }
    } else {
      _restoreMarkerHighlight();
    }
  }

  /// Resolves a tapped marker to its card. Markers can be a subset of the
  /// cards (search draws at most 100 inside the viewport), so the store ID,
  /// not the marker position, identifies the store.
  void _onRenderedMarkerClicked(int markerIndex, String storeId) {
    if (!mounted) return;
    if (markerIndex < 0) {
      _onMarkerClicked(-1);
      return;
    }
    var key = storeId;
    if (key.isEmpty && markerIndex < _renderedMarkerStoreIds.length) {
      key = _renderedMarkerStoreIds[markerIndex];
    }
    final storeIndex = key.isEmpty
        ? -1
        : _currentStores.indexWhere((store) => _mapStoreKey(store) == key);
    if (storeIndex < 0) {
      _restoreMarkerHighlight();
      return;
    }
    _onMarkerClicked(storeIndex);
  }

  /// Card index to the index in the marker list last sent to the map, or -1.
  int _renderedMarkerIndexOf(int storeIndex) {
    if (storeIndex < 0 || storeIndex >= _currentStores.length) return -1;
    return _renderedMarkerStoreIds.indexOf(
      _mapStoreKey(_currentStores[storeIndex]),
    );
  }

  void _highlightMapMarker(int index) {
    final markerIndex = _renderedMarkerIndexOf(index);
    if (kIsWeb) {
      web_helper.highlightKakaoMapMarkerWeb(_viewId, markerIndex);
    } else {
      _safeRunJavaScript('highlightMarker($markerIndex);');
    }
  }

  void _restoreMarkerHighlight() {
    final selected = _selectedStore;
    final selectedKey = selected == null ? null : _mapStoreKey(selected);
    _highlightMapMarker(
      selectedKey == null
          ? -1
          : _currentStores.indexWhere(
              (store) => _mapStoreKey(store) == selectedKey,
            ),
    );
  }

  void _renderMarkers(List<Map<String, dynamic>> markerList) {
    _renderedMarkerStoreIds = markerList
        .map((marker) => marker['storeId'] as String)
        .toList(growable: false);
    _lastRenderedMarkerSignature = _markerListSignature(markerList);
    final markersJson = jsonEncode(markerList);
    if (kIsWeb) {
      web_helper.addMobileMarkersWeb(_viewId, markersJson);
    } else {
      _safeRunJavaScript('addMobileMarkers(${jsonEncode(markersJson)});');
    }
  }

  /// Search results may span the country (zoom limit 14); the normal map
  /// stays inside the bounds endpoint's span (10).
  void _setMapSearchMode(bool enabled) {
    if (kIsWeb) {
      web_helper.setKakaoMapSearchModeWeb(_viewId, enabled);
    } else {
      _safeRunJavaScript('setSearchMode($enabled);');
    }
  }

  void _panMapTo(Store store) {
    if (!store.hasValidCoordinates) return;
    if (kIsWeb) {
      web_helper.setKakaoMapCenterFromSwipeWeb(
        _viewId,
        store.latitude,
        store.longitude,
      );
    } else {
      _safeRunJavaScript(
        'setMapCenterFromSwipe(${store.latitude}, ${store.longitude});',
      );
    }
  }

  void _centerMapOnStore(Store store, int index) {
    if (!store.hasValidCoordinates) return;
    _viewportPolicy.invalidate();
    _panMapTo(store);
    _highlightMapMarker(index);
  }

  void _onStorePageChanged(int index) {
    if (index < 0 || index >= _currentStores.length) return;
    final store = _currentStores[index];
    _keepViewport();
    if (!identical(_selectedStore, store)) {
      setState(() => _selectedStore = store);
    }
    _centerMapOnStore(store, index);
  }

  void _resetStoreCarouselToFirst() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_pageController.page?.round() != 0) {
        _pageController.jumpToPage(0);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pendingAiResult = widget.initialRecommendation;
    _pendingSearchResult = widget.initialSearchResult;
    // A result handed over by another screen moves the map itself.
    if (_pendingAiResult == null && _pendingSearchResult == null) {
      final viewport = HomeMapScreen._savedViewport;
      if (viewport != null) {
        _restoredViewport = viewport;
        _keepsViewport = true;
        final selected = HomeMapScreen._savedSelectedStore;
        if (selected != null) {
          _selectedStore = selected;
          _showStoreSummary = true;
        }
      }
    }
    unawaited(_restoreCachedStores());
    WidgetsBinding.instance.addObserver(this); // 앱 생명주기 감지 등록
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _prepareInitialLocation(initial: true),
    );
    if (kIsWeb) {
      web_helper.registerKakaoWebViewFactory(_viewId);
      _webMapView = HtmlElementView(
        key: ValueKey(_viewId),
        viewType: web_helper.kakaoWebViewType,
        creationParams: _viewId,
      );
      web_helper.registerWebCallbacks(
        _viewId,
        _onWebMapIdle,
        _onMapMoveStart,
        _onRenderedMarkerClicked,
        _onMapReady,
        _onMapError,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _initWebMap());
    } else {
      _initMobileController();
    }
  }

  Future<void> _restoreCachedStores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(homeMapStoreCacheKey);
      final cached = decodeHomeMapStoreCache(raw);
      if (cached.isEmpty || !mounted || _hasFreshStoreResponse) return;
      setState(() {
        _allStores = cached;
        HomeMapScreen.setMapStores(List<Store>.unmodifiable(cached));
        _isAllStoresLoaded = true;
        _usingCachedStores = true;
      });
      if (_isMapReady) {
        _searchInCurrentArea();
      }
    } catch (error) {
      debugPrint('저장된 매장 캐시 복원 실패: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      _syncLocationTracking();
      _relayoutMobileMap();
      if (_awaitingLocationSettingsReturn) {
        // Coming back from location settings is a request to use them now,
        // including moving the map to the newly available position.
        _awaitingLocationSettingsReturn = false;
        unawaited(_moveToCurrentLocation());
      } else {
        _prepareInitialLocation();
      }
    } else if (state == AppLifecycleState.paused) {
      _appInForeground = false;
      _syncLocationTracking();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A pushed screen covers this map; it does not need GPS fixes or compass
    // headings drawn while hidden.
    final routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (routeIsCurrent != _routeIsCurrent) {
      _routeIsCurrent = routeIsCurrent;
      _syncLocationTracking();
    }
  }

  void _syncLocationTracking() {
    final active = _routeIsCurrent && _appInForeground;
    if (kIsWeb) {
      // Restarting a browser location watch can ask for permission again
      // (Safari "Ask"). Keep the watch and ignore updates while hidden.
      final subscription = _positionStream;
      if (subscription == null) return;
      if (active && subscription.isPaused) {
        subscription.resume();
      } else if (!active && !subscription.isPaused) {
        subscription.pause();
      }
      return;
    }
    if (active) {
      if (_trackingSuspended) {
        _trackingSuspended = false;
        _startLocationTracking();
      }
      return;
    }
    // Cancel rather than pause: a paused listener keeps the platform's GPS
    // and compass running. Both start again when the map is visible.
    if (_positionStream == null && _compassStream == null) return;
    _positionStream?.cancel();
    _compassStream?.cancel();
    _positionStream = null;
    _compassStream = null;
    _trackingSuspended = true;
  }

  @override
  void dispose() {
    HomeMapScreen._savedSelectedStore = _showStoreSummary
        ? _selectedStore
        : null;
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _compassStream?.cancel();
    _pageController.dispose();
    _boundsDebouncer?.cancel();
    _webBoundsRetryTimer?.cancel();
    _markerTapGuard?.cancel();
    _headingThrottle?.cancel();
    if (kIsWeb) {
      web_helper.disposeKakaoWebMap(_viewId);
    }
    super.dispose();
  }

  void _initMobileController() {
    final viewport = _restoredViewport;
    _lastMobileViewport = viewport;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(onWebResourceError: _onMobileMapResourceError),
      )
      ..addJavaScriptChannel(
        'Print',
        onMessageReceived: (JavaScriptMessage message) =>
            _onMobileMapMessage(message.message),
      )
      ..loadHtmlString(
        viewport == null
            ? _getMobileMapHtml()
            : _getMobileMapHtml(
                initialLat: viewport.lat,
                initialLng: viewport.lng,
                initialLevel: viewport.level,
              ),
        baseUrl: kakaoMapAuthorizedOrigin,
      );
  }

  void _onMobileMapMessage(String message) {
    if (!mounted) return;
    if (message == 'Map Initialized on Mobile') {
      _onMapReady();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _relayoutMobileMap();
      });
    } else if (message.startsWith('MAP_ERROR:')) {
      _onMapError(message.substring('MAP_ERROR:'.length));
    } else if (message.startsWith('BOUNDS:')) {
      final boundsJson = message.substring('BOUNDS:'.length);
      final viewport = parseMobileMapViewport(boundsJson);
      _lastMobileViewport = viewport ?? _lastMobileViewport;
      _rememberViewport(viewport);
      _boundsDebouncer?.cancel();
      _boundsDebouncer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) unawaited(_fetchAndAddLatestMarkers(boundsJson));
      });
    } else if (message == 'MOVE_START') {
      _onMapMoveStart();
    } else if (message.startsWith('CLICK:')) {
      final click = parseMobileMarkerClick(message.substring('CLICK:'.length));
      if (click == null) return;
      _markerTapGuard?.cancel();
      _markerTapGuard = Timer(const Duration(milliseconds: 400), () {
        _markerTapGuard = null;
      });
      _onRenderedMarkerClicked(click.index, click.storeId);
    } else if (message == 'MAP_CLICK') {
      // A marker tap can also reach the map as a background tap. It must not
      // close the card that the marker has just opened.
      final guard = _markerTapGuard;
      if (guard != null && guard.isActive) {
        guard.cancel();
        _markerTapGuard = null;
        return;
      }
      // So can a tap on a card or button drawn over the map (QA 10/7 #32).
      if (DateTime.now().millisecondsSinceEpoch < _suppressMarkerClicksUntil) {
        return;
      }
      _hideStore();
    } else {
      debugPrint('WebView: $message');
    }
  }

  void _onMobileMapResourceError(WebResourceError error) {
    // iOS can end the WebView content process under memory pressure, which
    // leaves a blank map. Reload the page at the last viewport.
    if (error.errorType != WebResourceErrorType.webContentProcessTerminated) {
      return;
    }
    _reloadMobileMap();
  }

  void _reloadMobileMap() {
    final controller = _webViewController;
    if (!mounted || kIsWeb || controller == null) return;
    _isMapReady = false;
    _lastRenderedMarkerSignature = '';
    _renderedMarkerStoreIds = const [];
    final viewport = _lastMobileViewport;
    final html = viewport == null
        ? _getMobileMapHtml()
        : _getMobileMapHtml(
            initialLat: viewport.lat,
            initialLng: viewport.lng,
            initialLevel: viewport.level,
          );
    unawaited(
      controller
          .loadHtmlString(html, baseUrl: kakaoMapAuthorizedOrigin)
          .onError(
            (Object error, StackTrace stackTrace) =>
                debugPrint('지도 다시 불러오기 실패: $error'),
          ),
    );
  }

  String _getMobileMapHtml({
    double initialLat = 37.5665,
    double initialLng = 126.9780,
    int initialLevel = 3,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
        #kakao-map-container { width: 100%; height: 100%; }
        .kakao-map-marker:focus-visible {
          outline: 3px solid #0F172A;
          outline-offset: 3px;
        }
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
      <script>
        // Defined before the SDK tag so its onerror handler can always report.
        function reportMapError(message) {
          if (window.Print && typeof Print.postMessage === 'function') {
            Print.postMessage('MAP_ERROR:' + message);
          }
        }
      </script>
      <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$_kakaoJsKey&libraries=services,clusterer" onerror="reportMapError('카카오맵 SDK를 불러오지 못했어요.')"></script>
    </head>
    <body>
      <div id="kakao-map-container" aria-label="매장 지도"></div>
      <script>
        var map;
        var userLocationOverlay;
        var boundsTimer = null;
        // When the pan and zoom started by a card swipe or marker tap end.
        var cardMoveEndsAt = 0;
        // Search results are filtered locally and may span the country. The
        // normal map stays within the bounds endpoint's 10-degree span.
        var searchMode = false;

        function maxMapLevel() {
          return searchMode ? 14 : 10;
        }

        function setSearchMode(enabled) {
          searchMode = enabled === true;
          if (!map) return;
          map.setMaxLevel(maxMapLevel());
          // Leaving a zoomed-out search: return inside the supported span.
          if (map.getLevel() > maxMapLevel()) map.setLevel(maxMapLevel());
        }

        function relayoutMap() {
          if (!map) return;
          var center = map.getCenter();
          map.relayout();
          map.setCenter(center);
          setTimeout(requestBounds, 100);
        }

        var mapInitAttempts = 0;

        function initializeMap() {
          if (typeof kakao === 'undefined' || !kakao.maps) {
            mapInitAttempts += 1;
            if (mapInitAttempts >= 25) {
              reportMapError('지도를 불러오지 못했어요. 네트워크와 지도 설정을 확인해주세요.');
              return;
            }
            setTimeout(initializeMap, 200);
            return;
          }
          try {
          var container = document.getElementById('kakao-map-container');
          var options = { center: new kakao.maps.LatLng($initialLat, $initialLng), level: $initialLevel };
          map = new kakao.maps.Map(container, options);
          map.setMaxLevel(maxMapLevel());

          kakao.maps.event.addListener(map, 'idle', function() {
            if (boundsTimer) clearTimeout(boundsTimer);
            // Report the viewport after that move ends instead of dropping
            // it: the search count must follow the zoomed map (QA 10/7 #30).
            var wait = Math.max(600, cardMoveEndsAt - Date.now() + 100);
            boundsTimer = setTimeout(function() {
              requestBounds();
            }, wait);
          });
          kakao.maps.event.addListener(map, 'dragstart', function() {
            Print.postMessage('MOVE_START');
          });
          kakao.maps.event.addListener(map, 'zoom_start', function() {
            Print.postMessage('MOVE_START');
          });

          kakao.maps.event.addListener(map, 'click', function(mouseEvent) {
            Print.postMessage('MAP_CLICK');
          });

          Print.postMessage("Map Initialized on Mobile");
          setTimeout(relayoutMap, 0);
          setTimeout(relayoutMap, 250);
          setTimeout(requestBounds, 500);
          } catch (error) {
            reportMapError('지도 화면을 준비하지 못했어요. 잠시 후 다시 시도해주세요.');
          }
        }

        window.onload = function() {
          initializeMap();
        };

        window.addEventListener('resize', relayoutMap);
        window.addEventListener('pageshow', relayoutMap);

        var customOverlays = [];
        var markerDataCache = [];
        var selectedMarkerIndex = -1;

        // Flutter resolves the store by its ID: markers can be a subset of the
        // cards, so the marker position alone is not a card position.
        function onMarkerClick(index) {
          var item = markerDataCache[index] || {};
          highlightMarker(index);
          Print.postMessage('CLICK:' + JSON.stringify({
            index: index,
            storeId: String(item.storeId || '')
          }));
        }

        function addMobileMarkers(markerListJson) {
          var markerData = JSON.parse(markerListJson);
          markerDataCache = markerData;
          selectedMarkerIndex = markerData.findIndex(function(item) {
            return item.selected === true;
          });

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
              bubble.className = 'kakao-map-marker';
              bubble.setAttribute('role', 'button');
              bubble.setAttribute('tabindex', '0');
              bubble.setAttribute('aria-label', item.title + ', ' + item.menu + ', ' + item.price);
              bubble.setAttribute('aria-pressed', 'false');
              var bgColor = item.source === 'USER' ? '#F97316' : '#2563EB';
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
              bubble.onclick = function(event) {
                // A marker tap must not also reach the map as a background tap.
                if (event && typeof event.stopPropagation === 'function') event.stopPropagation();
                onMarkerClick(idx);
              };
              bubble.onkeydown = function(event) {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault();
                  bubble.onclick(event);
                }
              };
              wrapper.appendChild(bubble);
              wrapper.appendChild(tail);

              var customOverlay = new kakao.maps.CustomOverlay({
                  position: new kakao.maps.LatLng(item.lat, item.lng),
                  content: wrapper,
                  yAnchor: 1.0,
                  zIndex: idx === selectedMarkerIndex ? 10 : 3
              });
              customOverlay.setMap(map);
              customOverlays.push(customOverlay);
            })(i);
          }
          highlightMarker(selectedMarkerIndex);
          Print.postMessage('Markers added: ' + markerData.length);
        }

        function highlightMarker(selectedIndex) {
          selectedMarkerIndex = Number.isInteger(selectedIndex) ? selectedIndex : -1;
          for (var i = 0; i < markerDataCache.length; i++) {
            var wrapper = document.getElementById('marker-wrapper-' + i);
            if (!wrapper) continue;
            var bubble = wrapper.children[0];
            var tail = wrapper.children[1];

            var isSelected = i === selectedMarkerIndex;
            var baseColor = markerDataCache[i].source === 'USER' ? '#F97316' : '#2563EB';
            bubble.setAttribute('aria-pressed', isSelected ? 'true' : 'false');
            if (isSelected) {
              bubble.style.background = '#C2410C'; // Selected
              tail.style.borderTopColor = '#C2410C';
              wrapper.style.transform = 'scale(1.2)';
              if (customOverlays[i]) customOverlays[i].setZIndex(10);
            } else {
              bubble.style.background = baseColor;
              tail.style.borderTopColor = baseColor;
              wrapper.style.transform = 'scale(1.0)';
              if (customOverlays[i]) customOverlays[i].setZIndex(3);
            }
          }
        }

        function setMapCenter(lat, lng) {
          if (map) {
            var moveLatLon = new kakao.maps.LatLng(lat, lng);
            map.setCenter(moveLatLon);
            if (map.getLevel() !== 3) {
              map.setLevel(3);
            }
          }
        }

        function setMapCenterFromSwipe(lat, lng) {
          if (map) {
            cardMoveEndsAt = Date.now() + 1000;
            var moveLatLon = new kakao.maps.LatLng(lat, lng);
            map.panTo(moveLatLon);
            if (map.getLevel() !== 3) {
              setTimeout(function() {
                map.setLevel(3, {animate: { duration: 300 }});
              }, 400);
            }
          }
        }

        // Search fits keep the top search bar and the bottom cards clear.
        // Short screens scale that padding down so it never exceeds the map.
        function fitPadding() {
          var container = document.getElementById('kakao-map-container');
          var width = container && container.offsetWidth > 0 ? container.offsetWidth : 360;
          var height = container && container.offsetHeight > 0 ? container.offsetHeight : 640;
          var verticalScale = Math.min(1, (height * 0.7) / 410);
          var sideScale = Math.min(1, (width * 0.5) / 80);
          return [
            Math.round(150 * verticalScale),
            Math.round(40 * sideScale),
            Math.round(260 * verticalScale),
            Math.round(40 * sideScale)
          ];
        }

        function fitMapStores(coordinatesJson) {
          if (!map) return;
          var points = JSON.parse(coordinatesJson);
          if (!points.length) return;
          map.setMaxLevel(maxMapLevel());
          if (points.length === 1) {
            map.setCenter(new kakao.maps.LatLng(points[0].lat, points[0].lng));
            map.setLevel(4);
          } else {
            var bounds = new kakao.maps.LatLngBounds();
            points.forEach(function(point) { bounds.extend(new kakao.maps.LatLng(point.lat, point.lng)); });
            var padding = fitPadding();
            map.setBounds(bounds, padding[0], padding[1], padding[2], padding[3]);
          }
          requestBounds();
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
          var values = [sw.getLat(), ne.getLat(), sw.getLng(), ne.getLng()];
          if (!values.every(Number.isFinite) ||
              values[0] < -90 || values[1] > 90 || values[0] >= values[1] ||
              values[2] < -180 || values[3] > 180 || values[2] >= values[3]) {
            return;
          }
          // Outside search, the backend accepts at most a 10-degree span.
          if (!searchMode && (values[1] - values[0] > 10 || values[3] - values[2] > 10)) {
            return;
          }
          var center = map.getCenter();
          var boundsData = JSON.stringify({
            minLat: values[0], maxLat: values[1],
            minLng: values[2], maxLng: values[3],
            centerLat: center.getLat(), centerLng: center.getLng(),
            level: map.getLevel()
          });
          Print.postMessage('BOUNDS:' + boundsData);
        }
      </script>
    </body>
    </html>
    ''';
  }

  void _initWebMap() {
    if (!mounted) return;
    try {
      // index.html의 SDK 로더가 준비되지 않았으면 JS 측 짧은 재시도가
      // 이어진다. 고정 대기 없이 플랫폼 뷰가 생긴 즉시 초기화를 요청한다.
      final viewport = _restoredViewport;
      if (viewport == null) {
        web_helper.initKakaoWebMap(_viewId);
      } else {
        web_helper.initKakaoWebMap(
          _viewId,
          lat: viewport.lat,
          lng: viewport.lng,
          level: viewport.level,
        );
      }
    } catch (e) {
      debugPrint('지도 초기화 에러: $e');
    }
  }

  Future<void> _prepareInitialLocation({bool initial = false}) async {
    final centerGeneration = initial
        ? _viewportPolicy.claimInitialCenter(
            hasDestination:
                _pendingAiResult != null ||
                _pendingSearchResult != null ||
                _activeAiRecommendation != null ||
                _searchResultStores != null ||
                _selectedStore != null ||
                _restoredViewport != null,
          )
        : null;
    final requestInitialPermission = initial && centerGeneration != null;
    if (!kIsWeb) {
      await _moveToCurrentLocation(
        centerGeneration: centerGeneration,
        passive: true,
        requestPermission: requestInitialPermission,
      );
      return;
    }

    // 이미 위치를 성공적으로 획득했거나 이전에 위치 권한을 수락한 상태라면
    // 탭 복귀 시 안내 모달을 띄우지 않고 조용히 현재 위치로 이동/갱신한다.
    if (HomeMapScreen.globalUserPosition != null ||
        HomeMapScreen.hasRequestedLocationWeb) {
      await _moveToCurrentLocation(
        centerGeneration: centerGeneration,
        passive: true,
        requestPermission: false,
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('web_location_granted') == true) {
        HomeMapScreen.hasRequestedLocationWeb = true;
        await _moveToCurrentLocation(
          centerGeneration: centerGeneration,
          passive: true,
          requestPermission: false,
        );
        return;
      }
    } catch (_) {}

    // 사용자가 '나중에 할게요'로 닫은 경우 홈 탭으로 복귀할 때마다 재노출하지 않는다.
    if (HomeMapScreen.hasDismissedLocationNotice) return;

    // Passive entry/resume may reuse a grant, but a new browser prompt must
    // start from the user's button tap, not an asynchronous lifecycle callback.
    var permission = LocationPermission.unableToDetermine;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      // Older Safari versions do not expose the geolocation Permissions API.
    }
    if (!mounted || _isCenteringLocation) return;
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await _moveToCurrentLocation(
        centerGeneration: centerGeneration,
        passive: true,
        requestPermission: false,
      );
    } else if (initial && _locationNotice == null) {
      _showLocationNotice(
        _webLocationPermissionNotice(
          title: '내 주변 매장을 찾아볼까요?',
          message: "아래 버튼을 누른 뒤 브라우저의\n위치 접근 요청에서 '허용'을 선택해 주세요.",
          primaryLabel: '위치 허용 요청',
          icon: Icons.my_location_rounded,
        ),
      );
    }
  }

  Future<void> _moveToCurrentLocation({
    int? centerGeneration,
    bool passive = false,
    bool requestPermission = true,
  }) async {
    if (_isCenteringLocation) return;
    final viewportGeneration = passive
        ? centerGeneration
        : _viewportPolicy.beginExplicitCenter();
    if (!passive) _suppressMarkerClicks(const Duration(milliseconds: 1200));
    final showFailureNotice = !passive || requestPermission;
    if (mounted && !passive) {
      setState(() {
        _isCenteringLocation = true;
        _locationNotice = null;
      });
    }

    try {
      if (kIsWeb) {
        // Keep this before any await so Safari receives the original tap.
        final position = await requestBrowserLocation();
        HomeMapScreen.hasRequestedLocationWeb = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('web_location_granted', true);
        } catch (_) {}
        if (!mounted) return;
        _storeUserPosition(position);
        if (viewportGeneration != null &&
            _viewportPolicy.canApply(viewportGeneration)) {
          _centerMapOnPosition(position, generation: viewportGeneration);
        }
        _startLocationTracking();
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && showFailureNotice) {
          _showLocationNotice(
            _LocationNoticeData(
              title: '위치 서비스를 켜주세요',
              message: '주변 가성비 식당을 찾으려면\n기기의 위치 서비스가 필요해요.',
              primaryLabel: '설정 열기',
              onPrimaryPressed: () =>
                  _openLocationSettings(serviceDisabled: true),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestPermission) return;
        permission = await Geolocator.requestPermission();
        // The permission dialog can outlive this screen.
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationNotice(
              const _LocationNoticeData(
                title: '위치 권한이 필요해요',
                message: '내 위치 주변의 매장을 보여드리려면\n위치 권한을 허용해주세요.',
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && showFailureNotice) {
          _showLocationNotice(
            _LocationNoticeData(
              title: '위치 권한이 꺼져 있어요',
              message: '설정에서 위치 권한을 허용하면\n내 주변 매장을 바로 찾을 수 있어요.',
              primaryLabel: '설정 열기',
              onPrimaryPressed: () =>
                  _openLocationSettings(serviceDisabled: false),
            ),
          );
        }
        return;
      }

      _startLocationTracking();

      // 이미 확보한 좌표나 OS 캐시를 먼저 사용해 지도 이동을 즉시 반응시킵니다.
      Position? lastKnown = _lastKnownPosition;
      if (lastKnown == null) {
        try {
          lastKnown = await Geolocator.getLastKnownPosition();
        } catch (_) {
          debugPrint('마지막 위치 조회 실패');
        }
      }

      if (lastKnown != null &&
          isFreshHomeLocation(lastKnown.timestamp, DateTime.now())) {
        _storeUserPosition(lastKnown);
        if (viewportGeneration != null &&
            _viewportPolicy.canApply(viewportGeneration)) {
          _centerMapOnPosition(lastKnown, generation: viewportGeneration);
        }
        _refreshCurrentPositionInBackground(
          centerGeneration: viewportGeneration,
        );
        return;
      }

      // Indoors a fresh fix can time out. An older fix still centers the map
      // near the user, and the tracking stream corrects it once GPS recovers.
      final position = await _getFreshPosition() ?? lastKnown;
      if (!mounted) return;
      if (position == null) {
        if (showFailureNotice) {
          _showLocationNotice(
            _LocationNoticeData(
              title: '현재 위치를 찾지 못했어요',
              message: '잠시 후 다시 시도하거나\n네트워크 상태를 확인해주세요.',
              primaryLabel: '다시 시도',
              onPrimaryPressed: _retryLocationPermission,
            ),
          );
        }
        return;
      }
      _storeUserPosition(position);
      if (viewportGeneration != null &&
          _viewportPolicy.canApply(viewportGeneration)) {
        _centerMapOnPosition(position, generation: viewportGeneration);
      }
    } on PermissionDeniedException {
      if (mounted && showFailureNotice) {
        _showLocationNotice(
          kIsWeb
              ? _webLocationPermissionNotice()
              : const _LocationNoticeData(
                  title: '위치 권한이 필요해요',
                  message: '내 위치 주변의 매장을 보여드리려면\n위치 권한을 허용해주세요.',
                ),
        );
      }
    } on TimeoutException {
      if (mounted && showFailureNotice) {
        _showLocationNotice(
          _LocationNoticeData(
            title: '위치 확인에 시간이 걸리고 있어요',
            message: '네트워크와 기기의 위치 서비스를 확인한 뒤\n다시 시도해 주세요.',
            primaryLabel: '다시 시도',
            onPrimaryPressed: _retryLocationPermission,
          ),
        );
      }
    } catch (_) {
      debugPrint('위치 가져오기 실패');
      if (mounted && showFailureNotice) {
        _showLocationNotice(
          _LocationNoticeData(
            title: '현재 위치를 찾지 못했어요',
            message: '잠시 후 다시 시도하거나\n위치 권한과 네트워크를 확인해주세요.',
            primaryLabel: '다시 시도',
            onPrimaryPressed: _retryLocationPermission,
          ),
        );
      }
    } finally {
      if (mounted && !passive) {
        setState(() => _isCenteringLocation = false);
      }
    }
  }

  void _showLocationNotice(_LocationNoticeData notice) {
    if (!mounted) return;
    setState(() => _locationNotice = notice);
  }

  void _hideLocationNotice() {
    if (!mounted) return;
    setState(() => _locationNotice = null);
  }

  _LocationNoticeData _webLocationPermissionNotice({
    String title = '위치 접근이 차단되어 있어요',
    String? message,
    String primaryLabel = '위치 다시 요청',
    IconData icon = Icons.location_off_rounded,
  }) {
    return _LocationNoticeData(
      title: title,
      message:
          message ??
          (isAppleMobileBrowser
              ? "iPad 설정 → 개인정보 보호 및 보안 →\n위치 서비스 → Safari 웹사이트에서\n위치를 '허용'으로 바꿔주세요."
              : "주소창의 사이트 설정에서 위치 권한을\n'묻기' 또는 '허용'으로 바꾼 뒤\n아래 버튼을 눌러주세요."),
      primaryLabel: primaryLabel,
      icon: icon,
      onPrimaryPressed: _retryLocationPermission,
    );
  }

  Future<void> _retryLocationPermission() async {
    HomeMapScreen.hasDismissedLocationNotice = false;
    _hideLocationNotice();
    await _moveToCurrentLocation();
  }

  Future<void> _openLocationSettings({required bool serviceDisabled}) async {
    _hideLocationNotice();
    final opened = await openLocationSettingsForStatus(
      serviceDisabled: serviceDisabled,
    );
    if (opened) {
      // Center on the user once they come back with location available.
      _awaitingLocationSettingsReturn = true;
      return;
    }
    if (mounted) {
      _showLocationNotice(
        const _LocationNoticeData(
          title: '설정을 열지 못했어요',
          message: '기기 설정에서 얼마고의 위치 권한을\n직접 허용해주세요.',
        ),
      );
    }
  }

  Future<Position?> _getFreshPosition() async {
    try {
      if (kIsWeb) return await requestBrowserLocation();
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      debugPrint('현재 위치 조회 실패');
      return null;
    }
  }

  void _refreshCurrentPositionInBackground({int? centerGeneration}) {
    if (_freshLocationRequest != null) return;
    _freshLocationRequest = _refreshCurrentPosition(
      centerGeneration: centerGeneration,
    );
  }

  Future<void> _refreshCurrentPosition({int? centerGeneration}) async {
    try {
      final position = await _getFreshPosition();
      if (position != null && mounted) {
        _storeUserPosition(position);
        if (centerGeneration != null &&
            _viewportPolicy.canApply(centerGeneration)) {
          _centerMapOnPosition(position, generation: centerGeneration);
        }
      }
    } finally {
      _freshLocationRequest = null;
    }
  }

  void _storeUserPosition(Position position) {
    _lastKnownPosition = position;
    HomeMapScreen.globalUserPosition = position;
    if (!_isMapReady) {
      _pendingMapPosition = position;
      return;
    }
    _updateLocationMarker(position.latitude, position.longitude);
  }

  void _onMapReady() {
    if (!mounted) return;

    _isMapReady = true;
    _lastRenderedMarkerSignature = '';
    if (kIsWeb && (!_isMapInitialized || _mapErrorMessage != null)) {
      setState(() {
        _isMapInitialized = true;
        _mapErrorMessage = null;
      });
    }
    // A reloaded native page starts in normal mode; restore the current mode.
    _setMapSearchMode(_searchResultStores != null);
    _flushPendingMapPosition();
    final pendingSearch = _pendingSearchResult;
    if (pendingSearch != null) {
      _pendingSearchResult = null;
      _applySearchResult(pendingSearch);
    }

    // 최초 진입도 지도 준비 이벤트에서 바로 현재 영역을 조회한다.
    final pendingAiResult = _pendingAiResult;
    if (pendingAiResult != null) {
      _pendingAiResult = null;
      _applyAiRecommendationResult(pendingAiResult);
    }
    _searchInCurrentArea();
    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _searchInCurrentArea();
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _searchInCurrentArea();
      });
    }
  }

  void _onMapError(String message) {
    if (!mounted) return;
    setState(() {
      _isMapReady = false;
      _isMapInitialized = false;
      _mapErrorMessage = message;
    });
  }

  void _retryMap() {
    setState(() => _mapErrorMessage = null);
    if (kIsWeb) {
      web_helper.recoverKakaoWebMap(_viewId);
    } else {
      _reloadMobileMap();
    }
  }

  void _hideStore() {
    if (!mounted) return;
    if (_showStoreSummary || _selectedStore != null) {
      setState(() {
        _showStoreSummary = false;
        _selectedStore = null;
      });
      _highlightMapMarker(-1);
    }
  }

  void _flushPendingMapPosition() {
    if (!_isMapReady) return;

    final position = _pendingMapPosition ?? _lastKnownPosition;
    if (position == null) return;

    _pendingMapPosition = null;
    _updateLocationMarker(position.latitude, position.longitude);
    final generation = _pendingMapCenterGeneration;
    _pendingMapCenterGeneration = null;
    if (generation != null && _viewportPolicy.canApply(generation)) {
      _centerMapOnPosition(position, generation: generation);
    }
  }

  void _centerMapOnPosition(Position position, {required int generation}) {
    if (!_viewportPolicy.canApply(generation)) return;
    if (!_isMapReady) {
      _pendingMapPosition = position;
      _pendingMapCenterGeneration = generation;
      return;
    }

    if (kIsWeb) {
      web_helper.setKakaoMapCenterWeb(
        _viewId,
        position.latitude,
        position.longitude,
      );
      // 웹에서도 중심 변경 후 안정화 시간을 두고 현재 영역 검색을 확실히 보장
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _searchInCurrentArea();
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _searchInCurrentArea();
      });
      return;
    }
    _safeRunJavaScript(
      'setMapCenter(${position.latitude}, ${position.longitude});',
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchInCurrentArea();
    });
  }

  void _updateUserHeading(double heading) {
    if (kIsWeb || !_isMapReady || !heading.isFinite) return; // 웹에서는 나침반 제외
    // Compass events arrive many times per second. Redraw at most ten times a
    // second, and only for a visible change.
    if (_headingThrottle?.isActive ?? false) {
      _pendingHeading = heading;
      return;
    }
    _sendUserHeading(heading);
  }

  void _sendUserHeading(double heading) {
    final previous = _lastSentHeading;
    if (previous != null &&
        (((heading - previous + 540) % 360) - 180).abs() < 3) {
      return;
    }
    _lastSentHeading = heading;
    _safeRunJavaScript('updateUserHeading(${heading.toStringAsFixed(1)});');
    _headingThrottle = Timer(const Duration(milliseconds: 100), () {
      final pending = _pendingHeading;
      _pendingHeading = null;
      if (pending != null && mounted && _isMapReady) _sendUserHeading(pending);
    });
  }

  void _updateLocationMarker(double lat, double lng) {
    if (kIsWeb) {
      web_helper.updateUserLocationMarkerWeb(_viewId, lat, lng);
    } else {
      _safeRunJavaScript('updateUserLocationMarker($lat, $lng);');
    }
  }

  void _safeRunJavaScript(String script) {
    final controller = _webViewController;
    if (controller == null) return;
    try {
      // Page errors are reported asynchronously, after this call returns.
      unawaited(
        controller
            .runJavaScript(script)
            .onError(
              (Object error, StackTrace stackTrace) =>
                  debugPrint('WebView JS 실행 에러 (무시됨): $error'),
            ),
      );
    } catch (e) {
      debugPrint('WebView JS 실행 에러 (무시됨): $e');
    }
  }

  void _relayoutMobileMap() {
    if (kIsWeb || !_isMapReady) return;
    _safeRunJavaScript('relayoutMap();');
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _isMapReady) _safeRunJavaScript('relayoutMap();');
    });
  }

  void _startLocationTracking() {
    // Permission prompts and position lookups can finish after this screen is
    // disposed. A stream started then would never be cancelled.
    if (!mounted) return;
    _positionStream ??=
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2, // 2미터 이상 이동 시 갱신
          ),
        ).listen(
          (Position position) => _storeUserPosition(position),
          onError: (Object error) {
            debugPrint('위치 추적 종료: $error');
            _positionStream = null;
          },
          cancelOnError: true,
        );

    // Keep a single compass subscription even when the position stream ends
    // with an error and is started again.
    if (!kIsWeb && _compassStream == null) {
      _compassStream = FlutterCompass.events?.listen(
        (CompassEvent event) {
          final heading = event.heading;
          if (heading != null) _updateUserHeading(heading);
        },
        onError: (Object error) {
          debugPrint('나침반 종료: $error');
          _compassStream = null;
        },
        cancelOnError: true,
      );
    }
    _syncLocationTracking();
  }

  Future<void> _searchInCurrentArea() async {
    if (kIsWeb) {
      try {
        final String? boundsJson = web_helper.getKakaoMapBoundsWeb(_viewId);
        if (boundsJson == null || parseKakaoMapBounds(boundsJson) == null) {
          _scheduleWebBoundsRetry();
          return;
        }
        _webBoundsRetryTimer?.cancel();
        _webBoundsRetryCount = 0;
        _rememberViewport(parseMobileMapViewport(boundsJson));
        await _fetchAndAddLatestMarkers(boundsJson);
      } catch (e) {
        debugPrint('웹 범위 검색 에러: $e');
      }
    } else {
      _safeRunJavaScript('requestBounds();');
    }
  }

  Future<void> _fetchAndAddLatestMarkers(String boundsJson) async {
    if (!mounted) return;
    final parsedBounds = parseKakaoMapBounds(boundsJson);
    if (parsedBounds == null) return;
    if (_searchResultStores == null &&
        !_isAiRecommendationActive &&
        !isHomeMapBoundsWithinBackendLimit(parsedBounds)) {
      // Ignore unsupported zoom levels and invalidate any request started
      // for the previous viewport so stale markers cannot replace the map.
      _boundsRequestGeneration++;
      _pendingBoundsJson = null;
      return;
    }
    // Start-up and "my location" ask for the same viewport several times.
    // When that viewport is already loading for the current map state, let
    // the response finish instead of discarding it and requesting it again.
    final boundsKey = _homeMapBoundsKey(parsedBounds);
    if (_isFetching &&
        _pendingBoundsJson == null &&
        _inFlightBoundsKey == boundsKey &&
        _inFlightBoundsGeneration == _boundsRequestGeneration) {
      return;
    }
    _boundsRequestGeneration++;
    _pendingBoundsJson = boundsJson;
    if (_isFetching) return;
    _isFetching = true;
    try {
      while (mounted && _pendingBoundsJson != null) {
        final requestGeneration = _boundsRequestGeneration;
        final bounds = parseKakaoMapBounds(_pendingBoundsJson!)!;
        _pendingBoundsJson = null;
        _inFlightBoundsKey = _homeMapBoundsKey(bounds);
        _inFlightBoundsGeneration = requestGeneration;
        final markerList = await _fetchStoresFromBackend(
          bounds,
          isCurrent: () => requestGeneration == _boundsRequestGeneration,
        );
        if (!mounted) return;
        if (requestGeneration != _boundsRequestGeneration) continue;
        if (_markerListSignature(markerList) == _lastRenderedMarkerSignature) {
          continue;
        }
        _renderMarkers(markerList);
      }
    } finally {
      _isFetching = false;
      _inFlightBoundsKey = null;
      _inFlightBoundsGeneration = null;
    }
  }

  String _homeMapBoundsKey(Map<String, double> bounds) => [
    bounds['minLat']!,
    bounds['maxLat']!,
    bounds['minLng']!,
    bounds['maxLng']!,
  ].map((value) => value.toStringAsFixed(5)).join(':');

  Future<List<Map<String, dynamic>>> _fetchStoresFromBackend(
    Map<String, double> bounds, {
    required bool Function() isCurrent,
  }) async {
    final minLat = bounds['minLat']!;
    final maxLat = bounds['maxLat']!;
    final minLng = bounds['minLng']!;
    final maxLng = bounds['maxLng']!;

    if (_isAiRecommendationActive && _aiRecommendedStores.isNotEmpty) {
      if (!mounted || !isCurrent()) return const [];
      setState(() {
        _currentStores = _aiRecommendedStores;
        _isAllStoresLoaded = true;
        _hasLoadError = false;
      });
      return _currentStores
          .map((store) => _storeMarker(store, _selectionFor(store)))
          .toList();
    }

    final searchResults = _searchResultStores;
    if (searchResults != null && !_isAiRecommendationActive) {
      final visible = searchResults
          .where(
            (store) =>
                store.hasValidCoordinates &&
                store.latitude >= minLat &&
                store.latitude <= maxLat &&
                store.longitude >= minLng &&
                store.longitude <= maxLng,
          )
          .toList();
      if (!mounted || !isCurrent()) return const [];
      setState(() {
        _currentStores = searchResults;
        _searchViewportCount = visible.length;
        _isAllStoresLoaded = true;
        _hasLoadError = false;
      });
      return visible
          .take(100)
          .map((store) => _storeMarker(store, _searchSelectionFor(store)))
          .toList();
    }

    try {
      final HomeMapStoreLoader loadStores =
          widget.storeLoader ?? loadHomeMapStoresWithStatus;
      final loadResult = await loadStores(
        bounds: bounds,
        cachedStores: _allStores,
      );
      if (!mounted || !isCurrent()) return const [];
      final fetchedStores = loadResult.stores;

      if (mounted) {
        setState(() {
          if (loadResult.hasFreshResponse) {
            _hasFreshStoreResponse = true;
            _allStores = fetchedStores
                .take(maxCachedHomeMapStores)
                .toList(growable: false);
            HomeMapScreen.setMapStores(List<Store>.unmodifiable(_allStores));
          }
          _isAllStoresLoaded =
              loadResult.hasFreshResponse || fetchedStores.isNotEmpty;
          _hasLoadError = !loadResult.hasFreshResponse && fetchedStores.isEmpty;
          _usingCachedStores =
              !loadResult.hasFreshResponse && fetchedStores.isNotEmpty;
        });
      }
      if (loadResult.hasFreshResponse) {
        unawaited(_cacheHomeMapStores(fetchedStores));
      }
      _reportBoundsLoadOutcome(loadResult);

      var stores = fetchedStores
          .where(
            (s) =>
                !s.isClosed &&
                s.hasValidCoordinates &&
                s.latitude >= minLat &&
                s.latitude <= maxLat &&
                s.longitude >= minLng &&
                s.longitude <= maxLng,
          )
          .map((store) => _StoreWithDistance(store, _distanceFromUser(store)))
          .toList();

      // ─── 검색 및 필터 적용 ───
      if (_searchQuery.trim().isNotEmpty) {
        stores = stores
            .where(
              (item) =>
                  SearchFilterPolicy.matchesQuery(item.store, _searchQuery),
            )
            .toList();
      }

      if (_searchFilter.maxPrice != null) {
        stores = stores.where((item) {
          return SearchFilterPolicy.matchesMaxPrice(
            item.store,
            _searchFilter.maxPrice!,
            query: _searchQuery,
          );
        }).toList();
      }

      if (_searchFilter.industries.isNotEmpty) {
        stores = stores
            .where(
              (item) => _searchFilter.industries.any(
                (ind) => SearchFilter.matchesIndustry(item.store, ind),
              ),
            )
            .toList();
      }

      if (_searchFilter.govCertified) {
        stores = stores.where((item) => item.store.source == 'GOV').toList();
      } else if (!_searchFilter.userReported) {
        stores = stores.where((item) => item.store.source != 'USER').toList();
      }

      if (_searchFilter.distance != null && _lastKnownPosition != null) {
        double maxDist = 0;
        if (_searchFilter.distance == '500m 이내') {
          maxDist = 500;
        } else if (_searchFilter.distance == '1km 이내') {
          maxDist = 1000;
        } else if (_searchFilter.distance == '3km 이내') {
          maxDist = 3000;
        }

        if (maxDist > 0) {
          stores = stores
              .where(
                (item) => (item.distanceMeters ?? double.infinity) <= maxDist,
              )
              .toList();
        }
      }

      if (_searchFilter.sortOrder == '저렴한순') {
        stores.sort(
          (a, b) => SearchFilterPolicy.compareByPrice(
            a.store,
            b.store,
            query: _searchQuery,
            distanceOf: _priceTieDistance,
          ),
        );
      } else {
        if (_lastKnownPosition != null) {
          stores.sort(
            (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
              b.distanceMeters ?? double.infinity,
            ),
          );
        }
      }

      // 💥 너무 많은 마커가 렌더링되어 앱이 멈추는 것을 방지 (최대 100개)
      if (stores.length > 100) {
        stores = stores.take(100).toList();
      }

      _currentStores = stores.map((item) => item.store).toList(growable: false);

      return _currentStores
          .map(
            (store) => _storeMarker(
              store,
              _searchQuery.isNotEmpty || _searchFilter.activeLabels.isNotEmpty
                  ? _searchSelectionFor(store)
                  : null,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('필터링 에러: $e');
      return [];
    }
  }

  Future<void> _cacheHomeMapStores(List<Store> stores) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        homeMapStoreCacheKey,
        encodeHomeMapStoreCache(stores),
      );
    } catch (error) {
      debugPrint('지도 매장 캐시 저장 실패: $error');
    }
  }

  /// Non-blocking feedback for viewport loads, once per streak. A load with
  /// no stores at all keeps the full-screen retry state instead.
  void _reportBoundsLoadOutcome(HomeMapStoreLoadResult result) {
    if (!mounted) return;
    if (result.hasFreshResponse) {
      _boundsFailureNoticeShown = false;
      if (!result.truncated) {
        _truncationNoticeShown = false;
        return;
      }
      if (_truncationNoticeShown) return;
      _truncationNoticeShown = true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        HowmuchSnackBar(
          content: const Text('지도를 확대하면 매장이 더 보여요.'),
          aboveNavigation: true,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (result.stores.isEmpty || _boundsFailureNoticeShown) return;
    _boundsFailureNoticeShown = true;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      HowmuchSnackBar.warning(
        title: '새 매장 정보를 불러오지 못했어요',
        aboveNavigation: true,
        content: _MapNoticeMessage(
          message: '저장된 매장으로 보여드리고 있어요.',
          actionLabel: '다시 시도',
          onAction: _retryBoundsLoad,
        ),
      ),
    );
  }

  void _retryBoundsLoad() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    _boundsFailureNoticeShown = false;
    _lastRenderedMarkerSignature = '';
    _searchInCurrentArea();
  }

  double? _distanceFromUser(Store store) {
    final position = _lastKnownPosition;
    if (position == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      store.latitude,
      store.longitude,
    );
  }

  /// '저렴한순' lists stores at the same price nearest first, like the search
  /// screen (QA #31). Without a position they stay in name order.
  double Function(Store store)? get _priceTieDistance =>
      _lastKnownPosition == null
      ? null
      : (store) => _distanceFromUser(store) ?? double.infinity;

  String _markerListSignature(List<Map<String, dynamic>> markers) {
    return markers
        .map(
          (marker) =>
              '${marker['storeId']}|${marker['title']}|${marker['lat']}|${marker['lng']}|${marker['menu']}|${marker['price']}|${marker['source']}',
        )
        .join('\n');
  }

  /// A tap on a store card can also reach the map below as a background tap
  /// and close the card (QA 10/7 #32). Like the location button, map taps
  /// are ignored while the card is pressed and right after it is released.
  Widget _blockMapTapsThrough(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) =>
          _suppressMarkerClicks(const Duration(milliseconds: 800)),
      onPointerUp: (_) =>
          _suppressMarkerClicks(const Duration(milliseconds: 800)),
      child: child,
    );
  }

  Widget _buildWebMap() {
    return Stack(
      children: [
        Positioned.fill(child: _webMapView),
        if (!_isMapInitialized)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildMobileMap() {
    if (_webViewController == null) {
      return const Center(child: Text('초기화 중...'));
    }
    return WebViewWidget(
      key: const ValueKey('kakao-map-mobile'),
      controller: _webViewController!,
    );
  }

  @override
  void didUpdateWidget(covariant HomeMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearchResult != widget.initialSearchResult &&
        widget.initialSearchResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySearchResult(widget.initialSearchResult!);
      });
    }
    if (oldWidget.showAiSpotlight != widget.showAiSpotlight) {
      _showAiSpotlight = widget.showAiSpotlight;
    }
    if (oldWidget.initialRecommendation != widget.initialRecommendation &&
        widget.initialRecommendation != null) {
      _pendingAiResult = widget.initialRecommendation;
      if (_isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pending = _pendingAiResult;
          if (mounted && pending != null) {
            _pendingAiResult = null;
            _applyAiRecommendationResult(pending);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = HowmuchBottomNav.heightFor(bottomOffset);
    const storeCardHeight = 158.0;
    const storeCardBottomGap = 94.0;

    // Keep the home map in the same 430px product shell as the other primary
    // tabs. MediaQuery still reports the full browser viewport, so overlay
    // coordinates must be derived from the shell width rather than the window.
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = FigmaMobileCanvas.webContentWidthFor(screenSize.width);
    final screenHeight = screenSize.height;
    final isCompactHeight = screenHeight < 400;
    final horizontalPadding = screenWidth <= 340
        ? 12.0
        : AppSizes.horizontalPadding;
    final searchTop = (isCompactHeight ? 8.0 : 10.0) + topOffset;
    final searchHeight = isCompactHeight ? 44.0 : 52.0;
    final todayPickTop = isCompactHeight
        ? searchTop + searchHeight + 8
        : 106.46307373046875 + topOffset;
    final todayPickHeight = isCompactHeight ? 44.0 : 55.80965805053711;

    final storeCardTop = screenHeight - storeCardBottomGap - storeCardHeight;
    final homeChromeOpacity = _showAiSpotlight ? 0.0 : 1.0;
    final bottomBase = screenHeight - bottomNavHeight;
    final defaultFloatingLocationTop = _showStoreSummary
        ? storeCardTop - 132.0
        : bottomBase - 132.0;
    final defaultFloatingAiTop = _showStoreSummary
        ? storeCardTop - 68.0
        : bottomBase - 68.0;
    final preferredLocationTop = isCompactHeight
        ? todayPickTop + todayPickHeight + 4
        : defaultFloatingLocationTop;
    // Resize/keyboard transitions can leave less room than the stacked
    // controls require. Never clamp with a minimum greater than the maximum:
    // that throws ArgumentError(164) and prevents the entire map from building.
    final compactControlLimit = math.max(0.0, bottomBase - 52.0);
    final inlineCompactControls =
        isCompactHeight && preferredLocationTop + 56 > compactControlLimit;
    final floatingLocationTop = isCompactHeight
        ? math.min(preferredLocationTop, compactControlLimit)
        : preferredLocationTop;
    final floatingAiTop = isCompactHeight
        ? (inlineCompactControls
              ? floatingLocationTop
              : floatingLocationTop + 56)
        : defaultFloatingAiTop;
    final showCompactTodayPick =
        !isCompactHeight ||
        floatingLocationTop >= todayPickTop + todayPickHeight + 4;
    final spotlightAiTop = bottomBase - 77.0;
    final spotlightCoachTop = spotlightAiTop - 48.0;

    final activeFilters = _searchFilter.activeLabels;
    final hasFilters = activeFilters.isNotEmpty;
    final isSearching = _searchQuery.isNotEmpty || hasFilters;
    final isResultActive =
        _isAiRecommendationActive && _aiRecommendedStores.isNotEmpty;
    final isAiActive =
        isResultActive &&
        _activeAiRecommendation?.origin != MapResultOrigin.approvedReport;
    final showStoreList =
        (isSearching || isResultActive) && _currentStores.isNotEmpty;
    final topOffsetPush = hasFilters ? 44.0 : 0.0;

    // On the app the map reaches the screen edges when the screen is wider
    // than the shell (landscape), while every control stays in the same
    // centered 430 column as before (QA 10/7 #45). On the web and on portrait
    // phones the column is the whole canvas, so nothing moves.
    Widget productColumn(List<Widget> children) => Positioned.fill(
      child: Center(
        child: SizedBox(
          width: screenWidth,
          child: Stack(children: children),
        ),
      ),
    );

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFEFF4FF),
      fullWidthOnApp: true,
      child: Stack(
        children: [
          Positioned.fill(
            // A full-screen onTap creates a Flutter semantics hit area above
            // the platform view. Background taps already arrive from Kakao.
            child: kIsWeb ? _buildWebMap() : _buildMobileMap(),
          ),

          if (_mapErrorMessage != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFF4F6FA),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 44,
                          color: HomeMapScreen.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _mapErrorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HomeMapScreen.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _retryMap,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (!_isAllStoresLoaded && _mapErrorMessage == null)
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
                            image: AssetImage('assets/images/app_logo_ui.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _hasLoadError
                            ? '데이터를 불러오지 못했어요.\n서버 연결을 확인해주세요.'
                            : _usingCachedStores
                            ? '저장된 매장 데이터로 먼저 보여드리고 있어요.'
                            : '가성비 식당 데이터를\n열심히 불러오고 있어요...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _hasLoadError
                              ? Colors.red
                              : const Color(0xFF2563EB),
                          fontFamily: 'Noto Sans KR',
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
                            _searchInCurrentArea();
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

          productColumn([
            Positioned(
              key: const ValueKey('home-search-control'),
              left: horizontalPadding,
              right: horizontalPadding,
              top: searchTop,
              height: searchHeight,
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
                top: 86 + topOffset + 52 + 10, // _SearchBar below
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
                    separatorBuilder: (_, _) =>
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
                            // The X was a nameless tap target (QA 10/7 #50);
                            // same name as the search screen's chips.
                            Semantics(
                              container: true,
                              button: true,
                              label: '$label 필터 해제',
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchFilter = _searchFilter.remove(label);
                                    _refreshTransferredSearchResults();
                                  });
                                  _searchInCurrentArea();
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (!isSearching && !isResultActive) ...[
              if (!isCompactHeight)
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
              if (showCompactTodayPick)
                Positioned(
                  key: const ValueKey('home-today-pick-card'),
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: todayPickTop + topOffsetPush,
                  height: todayPickHeight,
                  child: Opacity(
                    opacity: homeChromeOpacity,
                    child: _TodayPickCard(compact: isCompactHeight),
                  ),
                ),
            ],
            Positioned(
              key: const ValueKey('home-location-control'),
              right: inlineCompactControls ? 76 : 16,
              top: floatingLocationTop,
              width: 52.0,
              height: 52.0,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: Tooltip(
                  message: '내 위치로 이동',
                  child: Semantics(
                    button: true,
                    label: '내 위치로 이동',
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _suppressMarkerClicks(
                        const Duration(milliseconds: 1000),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _suppressMarkerClicks(
                          const Duration(milliseconds: 1000),
                        ),
                        onTap: () {
                          _suppressMarkerClicks(
                            const Duration(milliseconds: 1000),
                          );
                          _moveToCurrentLocation();
                        },
                        child: _RoundIconButton(
                          icon: Icons.near_me_rounded,
                          color: HomeMapScreen.blue,
                          isLoading: _isCenteringLocation,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('home-ai-control'),
              right: 16,
              top: floatingAiTop,
              height: 51.9886360168457,
              child: Opacity(
                opacity: homeChromeOpacity,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) =>
                      _suppressMarkerClicks(const Duration(milliseconds: 800)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _suppressMarkerClicks(
                      const Duration(milliseconds: 800),
                    ),
                    onVerticalDragUpdate: (_) {},
                    onHorizontalDragUpdate: (_) {},
                    child: Tooltip(
                      message: 'AI 추천받기',
                      child: Semantics(
                        button: true,
                        label: 'AI 추천받기',
                        onTap: _openAiRecommend,
                        excludeSemantics: true,
                        child: _AiRecommendControl(
                          onTap: _openAiRecommend,
                          compact: inlineCompactControls,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isAiActive) ...[
              Positioned(
                left: AppSizes.horizontalPadding,
                right: AppSizes.horizontalPadding,
                top: 64.0 + topOffset + topOffsetPush,
                child: Opacity(
                  opacity: homeChromeOpacity,
                  child: Center(
                    child: _AiRecommendationBanner(
                      count: _aiRecommendedStores.length,
                      origin: _activeAiRecommendation?.origin,
                      onReset: _clearAiRecommendation,
                    ),
                  ),
                ),
              ),
            ],
            if (showStoreList) ...[
              if (_activeAiRecommendation?.origin !=
                  MapResultOrigin.approvedReport)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomNavHeight + 10 + storeCardHeight + 4,
                  child: Opacity(
                    opacity: homeChromeOpacity,
                    child: Center(
                      child: _FloatingSearchSummary(
                        count: _currentStores.length,
                        title: isAiActive
                            ? (_activeAiRecommendation?.origin ==
                                      MapResultOrigin.todaysPick
                                  ? '오늘의 픽 '
                                  : 'AI 추천 결과 ')
                            : null,
                        detail: _searchResultStores == null
                            ? null
                            : '검색 전체 ${_searchResultStores!.length}곳 · 지도 안 $_searchViewportCount곳${_searchViewportCount > 100 ? ' (마커 100곳 표시)' : ''}${_searchResultStores!.any((store) => !store.hasValidCoordinates) ? ' · 위치 없는 매장 ${_searchResultStores!.where((store) => !store.hasValidCoordinates).length}곳' : ''}',
                      ),
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
                  child: _blockMapTapsThrough(
                    HomeMapStoreCarousel(
                      controller: _pageController,
                      itemCount: _currentStores.length,
                      onPageChanged: _onStorePageChanged,
                      itemBuilder: (context, index) {
                        final store = _currentStores[index];
                        return HomeMapStoreSummaryCard(
                          store: store,
                          selection: isAiActive
                              ? _selectionFor(store)
                              : (isSearching
                                    ? _searchSelectionFor(store)
                                    : null),
                        );
                      },
                    ),
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
                  child: _blockMapTapsThrough(
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (_) {},
                      onHorizontalDragUpdate: (_) {},
                      child: HomeMapStoreSummaryCard(
                        store: _selectedStore!,
                        selection: isAiActive
                            ? _selectionFor(_selectedStore!)
                            : (isSearching
                                  ? _searchSelectionFor(_selectedStore!)
                                  : null),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              key: const ValueKey('home-bottom-navigation'),
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
          ]),
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
            productColumn([
              Positioned(
                left: (screenWidth - 265) / 2,
                top: spotlightCoachTop,
                width: 265,
                height: 38,
                child: _AiCoachTip(onTap: _openAiRecommend),
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
                    onTap: _openAiRecommend,
                    spotlight: true,
                  ),
                ),
              ),
            ]),
          ],
          if (_locationNotice != null)
            Positioned.fill(
              // Screen readers must not reach the map controls behind it.
              child: BlockSemantics(
                child: _LocationPermissionModal(
                  notice: _locationNotice!,
                  onClose: _hideLocationNotice,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationNoticeData {
  const _LocationNoticeData({
    required this.title,
    required this.message,
    this.primaryLabel = '확인',
    this.onPrimaryPressed,
    this.icon = Icons.location_off_rounded,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final Future<void> Function()? onPrimaryPressed;
  final IconData icon;
}

class _LocationPermissionModal extends StatelessWidget {
  const _LocationPermissionModal({required this.notice, required this.onClose});

  final _LocationNoticeData notice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final width = (FigmaMobileCanvas.logicalWidthOf(context) - 48).clamp(
      280.0,
      327.0,
    );

    return Material(
      color: Colors.black.withValues(alpha: .35),
      child: Center(
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HomeMapScreen.blue.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(notice.icon, color: HomeMapScreen.blue, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                notice.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeMapScreen.ink,
                  fontFamily: HomeMapScreen.fontFamily,
                  fontFamilyFallback: HomeMapScreen.fontFallback,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notice.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeMapScreen.muted,
                  fontFamily: HomeMapScreen.fontFamily,
                  fontFamilyFallback: HomeMapScreen.fontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    final action = notice.onPrimaryPressed;
                    if (action == null) {
                      onClose();
                      return;
                    }
                    await action();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeMapScreen.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: HomeMapScreen.fontFamily,
                      fontFamilyFallback: HomeMapScreen.fontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  child: Text(notice.primaryLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () {
                    HomeMapScreen.hasDismissedLocationNotice = true;
                    onClose();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: HomeMapScreen.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: HomeMapScreen.fontFamily,
                      fontFamilyFallback: HomeMapScreen.fontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  child: Text(
                    notice.onPrimaryPressed == null ? '닫기' : '나중에 할게요',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              borderRadius: BorderRadius.circular(22),
              elevation: 0,
              shadowColor: const Color(0x140F172A),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
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
        _SquareButton(
          icon: Icons.tune_rounded,
          label: '검색 필터 열기',
          onTap: onFilterTap,
        ),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        shadowColor: const Color(0x140F172A),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: HomeMapScreen.ink, size: 19),
          ),
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
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
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
  const _TodayPickCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.todaysPick),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: .909),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        // The banner floats over the map at a fixed height, so its text stops
        // at the compact chrome scale (QA 10/7 #5).
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppTextScale.compactChrome,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 320;
              return Row(
                children: [
                  SizedBox(
                    width: compact ? 44 : 55.99431610107422,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFEFF4FF), Color(0xFFEFF4FF)],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.thunderstorm_outlined,
                            color: HomeMapScreen.blue,
                            size: 20,
                          ),
                          const SizedBox(height: 1.989),
                          // 기온을 확인하지 못한 경우 추정값을 표시하지 않는다.
                          Text(
                            '오늘',
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
                  SizedBox(width: narrow ? 8 : 11.988616943359375),
                  const Expanded(child: _TodayPickText()),
                  if (!compact) ...[
                    const _RankDot(label: '1', color: HomeMapScreen.blue),
                    const _RankDot(label: '2', color: HomeMapScreen.orange),
                    const _RankDot(label: '3', color: HomeMapScreen.green),
                  ],
                  SizedBox(width: narrow ? 4 : 9.985779),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: HomeMapScreen.muted,
                    size: 17,
                  ),
                  SizedBox(width: narrow ? 8 : 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TodayPickText extends StatelessWidget {
  const _TodayPickText();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '오늘의 픽',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontFamily: HomeMapScreen.fontFamily,
                    fontFamilyFallback: HomeMapScreen.fontFallback,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(width: 5.994),
                Expanded(
                  child: Text(
                    '· ${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')} ${['월', '화', '수', '목', '금', '토', '일'][DateTime.now().weekday - 1]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeMapScreen.muted,
                      fontFamily: HomeMapScreen.fontFamily,
                      fontFamilyFallback: HomeMapScreen.fontFallback,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: .994),
            // Shrinks to the space left by the rank dots instead of ending in
            // an ellipsis when the text is enlarged.
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '날씨와 거리로 매장 추천',
                maxLines: 1,
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
            ),
          ],
        );
        // The short landscape banner (44px) cannot hold both lines at the
        // capped scale; shrink them together instead of cutting the title.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: constraints.maxWidth, child: lines),
        );
      },
    );
  }
}

class _RankDot extends StatelessWidget {
  const _RankDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(left: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

const _storeNameStyle = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 18,
  fontWeight: FontWeight.w700,
  height: 1.25,
);

/// A long name on two lines, at the search list card's size.
const _wrappedStoreNameStyle = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontFamilyFallback: HomeMapScreen.fontFallback,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.2,
);

const _compactPriceStyle = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontWeight: FontWeight.w800,
  fontSize: 18,
  height: 1.5,
);

const _tightCompactPriceStyle = TextStyle(
  color: HomeMapScreen.ink,
  fontFamily: HomeMapScreen.fontFamily,
  fontWeight: FontWeight.w800,
  fontSize: 18,
  height: 1.2,
);

TextPainter _layoutText(
  String text,
  TextStyle style,
  TextScaler textScaler, {
  int? maxLines,
  double maxWidth = double.infinity,
  TextDirection textDirection = TextDirection.ltr,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  maxLines: maxLines,
  ellipsis: maxLines == null ? null : '…',
  textScaler: textScaler,
  textDirection: textDirection,
)..layout(maxWidth: maxWidth);

double _textWidth(String text, TextStyle style, TextScaler textScaler) {
  final painter = _layoutText(text, style, textScaler, maxLines: 1);
  final width = painter.width;
  painter.dispose();
  return width;
}

double _textHeight(TextStyle style, TextScaler textScaler) {
  final painter = _layoutText('0', style, textScaler, maxLines: 1);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Whether a name that does not fit on one card line moves to two smaller
/// lines, so branches of one brand stay distinguishable (QA 10/7 #29). The
/// card height is fixed: when two lines do not fit (large text), the single
/// line with an ellipsis stays.
bool _storeNameWrapsInCard({
  required String name,
  required double width,
  required double height,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  if (width <= 0 || height <= 0) return false;
  final oneLine = _layoutText(
    name,
    _storeNameStyle,
    textScaler,
    maxLines: 1,
    maxWidth: width,
    textDirection: textDirection,
  );
  final fitsOneLine = !oneLine.didExceedMaxLines;
  oneLine.dispose();
  if (fitsOneLine) return false;
  final twoLines = _layoutText(
    name,
    _wrappedStoreNameStyle,
    textScaler,
    maxLines: 2,
    maxWidth: width,
    textDirection: textDirection,
  );
  final twoLineHeight = twoLines.height;
  twoLines.dispose();
  return twoLineHeight <= height;
}

class HomeMapStoreSummaryCard extends StatelessWidget {
  final Store store;
  final RecommendationMenuSelection? selection;
  const HomeMapStoreSummaryCard({
    super.key,
    required this.store,
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    // The card has a fixed height on the map, so its text stops at the
    // compact chrome scale; the full details scale on the store page
    // (QA 10/7 #5).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppTextScale.compactChrome,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F172A),
              blurRadius: 16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    _SourceBadge(isUserReported: store.isUserReported),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        store.address.split(' ').take(3).join(' '),
                        style: _muted11,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 60,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScaler = MediaQuery.textScalerOf(context);
                    final textDirection = Directionality.of(context);
                    if (constraints.maxWidth < 300) {
                      final industryWidth = math.min(
                        64.0,
                        _textWidth(store.industry, _muted11, textScaler),
                      );
                      final priceLineHeight = math.max(
                        _textHeight(_muted12, textScaler),
                        _textHeight(_tightCompactPriceStyle, textScaler),
                      );
                      final wrapName = _storeNameWrapsInCard(
                        name: store.storeName,
                        width: constraints.maxWidth - 8 - industryWidth,
                        height: constraints.maxHeight - 2 - priceLineHeight,
                        textScaler: textScaler,
                        textDirection: textDirection,
                      );
                      // Enlarged text also needs the tight price line, or the
                      // name and price no longer fit the 60px row.
                      final roomyHeight =
                          _textHeight(_storeNameStyle, textScaler) +
                          4 +
                          math.max(
                            _textHeight(_muted12, textScaler),
                            _textHeight(_compactPriceStyle, textScaler),
                          );
                      final tight =
                          wrapName || roomyHeight > constraints.maxHeight;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StoreInfo(
                                  store: store,
                                  compact: true,
                                  wrapName: wrapName,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 64),
                                child: Text(
                                  store.industry,
                                  style: _muted11,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: tight ? 2 : 4),
                          _StorePrice(
                            store: store,
                            selection: selection,
                            compact: true,
                            tight: tight,
                          ),
                        ],
                      );
                    }
                    final wrapName = _storeNameWrapsInCard(
                      name: store.storeName,
                      width: constraints.maxWidth - 12 - 144,
                      height:
                          constraints.maxHeight -
                          4 -
                          _textHeight(_muted12, textScaler),
                      textScaler: textScaler,
                      textDirection: textDirection,
                    );
                    return Row(
                      children: [
                        Expanded(
                          child: _StoreInfo(store: store, wrapName: wrapName),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 144,
                          child: _StorePrice(
                            store: store,
                            selection: selection,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE7E9E2)),
              SizedBox(
                height: 54,
                child: Center(child: _DetailButton(store: store)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  final Store store;
  final bool compact;
  final bool wrapName;
  const _StoreInfo({
    required this.store,
    this.compact = false,
    this.wrapName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          store.storeName,
          style: wrapName ? _wrappedStoreNameStyle : _storeNameStyle,
          maxLines: wrapName ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(store.industry, style: _muted12),
        ],
      ],
    );
  }
}

class _StorePrice extends StatelessWidget {
  final Store store;
  final RecommendationMenuSelection? selection;
  final bool compact;

  /// Drops the price line's extra leading to make room for a two-line name.
  final bool tight;
  const _StorePrice({
    required this.store,
    this.selection,
    this.compact = false,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPrice = selection == null ? store.price1 : selection!.price;
    final priceStr = formatMenuPrice(
      selectedPrice,
      free: selection?.free ?? store.free1,
    );
    final selectedMenu = selection?.menu.trim() ?? '';
    final menuStr = selectedMenu.isNotEmpty
        ? selectedMenu
        : (store.menu1.isNotEmpty ? store.menu1 : '대표 메뉴');

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              menuStr,
              style: _muted12,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                priceStr,
                style: tight ? _tightCompactPriceStyle : _compactPriceStyle,
              ),
            ),
          ),
        ],
      );
    }
    // Sized by its content and centered in the 60px row: the old 52px box
    // overflowed by 6px at 1.3x text.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          menuStr,
          textAlign: TextAlign.right,
          style: _muted10.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            priceStr,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: HomeMapScreen.ink,
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailButton extends StatefulWidget {
  final Store store;
  const _DetailButton({required this.store});

  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton> {
  bool _showFocus = false;

  void _open() => context.push(AppRoutes.storeDetail, extra: widget.store);

  @override
  Widget build(BuildContext context) {
    // Keyboard users reach the card action with Tab and open it with
    // Enter or Space, like any other button.
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: _open,
          child: Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              color: HomeMapScreen.blue,
              borderRadius: BorderRadius.circular(12),
              border: _showFocus
                  ? Border.all(color: HomeMapScreen.ink, width: 2)
                  : null,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  final IconData icon;
  final Color color;
  final bool isLoading;

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
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
            )
          : Icon(icon, color: color, size: 22),
    );
  }
}

class _AiRecommendControl extends StatelessWidget {
  const _AiRecommendControl({
    required this.onTap,
    this.spotlight = false,
    this.compact = false,
  });

  final VoidCallback onTap;
  final bool spotlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Its label used to be clipped to 'AI 추천' at large text sizes: the pill
    // now grows with its one-line label, which stops at the compact chrome
    // scale like the other map controls (QA 10/7 #5).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppTextScale.compactChrome,
      child: _buildControl(),
    );
  }

  Widget _buildControl() {
    if (spotlight) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 78, minHeight: 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
              // Factors of 1 keep the pill at its label size instead of
              // stretching to the row height.
              child: const Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(color: HomeMapScreen.blue),
                      ),
                      TextSpan(text: ' 추천받기'),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
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
                        colors: [HomeMapScreen.blue, Color(0xFF10B981)],
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
          if (!compact)
            Container(
              constraints: const BoxConstraints(
                minWidth: 82,
                minHeight: 22.982954025268555,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
              child: const Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(color: HomeMapScreen.blue),
                      ),
                      TextSpan(text: ' 추천받기'),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
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
            ),
          if (!compact) const SizedBox(width: 7.5),
          Container(
            width: 51.9886360168457,
            height: 51.9886360168457,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HomeMapScreen.blue, Color(0xFF10B981)],
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

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isUserReported});

  final bool isUserReported;

  @override
  Widget build(BuildContext context) {
    final color = isUserReported ? HomeMapScreen.orange : HomeMapScreen.blue;
    final background = isUserReported
        ? const Color(0xFFFFF3EA)
        : const Color(0xFFEFF4FF);

    return Container(
      height: 20.99431800842285,
      padding: const EdgeInsets.symmetric(horizontal: 7.997161865234375),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, size: 5.994318008422852),
          const SizedBox(width: 5.994),
          Text(
            isUserReported ? '사용자 제보' : '정부 인증',
            style: TextStyle(
              color: color,
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

/// Message with an inline action for non-blocking map notices.
class _MapNoticeMessage extends StatelessWidget {
  const _MapNoticeMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: HomeMapScreen.blue,
            textStyle: const TextStyle(
              fontFamily: HomeMapScreen.fontFamily,
              fontFamilyFallback: HomeMapScreen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  검색 안내 칩
// ──────────────────────────────────────────────────────────────
class _FloatingSearchSummary extends StatelessWidget {
  const _FloatingSearchSummary({required this.count, this.title, this.detail});
  final int count;
  final String? detail;
  final String? title;

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
      child: detail != null
          ? Text(
              detail!,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomeMapScreen.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  title != null ? Icons.auto_awesome : Icons.location_on,
                  color: title != null
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  title ?? '현재 검색 결과 ',
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

class _AiRecommendationBanner extends StatelessWidget {
  const _AiRecommendationBanner({
    required this.count,
    required this.onReset,
    this.origin,
  });

  final int count;
  final VoidCallback onReset;
  final MapResultOrigin? origin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              // Today's pick is not an AI result (QA #23).
              origin == MapResultOrigin.todaysPick
                  ? '오늘의 픽 $count곳'
                  : 'AI 추천 매장 $count곳',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '전체보기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ],
              ),
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
