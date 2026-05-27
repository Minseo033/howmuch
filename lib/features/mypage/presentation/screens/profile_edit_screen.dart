import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _regionController;
  late List<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nicknameController = TextEditingController(text: profile.nickname);
    _regionController = TextEditingController(text: profile.region);
    _selectedCategories = [...profile.favoriteCategories];
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '5-F 프로필 수정',
      subtitle: '닉네임, 관심 지역, 관심 카테고리를 수정합니다.',
      child: HowmuchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionController,
              decoration: const InputDecoration(
                labelText: '관심 지역',
                prefixIcon: Icon(Icons.place),
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('관심 카테고리'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['한식', '분식', '카페', '중식', '미용', '세탁'].map((item) {
                final selected = _selectedCategories.contains(item);

                return FilterChip(
                  label: Text(item),
                  selected: selected,
                  onSelected: (checked) {
                    setState(() {
                      if (checked) {
                        _selectedCategories.add(item);
                      } else {
                        _selectedCategories.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            HowmuchButton(label: '프로필 저장', icon: Icons.save, onPressed: _save),
          ],
        ),
      ),
    );
  }

  void _save() {
    final current = ref.read(userProfileProvider);
    ref.read(userProfileProvider.notifier).state = current.copyWith(
      nickname: _nicknameController.text.trim().isEmpty
          ? current.nickname
          : _nicknameController.text.trim(),
      region: _regionController.text.trim().isEmpty
          ? current.region
          : _regionController.text.trim(),
      favoriteCategories: _selectedCategories,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('프로필을 저장했습니다.')));
  }
}
