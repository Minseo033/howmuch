import re

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'r') as f:
    content = f.read()

# Remove _MapBackground class
content = re.sub(r"class _MapBackground extends StatelessWidget \{.*?^}$", "", content, flags=re.MULTILINE | re.DOTALL)

# Remove _Pin class
content = re.sub(r"class _Pin extends StatelessWidget \{.*?^}$", "", content, flags=re.MULTILINE | re.DOTALL)

with open('lib/features/home/presentation/screens/home_map_screen.dart', 'w') as f:
    f.write(content)
