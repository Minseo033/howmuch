import 'package:flutter/material.dart';

import 'app_screen_registry.dart';

class ScreenCatalogScreen extends StatelessWidget {
  const ScreenCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupedScreens = <String, int>{};
    for (final screen in appScreens) {
      groupedScreens.update(
        screen.owner,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('얼마고? 화면 목록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '전체 화면 ${appScreens.length}개',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groupedScreens.entries
                  .map(
                    (entry) =>
                        Chip(label: Text('${entry.key} ${entry.value}개')),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            for (final screen in appScreens)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${screen.figmaId} ${screen.title}'),
                  subtitle: Text('${screen.owner} · ${screen.feature}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: screen.builder));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
