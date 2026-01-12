# Ralph

![Ralph](ralph.webp)

Automated agent that processes stories from a PRD, implementing one story per run with strict constraints.

## How It Works

Ralph follows a simple loop:

1. **Read state**: Loads `prd.json`, `progress.txt`, `constraints.json`, `failure.json`
2. **Pick story**: Selects first story with status `"todo"` from `prd.json`
3. **Implement**: Marks story `"doing"`, implements minimal change to meet acceptance criteria
4. **Validate**: Runs typecheck/tests, then `scripts/ralph/guard.sh` to enforce constraints
5. **Complete**: If green → marks story `"done"`, commits + pushes, exits

## Configuration

### `scripts/ralph/prd.json`
Stories with `id`, `title`, `status` (`todo`/`doing`/`done`), and `acceptance` criteria.

### `scripts/ralph/constraints.json`
- **iteration**: Max files/lines changed per run
- **scope**: Allowed/denied file paths
- **dependencies**: Whether dependency changes are allowed

### `AGENTS.md`
Contract defining rules:
- `PAUSED`: If `true`, agent exits immediately
- `MAX_ITERATIONS_PER_RUN`: Stories per run (default: 1)
- `REQUIRE_TESTS`: Whether tests must pass

## Guard System

`scripts/ralph/guard.sh` enforces constraints before commit:
- File count limits
- Line change limits
- Path restrictions
- Dependency change restrictions

## State Files

**Core state** (defines repo status):
- `prd.json`: Stories with status (`todo`/`doing`/`done`)
- `failure.json`: Failure tracking and recovery state

**Auxiliary state**:
- `progress.txt`: Learnings and conventions

## Principles

- **One story per run**: Small, focused changes
- **Fresh context**: Clean checkout each run
- **Declarative**: Acceptance lives in PRD, not code
- **Fail fast**: Never push failing tests

## GitHub Actions Automation

Ralph runs automatically via GitHub Actions, creating a self-perpetuating loop:

1. **Trigger**: Workflow runs on:
   - Manual trigger (`workflow_dispatch`)
   - Bot push to `AGENTS.md` or `scripts/ralph/**` (only ralph-bot commits trigger auto-runs; human commits are filtered)

2. **Execution**:
   - Checks if `PAUSED: false` (exits early if paused)
   - Validates prerequisites (AGENTS.md, prd.json, etc.)
   - Sets up environment (Node.js, OpenCode, API keys)
   - Runs one Ralph iteration via OpenCode
   - Validates changes (typecheck/tests)
   - Enforces constraints via `guard.sh`

3. **Success Path**:
   - Commits changes as `agent-ralph`
   - Pushes to `main`
   - Push triggers next workflow run (loop continues)

4. **Failure Path**:
   - Records failure in `failure.json`
   - Commits failure state
   - If failures ≥ `MAX_FAILURE_RETRIES`, auto-sets `PAUSED: true`
   - Pushes failure state (triggers next run to retry, unless paused)

**The Loop**: Each successful push triggers the next run, so Ralph processes stories continuously until:
- No more `"todo"` stories exist
- `PAUSED: true` is set
- Workflow is manually stopped

## Usage

Ralph runs via CI or locally. Ensure `AGENTS.md` has `PAUSED: false` to enable runs.
