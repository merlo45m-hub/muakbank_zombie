#!/usr/bin/env python3
"""
Tests for check_probe_contracts.py using temp fixture trees.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class TestProbeContracts(unittest.TestCase):
    def run_linter(self, project_dir: Path) -> tuple:
        """Run the linter and return (returncode, stdout, stderr)."""
        script = Path(__file__).parent.parent / 'check_probe_contracts.py'
        result = subprocess.run(
            [sys.executable, str(script), '--project-dir', str(project_dir)],
            capture_output=True,
            text=True
        )
        return result.returncode, result.stdout, result.stderr

    def create_fixture(self, files: dict) -> Path:
        """Create a temporary directory with the given file structure."""
        tmpdir = Path(tempfile.mkdtemp())
        for rel_path, content in files.items():
            full_path = tmpdir / rel_path
            full_path.parent.mkdir(parents=True, exist_ok=True)
            full_path.write_text(content)
        return tmpdir

    def test_pass_healthy_probes(self):
        """Test PASS on healthy probes with no violations."""
        files = {
            'project.godot': '''[application]

config/name="Test"
config/icon=""

[autoload]
GameManager="*res://autoload/GameManager.gd"
EventBus="*res://autoload/EventBus.gd"
''',
            'tools/tests/sample_probe.gd': '''extends Node

func test_something():
    var node = get_node_or_null("GameManager")
    if node:
        remove_child(node)
    assert_true(true)

func test_another():
    for i in range(10):
        pass
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 0)
            self.assertIn('PROBE_CONTRACTS: PASS (1 probes)', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_violation_1_const_load(self):
        """Test FAIL on const NAME = load( violation."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/bad_probe.gd': '''extends Node

const SCENE = load("res://scenes/Test.tscn")
const OTHER: PackedScene = load("res://other.tscn")

func test_it():
    pass
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('const load() not allowed', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_violation_2_bare_discard_loop(self):
        """Test FAIL on `for _ in` bare discard loop."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/bad_probe.gd': '''extends Node

func test_it():
    for _ in range(10):
        print("loop")
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('bare discard loop variable', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_violation_3_autoload_name_collision(self):
        """Test FAIL on .name = "X" colliding with autoload without get_node_or_null/remove_child."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
EventBus="*res://autoload/EventBus.gd"
''',
            'tools/tests/bad_probe.gd': '''extends Node

func test_it():
    var stub = Node.new()
    stub.name = "GameManager"
    add_child(stub)
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('collides with autoload', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_pass_autoload_name_with_proper_handling(self):
        """Test PASS when .name = "X" has get_node_or_null and remove_child."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/good_probe.gd': '''extends Node

func test_it():
    var existing = get_node_or_null("GameManager")
    if existing:
        remove_child(existing)
    var stub = Node.new()
    stub.name = "GameManager"
    add_child(stub)
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 0)
            self.assertIn('PROBE_CONTRACTS: PASS', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_violation_4_dead_stub_missing(self):
        """Test FAIL on load() referencing missing stub file."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/bad_probe.gd': '''extends Node

func test_it():
    var stub = load("res://tools/tests/stubs/MissingStub.gd")
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('dead stub reference', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_violation_4_dead_stub_no_func(self):
        """Test FAIL on load() referencing stub with no func."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/bad_probe.gd': '''extends Node

func test_it():
    var stub = load("res://tools/tests/stubs/EmptyStub.gd")
''',
            'tools/tests/stubs/EmptyStub.gd': '''extends Node

var some_var = 42
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('defines no func', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_pass_stub_with_func(self):
        """Test PASS when stub has a func defined."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
''',
            'tools/tests/good_probe.gd': '''extends Node

func test_it():
    var stub = load("res://tools/tests/stubs/ValidStub.gd")
''',
            'tools/tests/stubs/ValidStub.gd': '''extends Node

func setup():
    pass

func teardown():
    pass
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 0)
            self.assertIn('PROBE_CONTRACTS: PASS', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_missing_project_godot(self):
        """Test FAIL when project.godot is missing."""
        files = {
            'tools/tests/probe.gd': '''extends Node

func test_it():
    pass
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('project.godot missing', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)

    def test_fail_zero_probes(self):
        """Test FAIL when zero probe files found."""
        files = {
            'project.godot': '''[autoload]
GameManager="*res://autoload/GameManager.gd"
'''
        }
        tmpdir = self.create_fixture(files)
        try:
            code, out, err = self.run_linter(tmpdir)
            self.assertEqual(code, 1)
            self.assertIn('PROBE_CONTRACTS: FAIL', out)
            self.assertIn('zero probe files found', out)
        finally:
            import shutil
            shutil.rmtree(tmpdir)


if __name__ == '__main__':
    unittest.main()