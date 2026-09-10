import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

void leaveSettings(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
    this.footer,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: Navigator.of(context).canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBack();
    },
    child: FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: FigmaMobileCanvas.designSafePaddingOf(context).top,
              ),
              child: Material(
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '뒤로',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          title,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
            if (footer != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .45,
                ),
                child: SingleChildScrollView(
                  child: Material(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        12 +
                            FigmaMobileCanvas.designSafePaddingOf(
                              context,
                            ).bottom,
                      ),
                      child: footer,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.children, this.title});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class SettingsLink extends StatelessWidget {
  const SettingsLink({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    minVerticalPadding: 12,
    leading: icon == null
        ? null
        : Icon(icon, size: 22, color: AppColors.textMuted),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
    onTap: onTap,
  );
}

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    title: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.5)),
    ),
    value: value,
    onChanged: onChanged,
  );
}

class SettingsMessage extends StatelessWidget {
  const SettingsMessage(
    this.message, {
    super.key,
    this.action,
    this.onAction,
    this.isError = false,
  });
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool isError;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isError ? AppColors.error : AppColors.textBody,
            ),
          ),
          if (action != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onAction, child: Text(action!)),
            ),
        ],
      ),
    ),
  );
}

class SettingsLoading extends StatelessWidget {
  const SettingsLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '설정을 불러오는 중',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        const Text('설정을 불러오는 중…', textAlign: TextAlign.center),
      ],
    ),
  );
}

/// Keeps local drafts until the server acknowledges the explicit save.
class SettingsExitGuard extends StatefulWidget {
  const SettingsExitGuard({
    super.key,
    required this.dirty,
    required this.saving,
    required this.fallback,
    required this.builder,
  });
  final bool dirty;
  final bool saving;
  final String fallback;
  final Widget Function(VoidCallback onBack) builder;
  @override
  State<SettingsExitGuard> createState() => _SettingsExitGuardState();
}

class _SettingsExitGuardState extends State<SettingsExitGuard> {
  bool _leaving = false;
  bool _asking = false;
  Future<void> _leave() async {
    if (_leaving || _asking || widget.saving) return;
    if (widget.dirty) {
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('저장하지 않고 나갈까요?'),
          content: const Text('변경한 설정은 아직 저장되지 않았어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('변경 취소하고 나가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 편집'),
            ),
          ],
        ),
      );
      _asking = false;
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) leaveSettings(context, widget.fallback);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!widget.dirty && !widget.saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: widget.builder(_leave),
  );
}
