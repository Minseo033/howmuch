import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class DocumentSection {
  const DocumentSection({required this.title, required this.body});

  final String title;
  final String body;
}

class DocumentPage extends StatelessWidget {
  const DocumentPage({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<DocumentSection> sections;

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: title,
      subtitle: '시행일 $updatedAt',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in sections) ...[
            Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(section.body),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
