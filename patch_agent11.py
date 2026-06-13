import re

with open("lib/features/home/presentation/screens/home_map_screen.dart", "r") as f:
    code = f.read()

pattern = re.compile(r"      if \(response\.statusCode == 200\) \{.*?return stores.*?\}\n", re.DOTALL)

new_logic = """      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        var stores = data.map((json) => Store.fromJson(json)).toList();
        
        stores = stores.where((s) => s.latitude != 0 && s.longitude != 0).toList();

        if (_searchQuery.trim().isNotEmpty) {
          stores = stores.where((s) => s.storeName.contains(_searchQuery) || s.menu1.contains(_searchQuery) || s.industry.contains(_searchQuery) || s.address.contains(_searchQuery)).toList();
        }
        if (_searchFilter.maxPrice != null) {
          stores = stores.where((s) {
            final p = int.tryParse(s.price1.replaceAll(RegExp(r'[^0-9]'), ''));
            return p == null || p <= _searchFilter.maxPrice!;
          }).toList();
        }
        if (_searchFilter.industries.isNotEmpty) {
          stores = stores.where((s) => _searchFilter.industries.any((ind) => SearchFilter.matchesIndustry(s, ind))).toList();
        }
        if (_searchFilter.distance != null && _lastKnownPosition != null) {
          double maxDist = 0;
          if (_searchFilter.distance == '500m 이내') maxDist = 500;
          else if (_searchFilter.distance == '1km 이내') maxDist = 1000;
          else if (_searchFilter.distance == '3km 이내') maxDist = 3000;
          if (maxDist > 0) {
            stores = stores.where((s) {
              final d = Geolocator.distanceBetween(_lastKnownPosition!.latitude, _lastKnownPosition!.longitude, s.latitude, s.longitude);
              return d <= maxDist;
            }).toList();
          }
        }
        
        setState(() => _currentStores = stores);

        return stores.map((s) => {'lat': s.latitude, 'lng': s.longitude, 'title': s.storeName, 'menu': s.menu1, 'price': s.price1, 'source': s.source}).toList();
      }
"""

code = pattern.sub(new_logic, code)

with open("lib/features/home/presentation/screens/home_map_screen.dart", "w") as f:
    f.write(code)

print("home_map_screen.dart patched successfully.")
