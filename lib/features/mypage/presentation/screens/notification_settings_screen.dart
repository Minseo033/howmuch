import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/widgets/settings_widgets.dart';
import 'package:howmuch/features/mypage/presentation/widgets/push_permission_card.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationSettings? _saved;
  NotificationSettings? _draft;
  bool _saving = false;
  String? _error;
  String? _success;
  bool get _dirty =>
      _draft != null && _saved != null && !(_draft!.sameAs(_saved!));

  void _update(NotificationSettings next) {
    if (_saving) return;
    setState(() {
      _draft = next.copyWith(
        all: next.price && next.report && next.review && next.todayPick,
      );
      _error = null;
      _success = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    final draft = _draft!;
    if (draft.quietHours && draft.quietStart == draft.quietEnd) {
      setState(() => _error = '방해 금지 시작 시간과 종료 시간을 다르게 선택해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final saved = await ref
          .read(notificationSettingsApiServiceProvider)
          .saveSettings(draft);
      if (!mounted) return;
      ref.read(notificationSettingsProvider.notifier).updateSettings(saved);
      setState(() {
        _draft = saved;
        _saved = saved;
        _success = '알림 설정을 저장했어요.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            error is NotificationSettingsApiException && error.isUnauthorized
            ? '로그인이 만료됐어요. 다시 로그인한 뒤 설정을 저장해 주세요.'
            : '설정을 저장하지 못했어요. 변경 내용은 유지돼요. 다시 저장해 주세요.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final value = start ? _draft!.quietStart : _draft!.quietEnd;
    final parts = value.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (int.tryParse(parts.first) ?? 22).clamp(0, 23),
        minute: (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0).clamp(
          0,
          59,
        ),
      ),
      helpText: start ? '방해 금지 시작 시간' : '방해 금지 종료 시간',
    );
    if (!mounted || picked == null || _saving) return;
    final serialized =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _update(
      start
          ? _draft!.copyWith(quietStart: serialized)
          : _draft!.copyWith(quietEnd: serialized),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationSettingsProvider);
    if (_draft == null && state.hasValue) {
      _draft = state.requireValue;
      _saved = _draft;
    }
    final settings = _draft;
    return SettingsExitGuard(
      dirty: _dirty,
      saving: _saving,
      fallback: AppRoutes.mypage,
      builder: (onBack) => SettingsPage(
        title: '알림 설정',
        onBack: onBack,
        footer: settings == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) SettingsMessage(_error!, isError: true),
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
                error: (error, _) => ListView(
                  children: [
                    SettingsMessage(
                      error is NotificationSettingsApiException &&
                              error.isUnauthorized
                          ? '로그인 후 알림 설정을 사용할 수 있어요.'
                          : '설정을 불러오지 못했어요. 다시 시도해 주세요.',
                      isError: true,
                      action:
                          error is NotificationSettingsApiException &&
                              error.isUnauthorized
                          ? '로그인'
                          : '다시 시도',
                      onAction: () {
                        if (error is NotificationSettingsApiException &&
                            error.isUnauthorized) {
                          context.go(AppRoutes.login);
                        } else {
                          ref
                              .read(notificationSettingsProvider.notifier)
                              .loadSettings();
                        }
                      },
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const PushPermissionCard(),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      '변경한 내용은 아래 ‘설정 저장’을 눌러야 적용돼요.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  SettingsSection(
                    children: [
                      SettingsToggle(
                        title: '전체 알림',
                        subtitle: '알림 유형을 한 번에 켜거나 꺼요. 기기 권한은 변경하지 않아요.',
                        value: settings.all,
                        onChanged: _saving
                            ? null
                            : (value) => _update(
                                settings.copyWith(
                                  all: value,
                                  price: value,
                                  report: value,
                                  todayPick: value,
                                  review: value,
                                ),
                              ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '알림 유형',
                    children: [
                      SettingsToggle(
                        title: '가격 변동 알림',
                        subtitle: '찜한 매장의 가격 변동 제보가 승인되면 알려드려요.',
                        value: settings.price,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  _update(settings.copyWith(price: value)),
                      ),
                      SettingsToggle(
                        title: '제보·문의·댓글 알림',
                        subtitle: '제보 처리, 문의 답변과 내 게시물의 댓글 푸시를 받아요.',
                        value: settings.report,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  _update(settings.copyWith(report: value)),
                      ),
                      SettingsToggle(
                        title: '오늘의 픽 알림',
                        subtitle: '해당 유형의 알림이 발송될 때 받아요. 자동 정기 발송은 제공하지 않아요.',
                        value: settings.todayPick,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  _update(settings.copyWith(todayPick: value)),
                      ),
                      SettingsToggle(
                        title: '리뷰 알림',
                        subtitle:
                            '해당 유형의 알림이 발송될 때 받아요. 리뷰 반응의 자동 알림은 제공하지 않아요.',
                        value: settings.review,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  _update(settings.copyWith(review: value)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    children: [
                      SettingsLink(
                        title: '가격 알림 구독',
                        subtitle: '찜한 매장별 수신 여부와 가격 변동 조건',
                        icon: Icons.storefront_outlined,
                        onTap: _saving
                            ? null
                            : () => context.push(
                                AppRoutes.priceAlertSubscription,
                              ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: '방해 금지 시간',
                    children: [
                      SettingsToggle(
                        title: '방해 금지',
                        subtitle:
                            '한국 시간 기준으로 이 시간에는 기기 푸시를 보내지 않아요. 알림함의 기록은 유지돼요.',
                        value: settings.quietHours,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  _update(settings.copyWith(quietHours: value)),
                      ),
                      if (settings.quietHours)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _pickTime(true),
                                child: Text('시작 ${settings.quietStart}'),
                              ),
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _pickTime(false),
                                child: Text('종료 ${settings.quietEnd}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SettingsMessage(
                    '마케팅 알림은 현재 제공하지 않아요. 웹 공지 팝업과 알림함 기록은 기기 푸시와 별도로 표시돼요.',
                  ),
                ],
              ),
      ),
    );
  }
}
