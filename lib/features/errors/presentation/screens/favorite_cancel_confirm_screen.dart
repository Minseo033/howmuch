import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_dialog.dart';

/// 주소로 바로 들어온 찜 해제 확인 화면입니다. 찜 목록에서는 목록이 보이도록
/// [FavoriteCancelConfirmDialog]를 대화상자로 띄웁니다.
class FavoriteCancelConfirmScreen extends StatelessWidget {
  const FavoriteCancelConfirmScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    void close(bool removed) {
      if (context.canPop()) {
        context.pop(removed);
        return;
      }
      // 주소로 바로 들어온 경우 돌아갈 화면이 없으므로 찜 목록으로 보냅니다.
      context.go(AppRoutes.favoriteStores);
    }

    return FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
      child: Center(
        child: FavoriteCancelConfirmDialog(
          storeId: storeId,
          storeName: storeName,
          onClose: close,
        ),
      ),
    );
  }
}

/// 찜 해제를 확인하는 대화상자입니다. 해제했으면 true, 그대로 두면 false로 닫습니다.
class FavoriteCancelConfirmDialog extends ConsumerStatefulWidget {
  const FavoriteCancelConfirmDialog({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.onClose,
  });

  final String storeId;
  final String storeName;
  final ValueChanged<bool> onClose;

  @override
  ConsumerState<FavoriteCancelConfirmDialog> createState() =>
      _FavoriteCancelConfirmDialogState();
}

class _FavoriteCancelConfirmDialogState
    extends ConsumerState<FavoriteCancelConfirmDialog> {
  bool _busy = false;

  bool get _hasStore => widget.storeId.trim().isNotEmpty;

  Future<void> _remove() async {
    if (_busy || !_hasStore) return;
    // Logged-in visitors go on without waiting, so a quick second tap finds
    // the dialog busy.
    if (!ApiClient.isAuthenticated) {
      final loggedIn = await requireLogin(
        context,
        message: '로그인하면 이 매장의 찜을 바로 해제해요.',
      );
      if (!loggedIn || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      // Right after a login the account's favorites are not loaded yet. Read
      // them first, like the store screen's heart: removing from a list that
      // was never loaded would set the favorites count to 0.
      if (!ref.read(favoriteStoresProvider).hasValue) {
        await ref
            .read(favoriteStoresProvider.notifier)
            .loadFavorites(force: true);
        if (!mounted) return;
        if (!ref.read(favoriteStoresProvider).hasValue) {
          throw StateError('favorites not loaded');
        }
      }
      await ref
          .read(favoriteStoresProvider.notifier)
          .removeFavorite(widget.storeId);
      if (mounted) widget.onClose(true);
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
    // Keeps the favorites list alive while the dialog is open. Opened from
    // its address nothing else watches it, and an unwatched list would be
    // dropped between loading it and removing the store.
    ref.watch(favoriteStoresProvider);
    if (!_hasStore) {
      return HowmuchDialog(
        // Breaks between the phrases so the title does not wrap inside a word.
        title: '찜한 매장 정보를\n찾을 수 없어요',
        description: '찜 목록에서 다시 선택해 주세요.',
        cancelLabel: '유지하기',
        confirmLabel: '찜 해제',
        destructive: true,
        onCancel: () => widget.onClose(false),
        onConfirm: null,
      );
    }
    return HowmuchDialog(
      title: '찜을 해제할까요?',
      // Two phrases on two lines, so '꺼져요.' does not wrap on its own.
      description: '찜을 해제하면 이 매장의\n가격 변동 알림도 함께 꺼져요.',
      cancelLabel: '유지하기',
      confirmLabel: _busy ? '해제 중...' : '찜 해제',
      destructive: true,
      // Once the removal is under way the store can no longer be kept.
      cancelEnabled: !_busy,
      onCancel: () => widget.onClose(false),
      onConfirm: _busy ? null : _remove,
      // 매장명은 따로 한 줄에 보여 주고, 제목은 짧게 두어 단어 중간에서 줄이 바뀌지
      // 않게 합니다.
      child: _FavoriteStoreRow(storeName: widget.storeName),
    );
  }
}

/// The store being unfavorited, shown under the dialog's description.
class _FavoriteStoreRow extends StatelessWidget {
  const _FavoriteStoreRow({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              storeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
