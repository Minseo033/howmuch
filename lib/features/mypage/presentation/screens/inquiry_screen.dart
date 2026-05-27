import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/admin/presentation/state/admin_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '5-E 문의하기',
      subtitle: '가격 정보, 제보 검토, 계정 문제를 관리자에게 전달합니다.',
      child: _submitted ? _submittedView(context) : _formView(context),
    );
  }

  Widget _formView(BuildContext context) {
    return HowmuchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '문의 제목',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '문의 내용',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 16),
          HowmuchButton(label: '문의 제출', icon: Icons.send, onPressed: _submit),
        ],
      ),
    );
  }

  Widget _submittedView(BuildContext context) {
    return HowmuchCard(
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '문의가 접수되었습니다.',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('관리자 문의 검토 화면의 더미 목록에도 함께 추가됩니다.'),
          const SizedBox(height: 16),
          HowmuchButton(
            label: '새 문의 작성',
            icon: Icons.add,
            isPrimary: false,
            onPressed: () {
              setState(() {
                _submitted = false;
                _titleController.clear();
                _bodyController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  void _submit() {
    final profile = ref.read(userProfileProvider);
    final title = _titleController.text.trim().isEmpty
        ? '제목 없는 문의'
        : _titleController.text.trim();
    final body = _bodyController.text.trim().isEmpty
        ? '문의 내용이 입력되지 않았습니다.'
        : _bodyController.text.trim();

    ref.read(adminInquiriesProvider.notifier).state = [
      AdminInquiry(
        id: 'Q-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: title,
        author: profile.nickname,
        message: body,
        status: ReviewStatus.pending,
      ),
      ...ref.read(adminInquiriesProvider),
    ];

    setState(() => _submitted = true);
  }
}
