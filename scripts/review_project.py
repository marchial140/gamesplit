"""Structural checks only; never substitutes for xcodebuild or XCTest.
Install tooling outside the checkout: pip install tree-sitter tree-sitter-swift openstep-parser
"""
from pathlib import Path
import xml.etree.ElementTree as ET
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder
root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
files = list((root / 'GameSplit').glob('*.swift')) + list((root / 'GameSplitTests').glob('*.swift'))
for path in files:
    tree = parser.parse(path.read_bytes())
    def errors(node):
        if node.type == 'ERROR' or node.is_missing:
            yield f'{path.relative_to(root)}:{node.start_point.row + 1}: {node.type}'
        for child in node.children:
            yield from errors(child)
    problems = list(errors(tree.root_node))
    assert not problems, '\n'.join(problems)
print(f'Swift syntax parsed: {len(files)} files (no type checking)')
with (root / 'GameSplit.xcodeproj/project.pbxproj').open() as stream:
    project = OpenStepDecoder.ParseFromFile(stream)
objects = project['objects']
assert project['rootObject'] in objects
for obj in objects.values():
    if obj.get('isa') == 'PBXSourcesBuildPhase':
        for build_id in obj['files']:
            ref = objects[objects[build_id]['fileRef']]
            folder = 'GameSplitTests' if ref['path'].endswith('Tests.swift') else 'GameSplit'
            assert (root / folder / ref['path']).is_file(), ref['path']
    if obj.get('isa') == 'XCBuildConfiguration':
        assert obj['buildSettings']['SWIFT_VERSION'] == '5.0'
for folder in ['GameSplit', 'GameSplitTests']:
    compiled = {objects[objects[b]['fileRef']]['path'] for o in objects.values() if o.get('isa') == 'PBXSourcesBuildPhase' for b in o['files']}
    assert all(p.name in compiled for p in (root / folder).glob('*.swift'))
ET.parse(root / 'GameSplit.xcodeproj/xcshareddata/xcschemes/GameSplit.xcscheme')
print('Xcode project references, source membership, Swift language version and scheme XML: OK')
