#!/usr/bin/env python3
"""Validate Xcode source membership, references and the source-only distribution boundary."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'alt-tab-macos.xcodeproj/project.pbxproj'


def check():
    project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(PROJECT)]))
    objects = project['objects']
    errors = []
    reference_keys = {'children', 'files', 'buildPhases', 'buildConfigurations', 'targets', 'dependencies',
                      'packageProductDependencies', 'packageReferences', 'fileRef', 'productRef', 'mainGroup',
                      'productRefGroup', 'buildConfigurationList', 'baseConfigurationReference', 'target', 'targetProxy'}
    for identifier, obj in objects.items():
        for key, value in obj.items():
            if key not in reference_keys:
                continue
            for reference in value if isinstance(value, list) else [value]:
                if reference not in objects:
                    errors.append(f'{identifier}/{key}: dangling reference {reference}')
    paths = {}

    def walk(identifier, directory=ROOT):
        obj = objects[identifier]
        if obj['isa'] in {'PBXGroup', 'PBXVariantGroup'}:
            for child in obj.get('children', []):
                walk(child, directory / obj.get('path', ''))
        elif obj['isa'] == 'PBXFileReference' and obj.get('sourceTree') in {'SOURCE_ROOT', '<group>'}:
            path = (ROOT if obj['sourceTree'] == 'SOURCE_ROOT' else directory) / obj.get('path', '')
            paths[identifier] = path
            if path.is_relative_to(ROOT) and not path.exists():
                errors.append(f'Missing project file: {path.relative_to(ROOT)}')

    walk(objects[project['rootObject']]['mainGroup'])
    counts = []
    for identifier, obj in objects.items():
        if obj['isa'] != 'PBXSourcesBuildPhase':
            continue
        files = [paths.get(objects[entry].get('fileRef')) for entry in obj.get('files', [])]
        if None in files:
            errors.append(f'{identifier}: ungrouped source reference')
        if len(files) != len(set(files)):
            errors.append(f'{identifier}: duplicate source membership')
        counts.append(len(files))
    forbidden = re.compile(r'\b(?:LicenseManager|ProTransitionManager|ProFeature|ProGatedPreferences|ProBadgeView|UpgradeTab|Day15HardGatePopover)\b|import (?:Sparkle|AppCenter)|\bURLSession\b')
    for path in (ROOT / 'src').rglob('*.swift'):
        if forbidden.search(path.read_text()):
            errors.append(f'Retired commercial/network dependency: {path.relative_to(ROOT)}')
    for directory in ['src/pro', 'vendor/AppCenter', 'vendor/Sparkle']:
        if (ROOT / directory).exists():
            errors.append(f'Retired module still present: {directory}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Xcode references and {sum(counts)} source memberships valid; no commercial/network dependencies.')


if __name__ == '__main__':
    check()
