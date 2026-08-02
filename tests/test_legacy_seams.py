from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACTIVE_GDSCRIPT_ROOTS = (ROOT / "godot", ROOT / "tools")
ACTIVE_CONTRACT_FILES = (
    ROOT / "docs" / "02_prd" / "prd-20260626-sprites-playground-product-v0-6.md",
    ROOT / "Makefile",
    ROOT / ".github" / "workflows" / "pr-quality.yml",
)
RETIRED_CONTRACTS = (
    "prd_v0_3_" + "runtime",
    "legacy_" + "bundle_view",
    "import_" + "legacy_bundle",
    "data/" + "v0_3",
    "res://data/" + "templates",
    "res://data/" + "moves",
    "res://data/" + "sprite_sets",
)
PRIVATE_TOOL_CALL = re.compile(r"\.\s*(_[A-Za-z][A-Za-z0-9_]*)\s*\(")
PANEL_AUTHORED_ALIAS = re.compile(
    r"\bpanel\.(template_json|sprite_set_json|moves_json)\b"
)


def _active_contract_sources() -> list[Path]:
    sources = list(ACTIVE_CONTRACT_FILES)
    for source_root in ACTIVE_GDSCRIPT_ROOTS:
        sources.extend(source_root.rglob("*.gd"))
    return sorted(sources)


class LegacySeamTests(unittest.TestCase):
    def test_active_contracts_do_not_reference_retired_runtime_or_data_seams(self) -> None:
        failures: list[str] = []
        for path in _active_contract_sources():
            text = path.read_text(encoding="utf-8")
            for retired in RETIRED_CONTRACTS:
                if retired in text:
                    failures.append(f"{path.relative_to(ROOT)} references {retired}")
        self.assertEqual([], failures, "\n".join(failures))

    def test_tools_do_not_call_private_methods(self) -> None:
        failures: list[str] = []
        for path in sorted((ROOT / "tools").rglob("*.gd")):
            for line_number, line in enumerate(
                path.read_text(encoding="utf-8").splitlines(), start=1
            ):
                for match in PRIVATE_TOOL_CALL.finditer(line):
                    failures.append(
                        f"{path.relative_to(ROOT)}:{line_number} calls {match.group(1)}"
                    )
        self.assertEqual([], failures, "\n".join(failures))

    def test_tools_read_authored_data_through_public_snapshots(self) -> None:
        failures: list[str] = []
        for path in sorted((ROOT / "tools").rglob("*.gd")):
            for line_number, line in enumerate(
                path.read_text(encoding="utf-8").splitlines(), start=1
            ):
                match = PANEL_AUTHORED_ALIAS.search(line)
                if match is not None:
                    failures.append(
                        f"{path.relative_to(ROOT)}:{line_number} reads Panel {match.group(1)}"
                    )
        self.assertEqual([], failures, "\n".join(failures))


if __name__ == "__main__":
    unittest.main()
