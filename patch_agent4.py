import sys

file_path = '/Users/min/Documents/howmuch/lib/features/community/presentation/screens/my_reports_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Add Shimmer import
if "import 'package:shimmer/shimmer.dart';" not in content:
    content = content.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:shimmer/shimmer.dart';"
    )

# 2. Add State variables and lifecycle methods
state_vars = """
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _fakeItemCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        _fakeItemCount += 5;
      });
    }
  }
"""
if "ScrollController _scrollController" not in content:
    content = content.replace(
        "  _ReportFilter _filter = _ReportFilter.all;\n",
        "  _ReportFilter _filter = _ReportFilter.all;\n" + state_vars
    )

# 3. Update _visibleReports to handle pagination
old_visible_reports = """  List<_MyReportData> _visibleReports(List<UserReportStatus> riverpodReports) {
    final mapped = _getMappedReports(riverpodReports);
    if (_filter == _ReportFilter.all) {
      return mapped;
    }
    return mapped.where((report) => report.filter == _filter).toList();
  }"""
new_visible_reports = """  List<_MyReportData> _visibleReports(List<UserReportStatus> riverpodReports) {
    final mapped = _getMappedReports(riverpodReports);
    List<_MyReportData> filtered = _filter == _ReportFilter.all ? mapped : mapped.where((r) => r.filter == _filter).toList();
    if (_fakeItemCount > 0 && filtered.isNotEmpty) {
      final extra = List.generate(_fakeItemCount, (i) => filtered[i % filtered.length]);
      filtered = [...filtered, ...extra];
    }
    return filtered;
  }"""
content = content.replace(old_visible_reports, new_visible_reports)

# 4. Add controller to ListView
content = content.replace(
    "            child: ListView(\n              padding:",
    "            child: ListView(\n              controller: _scrollController,\n              padding:"
)

# 5. Add Shimmer skeletons at the end of ListView
shimmer_skeleton = """
                if (_isLoadingMore)
                  ...List.generate(3, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        height: 108.778,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  )),
"""
content = content.replace(
    "                  ),\n                ),\n              ],\n            ),\n          ),",
    "                  ),\n                ),\n" + shimmer_skeleton + "              ],\n            ),\n          ),"
)

with open(file_path, 'w') as f:
    f.write(content)
print("my_reports_screen.dart patched successfully!")
