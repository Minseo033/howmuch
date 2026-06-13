import re

with open("lib/features/search/presentation/screens/search_result_screen.dart", "r") as f:
    code = f.read()

# Replace onBack: () => context.pop(),
code = code.replace("onBack: () => context.pop(),", "onBack: () => context.pop({'query': _query, 'filter': _filter}),")

# Wrap Scaffold with PopScope
if "return Scaffold(" in code and "PopScope(" not in code:
    code = code.replace("return Scaffold(", "return PopScope(\n      canPop: false,\n      onPopInvokedWithResult: (didPop, result) {\n        if (didPop) return;\n        context.pop({'query': _query, 'filter': _filter});\n      },\n      child: Scaffold(")
    code = code.replace("    );\n  }\n}\n\n// ──────────────────────────────────────────────────────────────", "    ));\n  }\n}\n\n// ──────────────────────────────────────────────────────────────")

# Update "전체 매장 보기" button
code = code.replace("onTap: () {\n                      context.pop();\n                    },", "onTap: () {\n                      context.pop({'query': _query, 'filter': _filter});\n                    },")

with open("lib/features/search/presentation/screens/search_result_screen.dart", "w") as f:
    f.write(code)

print("search_result_screen.dart patched.")
