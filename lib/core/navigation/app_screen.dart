import 'package:flutter/widgets.dart';

typedef AppScreenBuilder = Widget Function(BuildContext context);

class AppScreen {
  const AppScreen({
    required this.figmaId,
    required this.title,
    required this.owner,
    required this.feature,
    required this.builder,
  });

  final String figmaId;
  final String title;
  final String owner;
  final String feature;
  final AppScreenBuilder builder;
}
