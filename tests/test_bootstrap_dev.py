#!/usr/bin/env python3
"""Behavior tests for the development bootstrap command-line interfaces."""

from __future__ import annotations

import json
import os
import platform
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
import zipfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
INSTALL_GODOT_AI = PROJECT_ROOT / "scripts" / "install_godot_ai.py"
INSTALL_CODE_REVIEW_GRAPH = PROJECT_ROOT / "scripts" / "install_code_review_graph.py"
INSTALL_PI_PACKAGES = PROJECT_ROOT / "scripts" / "install_pi_packages.py"
BOOTSTRAP_DEV = PROJECT_ROOT / "scripts" / "bootstrap_dev.py"
PINNED_GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
PINNED_GODOT_AI_VERSION = "3.0.7"
PINNED_CODE_REVIEW_GRAPH_VERSION = "2.3.7"


def _run(*args: object, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *(str(arg) for arg in args)],
        cwd=PROJECT_ROOT,
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )


def _write_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _tool_env(temp: Path, godot_version: str = PINNED_GODOT_VERSION) -> dict[str, str]:
    bin_dir = temp / "bin"
    bin_dir.mkdir()
    _write_executable(
        bin_dir / "godot",
        f"#!/bin/sh\nprintf '%s\\n' '{godot_version}'\n",
    )
    _write_executable(bin_dir / "uv", "#!/bin/sh\nprintf '%s\\n' 'uv 0.11.7'\n")
    _write_executable(
        bin_dir / "code-review-graph",
        f"#!/bin/sh\nprintf '%s\\n' 'code-review-graph {PINNED_CODE_REVIEW_GRAPH_VERSION}'\n",
    )
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"
    return env


def _write_godot_ai_archive(
    path: Path,
    *,
    version: str = PINNED_GODOT_AI_VERSION,
    export_strip: bool = True,
) -> None:
    plugin_registration = "add_export_plugin(_export_plugin)" if export_strip else "pass"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(
            "addons/godot_ai/plugin.cfg",
            textwrap.dedent(
                f'''\
                [plugin]

                name="Godot AI"
                version="{version}"
                script="plugin.gd"
                '''
            ),
        )
        archive.writestr("addons/godot_ai/plugin.gd", plugin_registration + "\n")
        archive.writestr(
            "addons/godot_ai/export/mcp_export_plugin.gd",
            'const AUTOLOAD_KEY := "autoload/_mcp_game_helper"\n',
        )
        archive.writestr("addons/godot_ai/runtime/game_helper.gd", "extends Node\n")
        archive.writestr("addons/godot_ai/README.md", "fixture\n")
        archive.writestr("addons/godot_ai/../../escaped.txt", "must not escape\n")


def _write_ready_godot_ai(
    project_root: Path,
    *,
    version: str = PINNED_GODOT_AI_VERSION,
    export_strip: bool = True,
) -> None:
    install = project_root / "addons" / "godot_ai"
    (install / "export").mkdir(parents=True)
    (install / "runtime").mkdir()
    (install / "plugin.cfg").write_text(
        f'[plugin]\nversion="{version}"\nscript="plugin.gd"\n',
        encoding="utf-8",
    )
    registration = "add_export_plugin(_export_plugin)" if export_strip else "pass"
    (install / "plugin.gd").write_text(registration + "\n", encoding="utf-8")
    (install / "export" / "mcp_export_plugin.gd").write_text(
        'const AUTOLOAD_KEY := "autoload/_mcp_game_helper"\n',
        encoding="utf-8",
    )
    (install / "runtime" / "game_helper.gd").write_text("extends Node\n", encoding="utf-8")


def _write_code_review_graph_lock(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "package": "code-review-graph",
                "version": PINNED_CODE_REVIEW_GRAPH_VERSION,
                "command": "code-review-graph",
            }
        ),
        encoding="utf-8",
    )


def _write_pi_manifest(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "packages": [
                    {
                        "source": "npm:demo-pi@1.2.3",
                        "type": "npm",
                        "name": "demo-pi",
                        "version": "1.2.3",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )


def _write_installed_npm(home: Path, version: str = "1.2.3") -> None:
    package_dir = home / ".pi" / "agent" / "npm" / "node_modules" / "demo-pi"
    package_dir.mkdir(parents=True)
    (package_dir / "package.json").write_text(
        json.dumps({"name": "demo-pi", "version": version}),
        encoding="utf-8",
    )


def _write_ready_limboai(project_root: Path) -> None:
    install = project_root / "addons" / "limboai"
    install.mkdir(parents=True)
    (install / "version.txt").write_text("v1.8.0\n", encoding="utf-8")
    binary_names = (
        ("liblimboai.linux.editor.arm64.so", "liblimboai.linux.template_release.arm64.so")
        if platform.machine().lower() in {"aarch64", "arm64"}
        else ("liblimboai.linux.editor.x86_64.so", "liblimboai.linux.template_release.x86_64.so")
    )
    for name in binary_names:
        binary = install / "bin" / name
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.touch()


class GodotAIInstallerCLITests(unittest.TestCase):
    def test_check_accepts_only_the_pinned_dev_only_installation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-ai-installer-test-") as temp_name:
            project_root = Path(temp_name) / "project"
            _write_ready_godot_ai(project_root)

            check = _run(INSTALL_GODOT_AI, "--check", "--project-root", project_root)

            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertIn("Godot AI 3.0.7 ready", check.stdout)
            self.assertIn("export-strip ready", check.stdout)

    def test_default_ensure_skips_a_healthy_installation_without_reading_archive(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-ai-installer-test-") as temp_name:
            project_root = Path(temp_name) / "project"
            _write_ready_godot_ai(project_root)

            ensure = _run(
                INSTALL_GODOT_AI,
                "--archive",
                project_root / "does-not-exist.zip",
                "--project-root",
                project_root,
            )

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertIn("already healthy; skipping installation", ensure.stdout)

    def test_archive_install_rejects_content_that_does_not_match_the_pin(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-ai-installer-test-") as temp_name:
            temp = Path(temp_name)
            project_root = temp / "project"
            archive = temp / "godot-ai-plugin.zip"
            _write_godot_ai_archive(archive)

            install = _run(INSTALL_GODOT_AI, "--archive", archive, "--project-root", project_root)

            self.assertNotEqual(install.returncode, 0)
            self.assertIn("checksum mismatch", install.stdout + install.stderr)
            self.assertFalse((project_root / "addons" / "escaped.txt").exists())

    def test_check_rejects_plugin_without_registered_export_strip(self) -> None:
        with tempfile.TemporaryDirectory(prefix="godot-ai-installer-test-") as temp_name:
            project_root = Path(temp_name) / "project"
            _write_ready_godot_ai(project_root, export_strip=False)

            check = _run(INSTALL_GODOT_AI, "--check", "--project-root", project_root)

            self.assertNotEqual(check.returncode, 0)
            self.assertIn("export-strip", check.stdout + check.stderr)


class CodeReviewGraphInstallerCLITests(unittest.TestCase):
    def test_check_accepts_the_exact_pinned_version(self) -> None:
        with tempfile.TemporaryDirectory(prefix="code-review-graph-installer-test-") as temp_name:
            temp = Path(temp_name)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            lock = temp / "code-review-graph.lock.json"
            _write_code_review_graph_lock(lock)
            _write_executable(
                bin_dir / "code-review-graph",
                f"#!/bin/sh\nprintf '%s\\n' 'code-review-graph {PINNED_CODE_REVIEW_GRAPH_VERSION}'\n",
            )
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"

            check = _run(INSTALL_CODE_REVIEW_GRAPH, "--check", "--lock", lock, env=env)

            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertIn("code-review-graph 2.3.7 ready", check.stdout)

    def test_default_ensure_skips_a_healthy_tool_without_calling_uv(self) -> None:
        with tempfile.TemporaryDirectory(prefix="code-review-graph-installer-test-") as temp_name:
            temp = Path(temp_name)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            lock = temp / "code-review-graph.lock.json"
            _write_code_review_graph_lock(lock)
            _write_executable(
                bin_dir / "code-review-graph",
                f"#!/bin/sh\nprintf '%s\\n' 'code-review-graph {PINNED_CODE_REVIEW_GRAPH_VERSION}'\n",
            )
            _write_executable(bin_dir / "uv", "#!/bin/sh\nexit 99\n")
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"

            ensure = _run(INSTALL_CODE_REVIEW_GRAPH, "--lock", lock, env=env)

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertIn("already healthy; skipping installation", ensure.stdout)

    def test_default_ensure_installs_a_missing_tool_with_uv(self) -> None:
        with tempfile.TemporaryDirectory(prefix="code-review-graph-installer-test-") as temp_name:
            temp = Path(temp_name)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            lock = temp / "code-review-graph.lock.json"
            call_log = temp / "uv-call.txt"
            installed_command = bin_dir / "code-review-graph"
            _write_code_review_graph_lock(lock)
            _write_executable(
                bin_dir / "uv",
                "#!/bin/sh\n"
                f"printf '%s\\n' \"$*\" > '{call_log}'\n"
                f"printf '%s\\n' '#!/bin/sh' \"printf '%s\\\\n' "
                f"'code-review-graph {PINNED_CODE_REVIEW_GRAPH_VERSION}'\" > '{installed_command}'\n"
                f"/bin/chmod +x '{installed_command}'\n",
            )
            env = os.environ.copy()
            env["PATH"] = str(bin_dir)

            ensure = _run(INSTALL_CODE_REVIEW_GRAPH, "--lock", lock, env=env)

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertEqual(
                call_log.read_text(encoding="utf-8").strip(),
                "tool install --force code-review-graph==2.3.7",
            )
            self.assertIn("Installed code-review-graph==2.3.7", ensure.stdout)

    def test_check_reports_an_installed_version_mismatch_without_calling_uv(self) -> None:
        with tempfile.TemporaryDirectory(prefix="code-review-graph-installer-test-") as temp_name:
            temp = Path(temp_name)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            lock = temp / "code-review-graph.lock.json"
            _write_code_review_graph_lock(lock)
            _write_executable(
                bin_dir / "code-review-graph",
                "#!/bin/sh\nprintf '%s\\n' 'code-review-graph 9.9.9'\n",
            )
            _write_executable(bin_dir / "uv", "#!/bin/sh\nexit 99\n")
            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"

            check = _run(INSTALL_CODE_REVIEW_GRAPH, "--check", "--lock", lock, env=env)

            self.assertNotEqual(check.returncode, 0)
            output = check.stdout + check.stderr
            self.assertIn(PINNED_CODE_REVIEW_GRAPH_VERSION, output)
            self.assertIn("9.9.9", output)


class PiPackageInstallerCLITests(unittest.TestCase):
    def test_check_accepts_an_exact_installed_npm_package(self) -> None:
        with tempfile.TemporaryDirectory(prefix="pi-package-installer-test-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            manifest = temp / "pi-packages.json"
            _write_pi_manifest(manifest)
            _write_installed_npm(home)
            env = os.environ.copy()
            env["HOME"] = str(home)

            check = _run(INSTALL_PI_PACKAGES, "--check", "--manifest", manifest, env=env)

            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertIn("npm:demo-pi@1.2.3 ready", check.stdout)

    def test_default_ensure_skips_a_healthy_package_without_calling_pi(self) -> None:
        with tempfile.TemporaryDirectory(prefix="pi-package-installer-test-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            manifest = temp / "pi-packages.json"
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            _write_pi_manifest(manifest)
            _write_installed_npm(home)
            _write_executable(bin_dir / "pi", "#!/bin/sh\nexit 99\n")
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"

            ensure = _run(INSTALL_PI_PACKAGES, "--manifest", manifest, env=env)

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertIn("already healthy; skipping installation", ensure.stdout)

    def test_default_ensure_installs_only_a_missing_package_with_pi_install(self) -> None:
        with tempfile.TemporaryDirectory(prefix="pi-package-installer-test-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            manifest = temp / "pi-packages.json"
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            _write_pi_manifest(manifest)
            _write_executable(
                bin_dir / "pi",
                "#!/bin/sh\n"
                "mkdir -p \"$HOME/.pi/agent/npm/node_modules/demo-pi\"\n"
                "printf '%s\\n' \"$*\" > \"$HOME/pi-call.txt\"\n"
                "printf '%s\\n' '{\"name\":\"demo-pi\",\"version\":\"1.2.3\"}' "
                "> \"$HOME/.pi/agent/npm/node_modules/demo-pi/package.json\"\n",
            )
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{bin_dir}{os.pathsep}{env.get('PATH', '')}"

            ensure = _run(INSTALL_PI_PACKAGES, "--manifest", manifest, env=env)

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertEqual((home / "pi-call.txt").read_text(encoding="utf-8").strip(), "install npm:demo-pi@1.2.3")
            self.assertIn("Installed npm:demo-pi@1.2.3", ensure.stdout)

    def test_check_reports_an_installed_version_mismatch_without_calling_pi(self) -> None:
        with tempfile.TemporaryDirectory(prefix="pi-package-installer-test-") as temp_name:
            temp = Path(temp_name)
            home = temp / "home"
            manifest = temp / "pi-packages.json"
            _write_pi_manifest(manifest)
            _write_installed_npm(home, version="9.9.9")
            env = os.environ.copy()
            env["HOME"] = str(home)

            check = _run(INSTALL_PI_PACKAGES, "--check", "--manifest", manifest, env=env)

            self.assertNotEqual(check.returncode, 0)
            output = check.stdout + check.stderr
            self.assertIn("1.2.3", output)
            self.assertIn("9.9.9", output)


class DevelopmentBootstrapCLITests(unittest.TestCase):
    def test_default_ensure_skips_healthy_components_without_using_archives(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bootstrap-dev-test-") as temp_name:
            temp = Path(temp_name)
            project_root = temp / "project"
            _write_ready_limboai(project_root)
            _write_ready_godot_ai(project_root)

            ensure = _run(
                BOOTSTRAP_DEV,
                "--project-root",
                project_root,
                "--skip-import",
                "--skip-pi",
                "--limboai-archive",
                temp / "missing-limboai.zip",
                "--godot-ai-archive",
                temp / "missing-godot-ai.zip",
                env=_tool_env(temp),
            )

            self.assertEqual(ensure.returncode, 0, ensure.stdout + ensure.stderr)
            self.assertIn("Godot 4.7.stable.official.5b4e0cb0f ready", ensure.stdout)
            self.assertIn("LimboAI v1.8.0 already healthy", ensure.stdout)
            self.assertIn("Godot AI 3.0.7 already healthy", ensure.stdout)

    def test_check_accepts_ready_pinned_toolchain(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bootstrap-dev-test-") as temp_name:
            temp = Path(temp_name)
            project_root = temp / "project"
            _write_ready_limboai(project_root)
            _write_ready_godot_ai(project_root)
            home = temp / "home"
            manifest = temp / "pi-packages.json"
            _write_pi_manifest(manifest)
            _write_installed_npm(home)
            env = _tool_env(temp)
            env["HOME"] = str(home)

            check = _run(
                BOOTSTRAP_DEV,
                "--check",
                "--project-root",
                project_root,
                "--pi-manifest",
                manifest,
                env=env,
            )

            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertIn("development bootstrap ready", check.stdout)
            self.assertIn("LimboAI", check.stdout)
            self.assertIn("Godot AI", check.stdout)

    def test_check_rejects_a_different_godot_version(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bootstrap-dev-test-") as temp_name:
            temp = Path(temp_name)
            project_root = temp / "project"
            _write_ready_limboai(project_root)
            _write_ready_godot_ai(project_root)

            check = _run(
                BOOTSTRAP_DEV,
                "--check",
                "--project-root",
                project_root,
                "--skip-pi",
                env=_tool_env(temp, "4.7.1.stable.official.other"),
            )

            self.assertNotEqual(check.returncode, 0)
            output = check.stdout + check.stderr
            self.assertIn(PINNED_GODOT_VERSION, output)
            self.assertIn("4.7.1.stable.official.other", output)

    def test_check_reports_both_missing_addons(self) -> None:
        with tempfile.TemporaryDirectory(prefix="bootstrap-dev-test-") as temp_name:
            temp = Path(temp_name)
            check = _run(
                BOOTSTRAP_DEV,
                "--check",
                "--project-root",
                temp / "project",
                "--skip-pi",
                env=_tool_env(temp),
            )

            self.assertNotEqual(check.returncode, 0)
            output = check.stdout + check.stderr
            self.assertIn("LimboAI", output)
            self.assertIn("Godot AI", output)


if __name__ == "__main__":
    unittest.main()
