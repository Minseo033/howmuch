import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a screen reader announces as an element's name: its tooltip and its
/// label, joined the way the iOS and web engines join them.
String spokenName(SemanticsNode node) {
  final data = node.getSemanticsData();
  return [data.tooltip, data.label].where((text) => text.isNotEmpty).join('\n');
}

/// The elements a screen reader can stop on whose name contains [text].
///
/// A node merged into its parent is read as part of the parent, so it is not
/// counted on its own.
SemanticsFinder readerElements(Pattern text) => find.semantics.byPredicate(
  (node) => !node.isMergedIntoParent && spokenName(node).contains(text),
  describeMatch: (_) => 'screen reader elements named "$text"',
);

/// The elements a screen reader announces exactly as [name].
SemanticsFinder readerElementsNamed(String name) => find.semantics.byPredicate(
  (node) => !node.isMergedIntoParent && spokenName(node) == name,
  describeMatch: (_) => 'screen reader elements named exactly "$name"',
);
