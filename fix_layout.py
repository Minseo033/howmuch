import re

with open('lib/features/community/presentation/screens/report_create_screen.dart', 'r') as f:
    content = f.read()

content = re.sub(r"      height: 243.736,\n", "", content)
content = re.sub(r"      height: _priceInfoCardHeight\(menuPrices.length\),\n", "", content)
content = re.sub(r"      height: _photoConfirmCardHeight\(photos.length\),\n", "", content)

with open('lib/features/community/presentation/screens/report_create_screen.dart', 'w') as f:
    f.write(content)
