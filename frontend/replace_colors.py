#!/usr/bin/env python3
"""Script to replace hardcoded colors with AppColors constants."""

import re

# Read the file
file_path = r"C:\OutilRWA\frontend\lib\modules\concentration\screens\concentration_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define replacements
replacements = [
    ('_concentrationIndigo900', 'AppColors.concentrationDeeper'),
    ('_concentrationIndigo800', 'AppColors.concentrationDark'),
    ('_concentrationIndigo', 'AppColors.concentrationPrimary'),
    ('_counterpartyBlue500', 'AppColors.counterpartyBlue'),
    ('_riskWeightEadGreen', 'AppColors.riskWeightGreen'),
    ('_riskWeightEadText', 'AppColors.riskWeightText'),
    ('_riskWeightRwaBlue', 'AppColors.riskWeightDark'),
    ('_riskWeightTrack', 'AppColors.riskWeightTrack'),
    ('_riskWeightPanelAccent', 'AppColors.panelAccent'),
    ('_ratingInvestmentGreen', 'AppColors.ratingInvestment'),
    ('_zoneUemoaGreen', 'AppColors.zoneUemoa'),
    ('_zoneCemacYellow', 'AppColors.zoneCemac'),
    ('_zoneOutsideCrimson', 'AppColors.zoneOutside'),
    ('_alertConnectorCrimson', 'AppColors.alertCritical'),
    ('_prudentialCapitalBlue', 'AppColors.prudentialCapital'),
    ('_prudentialTierEmerald', 'AppColors.prudentialTier'),
    ('_prudentialSolvencyViolet', 'AppColors.prudentialSolvency'),
    ('_prudentialLeverageAmber', 'AppColors.prudentialLeverage'),
    ('_prudentialBufferRose', 'AppColors.prudentialBuffer'),
    ('_prudentialComplianceCrimson', 'AppColors.prudentialCompliance'),
    ('_qualitySapphire', 'AppColors.qualityExcellent'),
    ('_qualityIndigo', 'AppColors.qualityGood'),
    ('_qualityTeal', 'AppColors.qualityAverage'),
    ('_qualityCyan', 'AppColors.qualityFair'),
    ('_qualityViolet', 'AppColors.qualityPoor'),
]

# Apply replacements
for old, new in replacements:
    content = content.replace(old, new)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"Replaced {len(replacements)} color constants in {file_path}")
