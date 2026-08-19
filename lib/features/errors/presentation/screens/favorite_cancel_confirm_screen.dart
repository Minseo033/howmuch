import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

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

  Future<void> _remove() async {
    if (_busy || !ApiClient.isAuthenticated) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(favoriteStoresProvider.notifier)
          .removeFavorite(widget.storeId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('찜 해제에 실패했어요. 다시 시도해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    color: Color(0xFFF27E22),
                    size: 32,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '찜을 취소할까요?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.storeName,
                    style: const TextStyle(
                      color: Color(0xFF4A68F6),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '찜을 취소하면 이 매장의 가격 변동 알림도 함께 꺼져요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : _remove,
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
      ),
    );
  }
}
