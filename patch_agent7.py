import re

with open("lib/features/search/presentation/screens/search_result_screen.dart", "r") as f:
    code = f.read()

code = code.replace("Store(\n      storeName:", "Store(\n      source: 'local',\n      storeName:")

with open("lib/features/search/presentation/screens/search_result_screen.dart", "w") as f:
    f.write(code)

print("Replaced Store initializations.")
