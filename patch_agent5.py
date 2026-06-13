import re

with open("lib/features/home/presentation/screens/home_map_screen.dart", "r") as f:
    code = f.read()

# Add imports
imports = """import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
"""
if "import 'package:http/http.dart' as http;" not in code:
    code = code.replace("import 'package:flutter/material.dart';", imports + "import 'package:flutter/material.dart';")

# Replace _fetchStoresFromBackend
old_fetch = """    try {
      // 서버를 호출하지 않고 _allStores에서 로컬 필터링 수행
      var stores = _allStores
          .where(
            (s) =>
                s.latitude >= minLat &&
                s.latitude <= maxLat &&
                s.longitude >= minLng &&
                s.longitude <= maxLng,
          )
          .toList();"""

new_fetch = """    try {
      String host = kIsWeb ? 'localhost' : '192.168.0.13'; 
      final url = 'http://${host}:8081/api/test/bounds?minLat=${minLat}&maxLat=${maxLat}&minLng=${minLng}&maxLng=${maxLng}';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      List<Store> fetchedStores = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        fetchedStores = data.map((json) => Store.fromJson(json)).toList();
      } else {
        // Fallback to local _allStores if backend fails
        fetchedStores = _allStores;
      }
      
      var stores = fetchedStores
          .where(
            (s) =>
                s.latitude >= minLat &&
                s.latitude <= maxLat &&
                s.longitude >= minLng &&
                s.longitude <= maxLng,
          )
          .toList();"""

code = code.replace(old_fetch, new_fetch)

with open("lib/features/home/presentation/screens/home_map_screen.dart", "w") as f:
    f.write(code)

