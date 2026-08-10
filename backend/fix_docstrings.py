import os
for filename in ['C:/outilrwa/backend/app/dashboard/models.py', 'C:/outilrwa/backend/app/dashboard/services.py']:
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix the corrupted first line quotes if they exist
    if content.startswith('\"\\\"\\\"'):
        content = '"""' + content[4:]
    
    # Fix corrupted docstrings like: \\\"\\\"\\\"
    content = content.replace('\\\"\\\"\\\"', '"""')
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)
