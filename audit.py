import os
import glob

def audit():
    screens = glob.glob('lib/features/**/*.dart', recursive=True)
    for screen in screens:
        with open(screen, 'r') as f:
            content = f.read()
        if 'FigmaMobileCanvas(' in content:
            lines = content.split('\n')
            has_bottom = False
            has_single_scroll = 'SingleChildScrollView' in content
            bottom_lines = []
            for i, line in enumerate(lines):
                if 'bottom:' in line and 'Positioned' in content:
                    # check if it's a fixed number or calculation involving 800
                    if 'bottom:' in line and not 'EdgeInsets' in line and not 'safeBottom' in line:
                        has_bottom = True
                        bottom_lines.append(line.strip())
            
            print(f"\n--- {os.path.basename(screen)} ---")
            print(f"Has SingleChildScrollView: {has_single_scroll}")
            if has_bottom:
                print(f"Has fixed bottom positioning: YES")
                for b in bottom_lines[:3]:
                    print(f"  {b}")

audit()
