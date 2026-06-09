import os

widgets_dir = 'lib/widgets'
for root, _, files in os.walk(widgets_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()
            
            # Replace dark theme colors with light theme equivalents
            new_content = content.replace('AppColors.backgroundDark', 'AppColors.backgroundLight')
            new_content = new_content.replace('AppColors.textWhite', 'AppColors.textDark')
            new_content = new_content.replace('color: Colors.white', 'color: AppColors.textDark')
            
            if new_content != content:
                with open(path, 'w') as f:
                    f.write(new_content)
                print(f"Updated {path}")
