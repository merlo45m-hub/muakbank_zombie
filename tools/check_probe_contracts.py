#!/usr/bin/env python3
"""
Static probe-contract linter for Godot project.
Checks for contract violations in probe files.
"""
import argparse
import os
import re
import sys
from pathlib import Path


def parse_autoloads(project_godot_path: Path) -> set:
    """Parse autoload node names from project.godot [autoload] section."""
    autoloads = set()
    in_autoload = False

    with open(project_godot_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line == '[autoload]':
                in_autoload = True
                continue
            if in_autoload and line.startswith('['):
                break
            if in_autoload and '=' in line:
                name = line.split('=')[0].strip()
                if name:
                    autoloads.add(name)
    return autoloads


def find_probe_files(project_dir: Path) -> list:
    """Find all probe files in the project."""
    probes = []
    for pattern in ['tools/tests/**/*_probe.gd', 'tools/capture/**/*_probe.gd']:
        probes.extend(project_dir.glob(pattern))
    return probes


def check_violation_1_load_in_const(content: str, filepath: Path) -> list:
    """Check for const NAME = load( or const NAME: TYPE = load( violations."""
    violations = []
    pattern = re.compile(r'^\s*const\s+\w+\s*(?::\s*\w+)?\s*=\s*load\(')
    for i, line in enumerate(content.splitlines(), 1):
        if pattern.match(line):
            violations.append(f"{filepath}:{i}: const load() not allowed at parse time")
    return violations


def check_violation_2_bare_discard_loop(content: str, filepath: Path) -> list:
    """Check for `for _ in` bare discard loop variable."""
    violations = []
    pattern = re.compile(r'\bfor\s+_\s+in\b')
    for i, line in enumerate(content.splitlines(), 1):
        if pattern.search(line):
            violations.append(f"{filepath}:{i}: bare discard loop variable '_' not allowed")
    return violations


def check_violation_3_autoload_name_collision(content: str, filepath: Path, autoloads: set) -> list:
    """Check for .name = "X" where X is autoload but no get_node_or_null/remove_child."""
    violations = []
    has_get_node = 'get_node_or_null' in content
    has_remove_child = 'remove_child' in content

    for autoload in autoloads:
        pattern = re.compile(rf'\.name\s*=\s*["\']?{re.escape(autoload)}["\']?')
        for i, line in enumerate(content.splitlines(), 1):
            if pattern.search(line):
                if not (has_get_node and has_remove_child):
                    violations.append(
                        f"{filepath}:{i}: stub name '{autoload}' collides with autoload; "
                        f"missing get_node_or_null/remove_child"
                    )
    return violations


def check_violation_4_dead_stub(content: str, filepath: Path, project_dir: Path) -> list:
    """Check for load("res://tools/tests/stubs/<file>.gd") whose target is missing or has no func."""
    violations = []
    pattern = re.compile(r'load\(["\']res://tools/tests/stubs/([^"\']+)\.gd["\']\)')
    for match in pattern.finditer(content):
        stub_name = match.group(1)
        stub_path = project_dir / 'tools' / 'tests' / 'stubs' / f'{stub_name}.gd'
        if not stub_path.exists():
            violations.append(f"{filepath}: dead stub reference '{stub_name}.gd' not found")
            continue

        stub_content = stub_path.read_text()
        if not re.search(r'\bfunc\s+\w+\s*\(', stub_content):
            violations.append(f"{filepath}: dead stub '{stub_name}.gd' defines no func")
    return violations


def main():
    parser = argparse.ArgumentParser(description='Check probe contracts')
    parser.add_argument('--project-dir', required=True, help='Project directory path')
    args = parser.parse_args()

    project_dir = Path(args.project_dir).resolve()
    project_godot = project_dir / 'project.godot'

    if not project_godot.exists():
        print("PROBE_CONTRACTS: FAIL (project.godot missing)")
        return 1

    autoloads = parse_autoloads(project_godot)
    probe_files = find_probe_files(project_dir)

    if not probe_files:
        print("PROBE_CONTRACTS: FAIL (zero probe files found)")
        return 1

    all_violations = []
    for probe_file in probe_files:
        content = probe_file.read_text()
        all_violations.extend(check_violation_1_load_in_const(content, probe_file))
        all_violations.extend(check_violation_2_bare_discard_loop(content, probe_file))
        all_violations.extend(check_violation_3_autoload_name_collision(content, probe_file, autoloads))
        all_violations.extend(check_violation_4_dead_stub(content, probe_file, project_dir))

    if all_violations:
        for v in all_violations:
            print(v)
        print(f"PROBE_CONTRACTS: FAIL ({len(all_violations)} violations)")
        return 1

    print(f"PROBE_CONTRACTS: PASS ({len(probe_files)} probes)")
    return 0


if __name__ == '__main__':
    sys.exit(main())