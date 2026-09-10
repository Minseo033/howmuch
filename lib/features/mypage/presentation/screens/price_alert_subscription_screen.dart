import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';

class PriceAlertSubscriptionScreen extends ConsumerStatefulWidget {
  const PriceAlertSubscriptionScreen({super.key});
  @override
  ConsumerState<PriceAlertSubscriptionScreen> createState() =>
      _PriceAlertSubscriptionScreenState();
}

class _PriceAlertSubscriptionScreenState
    extends ConsumerState<PriceAlertSubscriptionScreen> {
  PriceAlertSettings? _draft;
  PriceAlertSettings? _saved;
  bool _saving = false;
  String? _error;
  bool _conflict = false;
  String? _success;
  bool get _dirty =>
      _draft != null && _saved != null && !_draft!.sameAs(_saved!);
  void _update(PriceAlertSettings next) {
    if (_saving) return;
    setState(() {
      _draft = next.copyWith(
        all: next.stores.isNotEmpty && next.stores.every((s) => s.enabled),
      );
      _error = null;
      _success = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
      _conflict = false;
    });
    try {
      final saved = await ref
          .read(priceAlertApiServiceProvider)
          .saveSettings(_draft!);
      if (!mounted) return;
      ref.read(priceAlertSettingsProvider.notifier).updateLocal(saved);
      setState(() {
        _draft = saved;
        _saved = saved;
        _success = '가격 알림 설정을 저장했어요.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conflict = error is PriceAlertApiException && error.statusCode == 409;
        _error = error is PriceAlertApiException
            ? error.message
            : '설정을 저장하지 못했어요. 변경 내용은 유지돼요. 다시 저장해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reload() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('설정을 다시 불러올까요?'),
          content: const Text('아직 저장하지 않은 변경 내용은 사라져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 편집'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    setState(() {
      _draft = null;
      _saved = null;
      _error = null;
      _success = null;
      _conflict = false;
    });
    ref.read(priceAlertSettingsProvider.notifier).loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceAlertSettingsProvider);
    if (_draft == null && state.hasValue) {
      _draft = state.requireValue;
      _saved = _draft;
    }
    final settings = _draft;
    return SettingsExitGuard(
      dirty: _dirty,
      saving: _saving,
      fallback: AppRoutes.notificationSettings,
      builder: (onBack) => SettingsPage(
        title: '가격 알림 구독',
        onBack: onBack,
        footer: settings == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    SettingsMessage(
                      _error!,
                      isError: true,
                      action: _conflict ? '목록 다시 불러오기' : null,
                      onAction: _saving ? null : _reload,
                    ),
                  if (_success != null) SettingsMessage(_success!),
                  FilledButton(
                    onPressed: _saving || !_dirty ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_saving ? '저장 중…' : '설정 저장'),
                    ),
                  ),
                ],
              ),
        child: settings == null
            ? state.when(
                loading: () => const SettingsLoading(),
                data: (_) => const SettingsLoading(),
                error: (error, _) {
                  final unauthorized =
                      error is PriceAlertApiException &&
                      [401, 403].contains(error.statusCode);
                  return ListView(
                    children: [
                      SettingsMessage(
                        unauthorized
                            ? '로그인 후 가격 알림을 설정할 수 있어요.'
                            : '가격 알림 목록을 불러오지 못했어요. 다시 시도해 주세요.',
                        isError: true,
                        action: unauthorized ? '로그인' : '다시 시도',
                        onAction: unauthorized
                            ? () => context.go(AppRoutes.login)
                            : _reload,
                      ),
                    ],
                  );
                },
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      '찜한 매장의 가격 변동 제보가 승인되면 알려드려요. 변경 후 ‘설정 저장’을 눌러주세요.',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                  if (settings.stores.isEmpty)
                    SettingsSection(
                      children: [
                        SettingsMessage(
                          '아직 찜한 매장이 없어요. 매장을 찜하면 여기에서 수신 여부를 선택할 수 있어요.',
                          action: '매장 찾아보기',
                          onAction: _saving
                              ? null
                              : () => context.push(AppRoutes.home),
                        ),
                      ],
                    )
                  else ...[
                    SettingsSection(
                      children: [
                        SettingsToggle(
                          title: '모든 찜 매장',
                          subtitle: '찜한 매장의 가격 알림을 한 번에 변경해요.',
                          value: settings.all,
                          onChanged: _saving
                              ? null
                              : (value) => _update(
                                  settings.copyWith(
                                    stores: [
                                      for (final store in settings.stores)
                                        store.copyWith(enabled: value),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: '매장별 알림 · ${settings.stores.length}곳',
                      children: [
                        for (final store in settings.stores)
                          SettingsToggle(
                            key: ValueKey('price-alert-${store.storeId}'),
                            title: store.storeName,
                            subtitle: store.menuName,
                            value: store.enabled,
                            onChanged: _saving
                                ? null
                                : (value) => _update(
                                    settings.copyWith(
                                      stores: [
                                        for (final current in settings.stores)
                                          current.storeId == store.storeId
                                              ? current.copyWith(enabled: value)
                                              : current,
                                      ],
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                  SettingsSection(
                    title: '알림 조건',
                    children: [
                      SettingsToggle(
                        title: '가격 인하',
                        subtitle: '가격이 내려간 제보가 승인될 때',
                        value: settings.notifyOnDrop,
                        onChanged: _saving
                            ? null
                            : (value) => _update(
                                settings.copyWith(notifyOnDrop: value),
                              ),
                      ),
                      SettingsToggle(
                        title: '가격 인상',
                        subtitle: '가격이 오른 제보가 승인될 때',
                        value: settings.notifyOnRise,
                        onChanged: _saving
                            ? null
                            : (value) => _update(
                                settings.copyWith(notifyOnRise: value),
                              ),
                      ),
                      SettingsToggle(
                        title: '신메뉴',
                        subtitle: '새 메뉴 제보가 승인될 때',
                        value: settings.notifyOnNewMenu,
                        onChanged: _saving
                            ? null
                            : (value) => _update(
                                settings.copyWith(notifyOnNewMenu: value),
                              ),
                      ),
                    ],
                  ),
                  const SettingsMessage(
                    '매장이 없어도 알림 조건은 계정에 저장돼요. 알림 설정의 ‘가격 변동 알림’이 꺼져 있으면 발송되지 않아요.',
                  ),
                ],
              ),
      ),
    );
  }
}
