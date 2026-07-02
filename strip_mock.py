import re

def strip_mock_data():
    path = r'c:\OutilRWA\frontend\lib\core\services\rwa_api_service.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = re.sub(r'this\.useMockData\s*=\s*true,?\n\s*', '', content)
    content = re.sub(r'final bool useMockData;\n\s*', '', content)
    
    lines = content.split('\n')
    new_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        if 'if (useMockData)' in line:
            mock_brace_level = 1
            j = i + 1
            while mock_brace_level > 0 and j < len(lines):
                if '{' in lines[j]: mock_brace_level += lines[j].count('{')
                if '}' in lines[j]: mock_brace_level -= lines[j].count('}')
                j += 1
            i = j
            continue
            
        if 'if (!useMockData) {' in line:
            mock_brace_level = 1
            j = i + 1
            inner_lines = []
            while mock_brace_level > 0 and j < len(lines):
                if '{' in lines[j]: mock_brace_level += lines[j].count('{')
                if '}' in lines[j]: mock_brace_level -= lines[j].count('}')
                if mock_brace_level > 0:
                    inner_lines.append(lines[j])
                j += 1
            
            for il in inner_lines:
                if il.startswith('  '): new_lines.append(il[2:])
                else: new_lines.append(il)
                
            while j < len(lines):
                if 'return _buildMock' in lines[j] or 'return createExposure' in lines[j] or 'return fetchDashboard' in lines[j] or 'return previewExposure' in lines[j] or '_expositionsFuture = null;' in lines[j] or '_reportsFuture = null;' in lines[j]:
                    j += 1
                elif lines[j].strip() == '':
                    j += 1
                elif 'return;' in lines[j]:
                    j += 1
                else:
                    break
            i = j
            continue
            
        new_lines.append(line)
        i += 1
        
    content = '\n'.join(new_lines)
    
    idx = content.find('DashboardSnapshot _buildMockDashboard()')
    if idx != -1:
        idx2 = content.rfind('// ===', 0, idx)
        if idx2 != -1:
            content = content[:idx2] + '}\n'
            
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

strip_mock_data()
