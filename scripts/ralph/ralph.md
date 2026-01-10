You must follow AGENTS.md.

Loop (one story):
- Stop if AGENTS.md is paused.
- Read prd.json, session.txt, progress.txt, constraints.json, failure.json (recover first if failures > 0).
- Take the first todo story → mark it doing.
- Ship the smallest change that meets acceptance.
- Gates: run typecheck/tests, then scripts/ralph/guard.sh scripts/ralph/constraints.json.
- If green: mark story done, log session.txt entry, reset failures, commit + push, exit.

Output: keep logs short, one story per run.
