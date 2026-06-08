import re

with open('lib/features/community/presentation/screens/report_create_screen.dart', 'r') as f:
    content = f.read()

# Remove height: 65.98 from _EditableFormRow
content = re.sub(r"      height: 65.98,\n", "", content)

# Remove height: 41.989 from TextField Container
content = re.sub(r"            height: 41.989,\n", "", content)

# Remove height from _StepItem since it also caused an issue
content = re.sub(r"        height: 44.986,\n", "", content)

with open('lib/features/community/presentation/screens/report_create_screen.dart', 'w') as f:
    f.write(content)
