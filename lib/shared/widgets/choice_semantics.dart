import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Reads a choice (a chip, a sheet option, a segment) to screen readers as
/// one button that says whether it is picked.
///
/// iOS and Android hear "selected". On the web the state is "checked":
/// browsers ignore aria-selected on buttons, so Flutter's own chips make the
/// same switch. A [singleChoice] option reads as a radio button on the web.
///
/// Whatever the child exposes itself (its tap action, its text, the
/// selected: false of a ListTile) joins the same node (QA 10/7 #52).
class ChoiceSemantics extends StatelessWidget {
  const ChoiceSemantics({
    super.key,
    required this.selected,
    required this.child,
    this.label,
    this.singleChoice = false,
  });

  final bool selected;

  /// Read before the child's own text, if any, which stays in the name.
  final String? label;

  /// Exactly one option of the group is picked and picking another one
  /// replaces it.
  final bool singleChoice;

  final Widget child;

  /// Lets tests check the web semantics on the VM.
  @visibleForTesting
  static bool? debugIsWebOverride;

  @override
  Widget build(BuildContext context) {
    final web = debugIsWebOverride ?? kIsWeb;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label,
        selected: web ? null : selected,
        checked: web ? selected : null,
        inMutuallyExclusiveGroup: web && singleChoice ? true : null,
        child: child,
      ),
    );
  }
}
