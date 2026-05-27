import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class ReportDeleteConfirmScreen extends StatefulWidget {
  const ReportDeleteConfirmScreen({super.key});

  @override
  State<ReportDeleteConfirmScreen> createState() =>
      _ReportDeleteConfirmScreenState();
}

class _ReportDeleteConfirmScreenState extends State<ReportDeleteConfirmScreen> {
  bool _deleted = false;

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '7-5 제보 삭제 확인',
      subtitle: '사용자가 작성한 제보를 삭제하기 전 확인하는 공통 상태 화면입니다.',
      child: HowmuchCard(
        child: Column(
          children: [
            Icon(
              _deleted ? Icons.check_circle : Icons.delete_outline,
              size: 56,
              color: _deleted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              _deleted ? '제보가 삭제되었습니다.' : '이 제보를 삭제할까요?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _deleted
                  ? '실제 서버 연동 전까지는 화면 상태만 변경됩니다.'
                  : '삭제한 제보는 검토 목록에서 사라지며 복구할 수 없습니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_deleted)
              HowmuchButton(
                label: '홈으로 이동',
                icon: Icons.home,
                onPressed: () => context.go(AppRoutes.home),
              )
            else ...[
              HowmuchButton(
                label: '삭제하기',
                icon: Icons.delete,
                onPressed: () => setState(() => _deleted = true),
              ),
              const SizedBox(height: 8),
              HowmuchButton(
                label: '취소',
                icon: Icons.arrow_back,
                isPrimary: false,
                onPressed: () => context.go(AppRoutes.mypage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
