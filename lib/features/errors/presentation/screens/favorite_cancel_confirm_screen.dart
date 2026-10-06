import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/login_required_dialog.dart';

class FavoriteCancelConfirmScreen extends ConsumerStatefulWidget {
  const FavoriteCancelConfirmScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  ConsumerState<FavoriteCancelConfirmScreen> createState() =>
      _FavoriteCancelConfirmScreenState();
}

class _FavoriteCancelConfirmScreenState
    extends ConsumerState<FavoriteCancelConfirmScreen> {
  bool _busy = false;

  bool get _hasStore => widget.storeId.trim().isNotEmpty;

  void _close([bool removed = false]) {
    if (context.canPop()) {
      context.pop(removed);
      return;
    }
    // 주소로 바로 들어온 경우 돌아갈 화면이 없으므로 찜 목록으로 보냅니다.
    context.go(AppRoutes.favoriteStores);
  }

  Future<void> _remove() async {
    if (_busy || !_hasStore) return;
    if (!ApiClient.isAuthenticated) {
      final shouldLogin = await showLoginRequiredDialog(
        context,
        message: '찜 기능은 로그인 후 이용할 수 있어요.',
      );
      if (shouldLogin && mounted) context.push(AppRoutes.login);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(favoriteStoresProvider.notifier)
          .removeFavorite(widget.storeId);
      if (mounted) _close(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        HowmuchSnackBar(content: Text('찜 해제에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_border,
                  color: Color(0xFFF97316),
                  size: 32,
                ),
                const SizedBox(height: 20),
                Text(
                  _hasStore
                      ? '${widget.storeName} 찜을 취소할까요?'
                      : '찜한 매장 정보를 찾을 수 없어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_hasStore) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.storeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  _hasStore
                      ? '찜을 취소하면 이 매장의 가격 변동 알림도 함께 꺼져요.'
                      : '찜 목록에서 다시 선택해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        autofocus: true,
                        onPressed: _busy ? null : _close,
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy || !_hasStore ? null : _remove,
                        child: Text(_busy ? '처리 중...' : '찜 취소'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
