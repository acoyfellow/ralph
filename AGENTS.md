# RALPH CONTRACT

- PAUSED: false
- MAX_ITERATIONS_PER_RUN: 1
- MAX_FAILURE_RETRIES: 5
- REQUIRE_TESTS: true

## Memory
- git history
- scripts/ralph/progress.txt
- scripts/ralph/session.txt
- scripts/ralph/prd.json
- scripts/ralph/failure.json

## Rules
- If PAUSED is true → exit immediately.
- Do exactly ONE story per run.
- Pick first story in prd.json with status "todo".
- Set to "doing", implement, run gates, set to "done".
- If tests fail: do NOT push code changes. Failure handler will record state.
- Enforce constraints via scripts/ralph/guard.sh before committing.
- Keep changes minimal.

## Principles
- Fresh context each run (clean checkout).
- Single goal: first todo story only.
- Iterate quickly: small change, let the loop repeat.
- Declarative: acceptance lives in prd.json.

## Commands
- Typecheck: echo "No typecheck configured"
- Tests: echo "No tests configured"
PAUSED: true
