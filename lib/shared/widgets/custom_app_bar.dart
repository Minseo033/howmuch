import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/howmuch_top_bar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      toolbarHeight: HowmuchTopBar.height,
      backgroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.ink),
      leadingWidth: 64,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      leading:
          leading ??
          (canPop
              ? Semantics(
                  button: true,
                  label: '뒤로가기',
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    tooltip: '뒤로가기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: HowmuchTopBar.iconSize,
                    ),
                  ),
                )
              : null),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontFamily: 'Noto Sans KR',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(HowmuchTopBar.height);
}
