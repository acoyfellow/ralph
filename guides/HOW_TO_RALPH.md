# Setting Up a Ralph Loop

A Ralph loop is a disciplined workflow: **pick one story → implement → verify → commit → repeat**.

## Required Files

### 1. `AGENTS.md` (root)
Source of truth for:
- North star / stop conditions
- Absolute rules (non-negotiable)
- Local dev workflow
- Known footguns

### 2. `scripts/ralph/prd.json`
Task truth. Contains:
- `north_star`: What "done" looks like
- `goal": Current objective
- `stories[]`: Work items with:
  - `id": Unique identifier (e.g., "001")
  - `title": Short description
  - `status": "pending" | "completed"
  - `priority": "P0" | "P1" | "P2"
  - `description": What to do
  - `acceptance_criteria[]": How to verify
  - `dependencies[]": Story IDs that must complete first
  - `files_to_modify[]": Files to change
  - `test_file": Test file path
  - `verification": Command to verify
- `rules{}`: Project-specific constraints

### 3. `scripts/ralph/progress.txt`
Learnings and patterns. Update after each story.

## The Loop

1. **Pick next story**: Find highest priority `"status": "pending"` story in `prd.json`
2. **Write test first**: Create test file from story's `test_file`
3. **Implement**: Modify files from `files_to_modify[]`
4. **Verify**: Run `verification` command (must pass)
5. **Commit**: `git commit -m "feat: [ID] - [Title]"`
6. **Update tracking":
   - Set story `status` to `"completed"` in `prd.json`
   - Add learnings to `progress.txt`
7. **Repeat**: Go to step 1

## Absolute Rules

1. **PRD only**: If it's not in `prd.json`, don't do it
2. **One story per iteration**: Complete exactly one story per loop
3. **Tests first**: Write tests before implementation
4. **Verify before commit**: Run verification command, only commit if green
5. **Memory is files**: Persistent memory is git commits, `prd.json`, `progress.txt`, `CHANGELOG.md`

## Example `prd.json` Structure

```json
{
  "name": "project-refactor",
  "version": "1.0.0",
  "north_star": "Production-ready library with X pattern",
  "goal": "Transform from Y to Z",
  "stories": [
    {
      "id": "001",
      "title": "Implement feature X",
      "status": "pending",
      "priority": "P0",
      "description": "Add X to enable Y",
      "acceptance_criteria": [
        "X works",
        "Tests pass"
      ],
      "dependencies": [],
      "files_to_modify": ["src/index.ts"],
      "test_file": "test/feature-x.test.ts",
      "verification": "npm test && npm run typecheck"
    }
  ],
  "rules": {
    "tests_first": "Write tests before implementing",
    "git_checkpoints": "Commit after each story"
  }
}
```

## Example `AGENTS.md` Structure

```markdown
# AGENTS.md

## NORTH STAR / STOP CONDITION

Stop when ALL are true:
1. Production-ready artifact exists
2. Tests pass
3. Documentation matches reality

## ABSOLUTE RULES

1. Do only PRD work
2. One story per iteration
3. Tests first
4. Verify before commit
5. Memory is files (you can create new AGENTS.md in subdirectories)

## LOCAL DEV

[Your project's dev workflow]

## VERIFICATION CHECKLIST

Before committing:
- [ ] Verification command passes
- [ ] Story acceptance criteria met
- [ ] Story status updated in prd.json
- [ ] Learnings recorded in progress.txt
```

## Key Principles

- **Strict**: Follow the rules exactly
- **Minimal**: Only what's needed to track progress
- **File-based**: All state in version-controlled files
- **Incremental**: One small story at a time
- **Verified**: Never commit without passing verification