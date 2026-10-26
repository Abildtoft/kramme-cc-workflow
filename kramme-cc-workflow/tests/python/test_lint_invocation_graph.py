from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import lint_skill_contracts  # noqa: E402

PARENT = "kramme:test:parent"
CHILD = "kramme:test:child"
PARENT_PATH = f"kramme-cc-workflow/skills/{PARENT}/SKILL.md"


def handoff(line: int, shape: str, path: str = PARENT_PATH, target: str = CHILD) -> str:
    return (
        f"invocation graph: {path}:{line} hands off to {target} ({shape}), but {target} sets "
        "disable-model-invocation: true; make it a guarded child under an accepted ADR exception, "
        "rewrite the line as a user recommendation, or add an invocation_graph.allowlist entry with a reason"
    )


def hidden(line: int, path: str = PARENT_PATH, target: str = CHILD) -> str:
    return (
        f"invocation graph: {path}:{line} tells the user to run /{target}, but {target} sets "
        "user-invocable: false; make it user-invocable or reference it without a slash or dollar command"
    )


class InvocationGraphCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def _skill(
        self, name: str, body: str = "Body.", *, model_disabled: bool = False, user_invocable: str = "true"
    ) -> None:
        self._write(
            f"kramme-cc-workflow/skills/{name}/SKILL.md",
            "\n".join(
                [
                    "---",
                    f"name: {name}",
                    "description: Test skill.",
                    f"disable-model-invocation: {'true' if model_disabled else 'false'}",
                    f"user-invocable: {user_invocable}",
                    "---",
                    body,
                ]
            ),
        )

    def _run(
        self, parent_body: str, *, model_disabled: bool = True, **config: object
    ) -> lint_skill_contracts.CheckResult:
        self._skill(PARENT, parent_body)
        self._skill(CHILD, model_disabled=model_disabled)
        settings: dict[str, object] = {"allowlist": []}
        settings.update(config)
        context = lint_skill_contracts.LintContext(root=self.root, registry={"invocation_graph": settings}, schema={})
        return lint_skill_contracts.check_invocation_graph(context)

    def test_skips_when_the_registry_has_no_config(self) -> None:
        self._skill(PARENT, f"Invoke `{CHILD}`.")
        self._skill(CHILD, model_disabled=True)
        context = lint_skill_contracts.LintContext(root=self.root, registry={}, schema={})

        result = lint_skill_contracts.check_invocation_graph(context)

        self.assertEqual((result.failures, result.warnings), ([], []))

    def test_each_handoff_shape_fails_for_a_model_disabled_child(self) -> None:
        cases = {
            "invoke": f"Then invoke **`/{CHILD}`** with the plan.",
            "delegate": f"Once confirmed, it delegates to `{CHILD}` with the slices.",
            "skill-tool": f"Run `{CHILD}` via the Skill tool with the bug.",
            "engine": f"Use `{CHILD} --implement-only` as the implementation engine.",
            "conditional-use": f"Fix findings with `{CHILD}` when its structured flow fits.",
        }
        for shape, line in cases.items():
            with self.subTest(shape=shape):
                result = self._run(f"Intro.\n{line}")

                self.assertEqual(result.failures, [handoff(8, shape)])

    def test_fenced_command_reports_the_command_line(self) -> None:
        body = f"For each issue, invoke:\n\n```text\n/{CHILD} <PR_URL>\n```"

        result = self._run(body)

        self.assertEqual(result.failures, [handoff(10, "fenced-command")])

    def test_fenced_command_requires_a_command_verb_and_a_trailing_colon(self) -> None:
        for intro in ("The command looks like this:", "Otherwise, run the procedure."):
            with self.subTest(intro=intro):
                result = self._run(f"{intro}\n\n```text\n/{CHILD}\n```")

                self.assertEqual(result.failures, [])

    def test_handoffs_to_a_model_invocable_child_pass(self) -> None:
        body = "\n".join(
            [
                f"Then invoke `{CHILD}` with the plan.",
                f"It delegates to `{CHILD}`.",
                f"Use `{CHILD}` as the implementation engine.",
                "Invoke:",
                "```text",
                f"/{CHILD}",
                "```",
            ]
        )

        result = self._run(body, model_disabled=False)

        self.assertEqual(result.failures, [])

    def test_excluded_wording_passes(self) -> None:
        cases = {
            "negation": f"Do not invoke `{CHILD}` from this loop.",
            "skill-tool negation": f"Use `{CHILD}` but never via the Skill tool.",
            "user address": f"Recommend that the user invoke `{CHILD}` next.",
            "second person": f"After setup, invoke `/{CHILD}` to create your first issue.",
            "adjective": f"Return to the invoking `{CHILD}` workflow.",
            "excluded run shape": f"Run `/{CHILD}` when the audit finishes.",
            "excluded use-for shape": f"Use `{CHILD}` for the next review.",
            "stop and route": f"Route a complete set to `{CHILD} --reconcile` and stop.",
        }
        for label, line in cases.items():
            with self.subTest(label=label):
                result = self._run(line)

                self.assertEqual(result.failures, [])

    def test_fenced_lines_are_ignored_for_handoffs_but_checked_for_hidden_commands(self) -> None:
        self._skill(CHILD, user_invocable="false")
        self._skill(PARENT, f"```text\nInvoke `{CHILD}` now.\n/{CHILD}\n```")
        context = lint_skill_contracts.LintContext(
            root=self.root, registry={"invocation_graph": {"allowlist": []}}, schema={}
        )

        result = lint_skill_contracts.check_invocation_graph(context)

        self.assertEqual(result.failures, [hidden(9)])

    def test_hidden_command_rule_matches_slash_and_dollar_prefixes_only(self) -> None:
        self._skill(PARENT, f"Type `/{CHILD}`.\nOr mention `${CHILD}`.\nThe `{CHILD}` convention applies.")
        self._skill(CHILD, user_invocable="false")
        context = lint_skill_contracts.LintContext(
            root=self.root, registry={"invocation_graph": {"allowlist": []}}, schema={}
        )

        result = lint_skill_contracts.check_invocation_graph(context)

        self.assertEqual(result.failures, [hidden(7), hidden(8)])

    def test_unknown_targets_paths_and_self_references_are_ignored(self) -> None:
        self._skill(PARENT, f"Invoke `{PARENT}` again.\nInvoke `kramme:test:removed` next.", model_disabled=True)
        self._skill(CHILD, model_disabled=True)
        self._write(
            f"kramme-cc-workflow/skills/{PARENT}/references/notes.md",
            f"Read `skills/{CHILD}/SKILL.md` and invoke `kramme:test:agent`.\n",
        )
        context = lint_skill_contracts.LintContext(
            root=self.root, registry={"invocation_graph": {"allowlist": []}}, schema={}
        )

        result = lint_skill_contracts.check_invocation_graph(context)

        self.assertEqual(result.failures, [])

    def test_scans_references_shared_files_and_agents(self) -> None:
        self._skill(PARENT)
        self._skill(CHILD, model_disabled=True)
        self._write(f"kramme-cc-workflow/skills/{PARENT}/references/flow.md", f"Invoke `{CHILD}` now.\n")
        self._write("kramme-cc-workflow/shared/topic/references/flow.md", f"Invoke `{CHILD}` now.\n")
        self._write("kramme-cc-workflow/agents/kramme:test-agent.md", f"Invoke `{CHILD}` now.\n")
        context = lint_skill_contracts.LintContext(
            root=self.root, registry={"invocation_graph": {"allowlist": []}}, schema={}
        )

        result = lint_skill_contracts.check_invocation_graph(context)

        self.assertEqual(
            result.failures,
            [
                handoff(1, "invoke", path="kramme-cc-workflow/agents/kramme:test-agent.md"),
                handoff(1, "invoke", path="kramme-cc-workflow/shared/topic/references/flow.md"),
                handoff(1, "invoke", path=f"kramme-cc-workflow/skills/{PARENT}/references/flow.md"),
            ],
        )

    def test_reports_each_target_once_per_line_in_sorted_order(self) -> None:
        self._skill("kramme:test:other", model_disabled=True)
        body = "\n".join(
            [
                "Intro.",
                f"Invoke `kramme:test:other` first. Then invoke `{CHILD}` via the Skill tool.",
                f"Invoke `{CHILD}`, then delegate to `{CHILD}`.",
            ]
        )

        result = self._run(body)

        self.assertEqual(
            result.failures,
            [
                handoff(8, "invoke"),
                handoff(8, "invoke", target="kramme:test:other"),
                handoff(9, "invoke"),
            ],
        )

    def test_allowlist_suppresses_findings_and_warns_on_stale_entries(self) -> None:
        allowlist = [
            {"source": PARENT_PATH, "target": CHILD, "reason": "User-facing next step."},
            {"source": PARENT_PATH, "target": "kramme:test:gone", "reason": "Old route."},
        ]

        result = self._run(f"Invoke `{CHILD}` next.", allowlist=allowlist)

        self.assertEqual(result.failures, [])
        self.assertEqual(
            result.warnings,
            [f"invocation graph: allowlist entry {PARENT_PATH} -> kramme:test:gone matches no finding; remove it"],
        )

    def test_malformed_allowlist_entries_fail(self) -> None:
        allowlist = [
            {"source": PARENT_PATH, "target": CHILD, "reason": " "},
            {"source": "", "target": CHILD, "reason": "Why."},
            {"source": PARENT_PATH, "target": "test:child", "reason": "Why."},
            "not-an-object",
        ]

        result = self._run("Body.", allowlist=allowlist)

        self.assertEqual(
            result.failures,
            [
                f"invocation graph: allowlist entry {number} requires a source path, a kramme skill target, "
                "and a non-empty reason"
                for number in range(1, 5)
            ],
        )

    def test_allowlist_must_be_an_array(self) -> None:
        result = self._run("Body.", allowlist={"source": PARENT_PATH})

        self.assertEqual(result.failures, ["invocation graph: allowlist must be an array"])


if __name__ == "__main__":
    unittest.main()
