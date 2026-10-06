/// Why a recommendation request failed. Screens use this to explain the cause
/// instead of showing one generic error for every failure.
enum RecommendationFailure {
  location,
  invalidRequest,
  timeout,
  rateLimited,
  server,
  network,
  invalidResponse,
  unknown,
}

/// Longer than the server's worst case (weather lookup capped at about 2s plus
/// catalog filtering), so a slow but successful response is not discarded.
const recommendationRequestTimeout = Duration(seconds: 20);

Map<String, dynamic> recommendationError(
  RecommendationFailure failure, {
  String? message,
  int? statusCode,
}) => {
  'error': true,
  'errorType': failure.name,
  'message': message ?? _defaultMessages[failure],
  'statusCode': ?statusCode,
};

RecommendationFailure recommendationFailureOf(Map<String, dynamic>? data) {
  final type = data?['errorType']?.toString();
  for (final failure in RecommendationFailure.values) {
    if (failure.name == type) return failure;
  }
  return RecommendationFailure.unknown;
}

const _defaultMessages = <RecommendationFailure, String>{
  RecommendationFailure.location: '현재 위치가 필요합니다.',
  RecommendationFailure.invalidRequest: '추천 조건이 올바르지 않습니다.',
  RecommendationFailure.timeout: '추천 서버 응답 시간이 초과됐습니다.',
  RecommendationFailure.rateLimited: '추천 요청이 너무 많습니다.',
  RecommendationFailure.server: '추천 서버에서 오류가 발생했습니다.',
  RecommendationFailure.network: '네트워크 연결에 실패했습니다.',
  RecommendationFailure.invalidResponse: '추천 응답 형식이 올바르지 않습니다.',
  RecommendationFailure.unknown: '추천 정보를 불러오지 못했습니다.',
};

/// Title and guidance shown on the today's pick and route error screens.
({String title, String message}) recommendationFailureCopy(
  RecommendationFailure failure, {
  required bool route,
  String? serverMessage,
}) {
  // Object particle differs: 오늘의 픽을 / 추천 루트를.
  final subject = route ? '추천 루트를' : '오늘의 픽을';
  return switch (failure) {
    RecommendationFailure.location => (
      title: '현재 위치를 확인할 수 없어요',
      message: route
          ? '추천 루트를 만들려면 위치 권한을 허용해주세요.'
          : '주변 추천을 보려면 위치 권한을 허용해주세요.',
    ),
    RecommendationFailure.invalidRequest => (
      title: '추천 조건을 확인해주세요',
      message: serverMessage?.trim().isNotEmpty == true
          ? serverMessage!.trim()
          : '추천 거리나 위치 정보가 올바르지 않아요.',
    ),
    RecommendationFailure.timeout => (
      title: '서버 응답이 늦어지고 있어요',
      message: '서버가 제때 응답하지 않았어요. 잠시 후 다시 시도해주세요.',
    ),
    RecommendationFailure.rateLimited => (
      title: '요청이 너무 많아요',
      message: '짧은 시간에 요청이 많았어요. 잠시 후 다시 시도해주세요.',
    ),
    RecommendationFailure.server => (
      title: '추천 서버에 문제가 생겼어요',
      message: '서버에서 오류가 발생했어요. 잠시 후 다시 시도해주세요.',
    ),
    RecommendationFailure.network => (
      title: '인터넷 연결을 확인해주세요',
      message: '네트워크에 연결하지 못해 $subject 불러오지 못했어요.',
    ),
    RecommendationFailure.invalidResponse => (
      title: '$subject 불러오지 못했어요',
      message: '서버 응답을 읽지 못했어요. 잠시 후 다시 시도해주세요.',
    ),
    RecommendationFailure.unknown => (
      title: '$subject 불러오지 못했어요',
      message: '잠시 후 다시 시도해주세요.',
    ),
  };
}
