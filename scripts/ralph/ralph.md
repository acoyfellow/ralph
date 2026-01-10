You must follow AGENTS.md.

Process:
1) Read AGENTS.md. If PAUSED true: stop.
2) Read scripts/ralph/prd.json, session.txt, progress.txt, constraints.json, failure.json.
3) If failure.json.consecutiveFailures > 0, your #1 job is to get back to green.
4) Pick first story with status "todo". Set it to "doing".
5) Implement smallest possible change to satisfy acceptance.
6) Run typecheck/tests.
7) Enforce constraints: scripts/ralph/guard.sh scripts/ralph/constraints.json
8) If pass:
   - set story to "done"
   - append short log to session.txt
   - reset failure.json.consecutiveFailures to 0
9) Commit + push.
10) Exit.

Output constraints:
- Keep logs short.
- One story per run.
