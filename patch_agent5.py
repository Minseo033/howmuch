import os

file_path = "/Users/min/Documents/howmuch/lib/features/home/presentation/screens/home_map_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Replace _SearchBar
old_search_bar = """              child: _SearchBar(
                query: _searchQuery,
                onTap: _openSearch,
                onFilterTap: () => _openSearch(openFilter: true),
              ),"""
new_search_bar = """              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _SearchBar(
                  query: _searchQuery,
                  onTap: _openSearch,
                  onFilterTap: () => _openSearch(openFilter: true),
                ),
              ),"""
content = content.replace(old_search_bar, new_search_bar)

# 2. Replace _AiRecommendControl 1
old_ai_1 = """              child: _AiRecommendControl(
                onTap: () => context.push(AppRoutes.aiRecommend),
              ),"""
new_ai_1 = """              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _AiRecommendControl(
                  onTap: () => context.push(AppRoutes.aiRecommend),
                ),
              ),"""
content = content.replace(old_ai_1, new_ai_1)

# 3. Replace _AiRecommendControl 2
old_ai_2 = """              child: _AiRecommendControl(
                onTap: () => context.push(AppRoutes.aiRecommend),
                spotlight: true,
              ),"""
new_ai_2 = """              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: _AiRecommendControl(
                  onTap: () => context.push(AppRoutes.aiRecommend),
                  spotlight: true,
                ),
              ),"""
content = content.replace(old_ai_2, new_ai_2)

# 4. Replace _StoreSummaryCard in PageView
old_store_1 = """                      child: _StoreSummaryCard(store: _currentStores[index]),"""
new_store_1 = """                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (_) {},
                        onHorizontalDragUpdate: (_) {},
                        child: _StoreSummaryCard(store: _currentStores[index]),
                      ),"""
content = content.replace(old_store_1, new_store_1)

# 5. Replace _StoreSummaryCard for selected store
old_store_2 = """                child: _StoreSummaryCard(store: _selectedStore!),"""
new_store_2 = """                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  child: _StoreSummaryCard(store: _selectedStore!),
                ),"""
content = content.replace(old_store_2, new_store_2)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Patch applied to home_map_screen.dart successfully!")
