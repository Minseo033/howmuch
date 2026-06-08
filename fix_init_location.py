import re

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# 1. Update _initMobileController to call _moveToCurrentLocation
pattern_mobile = r"if \(message\.message\.startsWith\('BOUNDS:'\)\) \{"
replacement_mobile = """if (message.message == 'Map Initialized on Mobile') {
            _moveToCurrentLocation();
          }
          if (message.message.startsWith('BOUNDS:')) {"""
content = content.replace(pattern_mobile, replacement_mobile)

# 2. Update _initWebMap to call _moveToCurrentLocation
pattern_web = r"_isMapInitialized = true;\n        }\);"
replacement_web = """_isMapInitialized = true;
        });
        _moveToCurrentLocation();"""
content = content.replace(pattern_web, replacement_web)

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)
