import sys

content = open('c:/OutilRWA/frontend/lib/modules/risque_operationnel/widgets/ro_import_bic_dialog.dart', 'r', encoding='utf-8').read()

content = content.replace("\\'", "'")
content = content.replace("_buildModeSelector(),", "")

open('c:/OutilRWA/frontend/lib/modules/risque_operationnel/widgets/ro_import_bic_dialog.dart', 'w', encoding='utf-8').write(content)
