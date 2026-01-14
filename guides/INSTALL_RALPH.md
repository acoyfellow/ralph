# Installing Ralph into an Existing Repository

This guide shows you how to set up a self-perpetuating **RALPH LOOP** in your repository, modeled after the reference "ralph" repo pattern.

## Outcome

Create the minimal files and GitHub Actions workflow so the loop can run one iteration at a time:
- Read state from files
- Choose exactly one story
- Implement minimal change
- Enforce guard constraints
- Commit + push
- Push re-triggers the workflow until no todo stories remain or PAUSED is true

## Non-negotiables

- **One story per run**. Small commits.
- **Never commit if guard fails**.
- Keep `AGENTS.md` short (~70 lines). Only include repeated-footgun info.
- **Persistent memory is ONLY repo files + git commits** (no hidden memory).
- Prefer docs-only scaffolding first; don't add deps unless a story requires it.

## Installation Steps

### 1. Create AGENTS.md (Root Directory)

Create `/AGENTS.md` with minimal configuration:

```markdown
# RALPH

- PAUSED: false

## Loop
1. Load prd.json → first "todo" story
2. Implement minimal change
3. Run guard: bash scripts/ralph/guard.sh scripts/ralph/constraints.json
4. Commit + push

## Commands
- Tests: echo "No tests configured"
```

**Keep it under 70 lines.** Only add project-specific commands or repeated footguns.

### 2. Create OpenCode Configuration

Create `/.opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/glm-4.7-free"
}
```

### 3. Create Ralph State Files

#### `/scripts/ralph/prd.json`

Initialize with 3–6 tiny bootstrap stories:

```json
{
  "project": "your-org/your-repo",
  "stories": [
    {
      "id": "S1",
      "title": "Boot Ralph automation scaffold",
      "status": "todo",
      "acceptance": [
        "It is verifiable by CI",
        "It is small enough for one run"
      ],
      "notes": "Keep stories tiny. 5–15 minutes of compute."
    },
    {
      "id": "S2",
      "title": "Add/verify diff guard in CI",
      "status": "todo",
      "acceptance": [
        "Guard script validates changes",
        "Workflow keeps passing guard limits"
      ]
    },
    {
      "id": "S3",
      "title": "Make README describe how to run",
      "status": "todo",
      "acceptance": [
        "README explains Ralph loop",
        "README shows how to trigger workflow"
      ]
    }
  ]
}
```

#### `/scripts/ralph/progress.txt`

```
# Progress / Learnings

## Commands
- typecheck: echo "No typecheck configured"
- test: echo "No tests configured"

## Conventions
- Small commits
- One story per run
- Never push failing tests
```

Update this file after each successful story completion with learnings.

#### `/scripts/ralph/constraints.json`

```json
{
  "version": 1,
  "iteration": {
    "maxFilesChanged": 12,
    "maxLinesChanged": 400
  },
  "scope": {
    "allowPaths": [
      "src/",
      "app/",
      "scripts/",
      "content/",
      "README.md",
      "AGENTS.md",
      "scripts/ralph/",
      ".github/workflows/",
      ".opencode/"
    ],
    "denyPaths": []
  },
  "dependencies": {
    "allowDependencyChanges": false
  }
}
```

Adjust `allowPaths` to match your repo structure. Set `allowDependencyChanges` to `true` if stories may need to add dependencies.

#### `/scripts/ralph/failure.json`

```json
{
  "consecutiveFailures": 0,
  "lastFailureSummary": "",
  "lastFailureRunUrl": "",
  "lastFailureAt": ""
}
```

This tracks failures and triggers auto-pause when `MAX_FAILURE_RETRIES` is exceeded.

#### `/scripts/ralph/guard.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CONSTRAINTS_FILE="${1:-scripts/ralph/constraints.json}"

node - <<'NODE' "$CONSTRAINTS_FILE"
const fs = require("fs");
const file = process.argv[2] || process.argv[1];
const c = JSON.parse(fs.readFileSync(file, "utf8"));

function sh(cmd) {
  const { execSync } = require("child_process");
  return execSync(cmd, { stdio: ["ignore", "pipe", "pipe"] }).toString("utf8");
}

const allow = (c.scope?.allowPaths ?? []);
const deny = (c.scope?.denyPaths ?? []);
const maxFiles = c.iteration?.maxFilesChanged ?? 999999;
const maxLines = c.iteration?.maxLinesChanged ?? 999999;
const allowDepChanges = c.dependencies?.allowDependencyChanges ?? true;

const files = sh("git diff --name-only").trim().split("\n").filter(Boolean);

if (files.length > maxFiles) {
  console.error(`❌ Guard: too many files changed (${files.length} > ${maxFiles})`);
  process.exit(2);
}

function isAllowed(path) {
  if (allow.length === 0) return true;
  return allow.some(a => a.endsWith("/") ? path.startsWith(a) : path === a);
}
function isDenied(path) {
  return deny.some(d => d.endsWith("/") ? path.startsWith(d) : path === d);
}

const badDenied = files.filter(isDenied);
if (badDenied.length) {
  console.error("❌ Guard: denied paths modified:\n" + badDenied.map(f => `- ${f}`).join("\n"));
  process.exit(3);
}

const badNotAllowed = allow.length ? files.filter(f => !isAllowed(f)) : [];
if (badNotAllowed.length) {
  console.error("❌ Guard: modified files outside allowPaths:\n" + badNotAllowed.map(f => `- ${f}`).join("\n"));
  process.exit(4);
}

if (!allowDepChanges) {
  const depFiles = ["package.json","package-lock.json","pnpm-lock.yaml","yarn.lock","bun.lockb","bun.lock"];
  const badDeps = files.filter(f => depFiles.includes(f));
  if (badDeps.length) {
    console.error("❌ Guard: dependency changes are not allowed:\n" + badDeps.map(f => `- ${f}`).join("\n"));
    process.exit(5);
  }
}

const numstat = sh("git diff --numstat").trim().split("\n").filter(Boolean);
let added = 0, deleted = 0;
for (const line of numstat) {
  const [a, d] = line.split("\t");
  const A = a === "-" ? 0 : parseInt(a, 10);
  const D = d === "-" ? 0 : parseInt(d, 10);
  if (!Number.isNaN(A)) added += A;
  if (!Number.isNaN(D)) deleted += D;
}
const total = added + deleted;

if (total > maxLines) {
  console.error(`❌ Guard: too many lines changed (${total} > ${maxLines}) [added=${added}, deleted=${deleted}]`);
  process.exit(6);
}

console.log(`✅ Guard OK: files=${files.length}/${maxFiles}, lines=${total}/${maxLines}`);
NODE
```

Make it executable: `chmod +x scripts/ralph/guard.sh`

### 4. Create GitHub Actions Workflow

Create `/.github/workflows/ralph.yml`:

```yaml
name: ralph

on:
  workflow_dispatch: {}
  push:
    paths:
      - "AGENTS.md"
      - "scripts/ralph/**"

permissions:
  contents: write

concurrency:
  group: ralph-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  run:
    if: |
      github.event_name == 'workflow_dispatch' || 
      github.event.pusher.name == 'ralph-bot'
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v4

      - name: Stop if paused
        shell: bash
        run: |
          set -euo pipefail
          if grep -qE '^-\s+PAUSED:\s*true\s*$' AGENTS.md; then
            echo "PAUSED: true — exiting."
            exit 0
          fi

      - name: Validate Ralph prerequisites
        shell: bash
        run: |
          set -euo pipefail
          
          echo "Validating Ralph prerequisites..."
          
          if [ ! -f AGENTS.md ]; then
            echo "ERROR: AGENTS.md not found"
            exit 1
          fi
          
          if ! grep -qE '^-\s+PAUSED:\s*false\s*$' AGENTS.md; then
            echo "ERROR: AGENTS.md must have 'PAUSED: false'"
            exit 1
          fi
          
          if [ ! -f scripts/ralph/prd.json ]; then
            echo "ERROR: scripts/ralph/prd.json not found"
            exit 1
          fi
          
          if ! jq empty scripts/ralph/prd.json 2>/dev/null; then
            echo "ERROR: scripts/ralph/prd.json is not valid JSON"
            exit 1
          fi

          echo "All prerequisites validated successfully."

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Install OpenCode
        shell: bash
        run: |
          set -euo pipefail
          npm install -g opencode-ai

      - name: Restore OpenCode auth (optional)
        shell: bash
        env:
          OPENCODE_AUTH_JSON: ${{ secrets.OPENCODE_AUTH_JSON }}
        run: |
          set -euo pipefail
          if [ -n "${OPENCODE_AUTH_JSON:-}" ]; then
            mkdir -p ~/.local/share/opencode
            printf "%s" "$OPENCODE_AUTH_JSON" > ~/.local/share/opencode/auth.json
          fi

      - name: Run agent (one iteration)
        shell: bash
        env:
          CI: "true"
        run: |
          set -euo pipefail
          opencode run \
            --model opencode/glm-4.7-free \
            -f AGENTS.md \
            -f scripts/ralph/prd.json \
            -f scripts/ralph/progress.txt \
            -f scripts/ralph/constraints.json \
            -f scripts/ralph/failure.json \
            -- "Execute exactly ONE Ralph iteration. Follow AGENTS.md."

      - name: Typecheck/tests
        shell: bash
        run: |
          set -euo pipefail

          # Validate JSON files
          echo "Validating JSON files..."
          for file in .opencode/opencode.json scripts/ralph/*.json; do
            if ! jq empty "$file"; then
              echo "JSON validation failed for $file"
              exit 1
            fi
          done
          echo "All JSON files are valid."

          echo "No typecheck configured"
          echo "No tests configured"

      - name: Enforce constraints (diff guard)
        shell: bash
        run: |
          set -euo pipefail
          chmod +x scripts/ralph/guard.sh
          scripts/ralph/guard.sh scripts/ralph/constraints.json

      - name: Commit + push (success path)
        shell: bash
        env:
          BOT_NAME: ${{ secrets.RALPH_BOT_NAME || 'ralph-bot' }}
          BOT_EMAIL: ${{ secrets.RALPH_BOT_EMAIL || 'ralph-bot@users.noreply.github.com' }}
        run: |
          set -euo pipefail
          git config user.name "$BOT_NAME"
          git config user.email "$BOT_EMAIL"
          git add -A
          git diff --cached --quiet && { echo "No changes"; exit 0; }
          git commit -m "ralph: one iteration"
          git push

      - name: Failure handler (persist failure + retrigger)
        if: failure()
        shell: bash
        env:
          RUN_URL: ${{ format('https://github.com/{0}/actions/runs/{1}', github.repository, github.run_id) }}
          BOT_NAME: ${{ secrets.RALPH_BOT_NAME || 'ralph-bot' }}
          BOT_EMAIL: ${{ secrets.RALPH_BOT_EMAIL || 'ralph-bot@users.noreply.github.com' }}
        run: |
          set -euo pipefail

          MAX_RETRIES=$(grep -E '^-\s+MAX_FAILURE_RETRIES:' -m1 AGENTS.md | awk '{print $3}' || true)
          MAX_RETRIES=${MAX_RETRIES:-5}

          mkdir -p scripts/ralph
          if [ ! -f scripts/ralph/failure.json ]; then
            cat > scripts/ralph/failure.json <<'JSON'
          {"consecutiveFailures":0,"lastFailureSummary":"","lastFailureRunUrl":"","lastFailureAt":""}
          JSON
          fi

          node - <<'NODE'
          const fs = require("fs");
          const p = "scripts/ralph/failure.json";
          const doc = JSON.parse(fs.readFileSync(p,"utf8"));
          doc.consecutiveFailures = (doc.consecutiveFailures || 0) + 1;
          doc.lastFailureRunUrl = process.env.RUN_URL;
          doc.lastFailureAt = new Date().toISOString();
          doc.lastFailureSummary = "Workflow failed before green gates. See run URL.";
          fs.writeFileSync(p, JSON.stringify(doc, null, 2) + "\n");
          NODE

          FAILS=$(node -p "require('./scripts/ralph/failure.json').consecutiveFailures")
          echo "Consecutive failures: $FAILS / $MAX_RETRIES"

          if [ "$FAILS" -ge "$MAX_RETRIES" ]; then
            echo "Max failures reached. Auto-pausing."
            if grep -qE '^-\s+PAUSED:\s*' AGENTS.md; then
              sed -i 's/^-\s+PAUSED:\s*.*/- PAUSED: true/' AGENTS.md
            else
              echo "- PAUSED: true" >> AGENTS.md
            fi
          fi

          git config user.name "$BOT_NAME"
          git config user.email "$BOT_EMAIL"
          git add scripts/ralph/failure.json AGENTS.md
          git diff --cached --quiet && exit 1
          git commit -m "ralph: record failure ($FAILS/$MAX_RETRIES)"
          git push
```

### 5. Update README (Optional)

Add a section to your README explaining the Ralph loop:

```markdown
## Ralph Automation

This repository uses Ralph, an automated agent that processes stories from a PRD.

### How It Works

1. **Read state**: Loads `prd.json` and other state files
2. **Pick story**: Selects first story with status `"todo"`
3. **Implement**: Makes minimal change to meet acceptance criteria
4. **Validate**: Runs tests and guard constraints
5. **Complete**: Commits + pushes, triggering next iteration

### Manual Trigger

Trigger Ralph manually via GitHub Actions:
- Go to Actions → ralph workflow
- Click "Run workflow"

### Pause/Resume

Edit `AGENTS.md` and set `PAUSED: true` to stop the loop.
Set `PAUSED: false` to resume.
```

## RALPH LOOP Rules (How It Operates)

Each iteration follows this process:

1. **Load** `AGENTS.md` and state files in `scripts/ralph/`
2. **Exit if paused**: If `- PAUSED: true` → exit immediately
3. **Pick story**: In `prd.json`, find first story with `"status": "todo"`
4. **Mark doing**: Update story status to `"doing"`
5. **Implement**: Make minimal changes to satisfy acceptance criteria
6. **Verify**: Run verification commands (if specified)
7. **Guard**: Run `bash scripts/ralph/guard.sh scripts/ralph/constraints.json`
8. **On success**:
   - Mark story `"done"` in `prd.json`
   - Append learnings to `progress.txt`
   - Commit + push with bot identity
   - Push triggers next iteration
9. **On failure**:
   - Update `failure.json` (increment `consecutiveFailures`)
   - If failures exceed `MAX_FAILURE_RETRIES`, set `- PAUSED: true`
   - Commit + push failure state

## GitHub Secrets Required

### Required Secrets

**None for basic operation.** The workflow uses default GitHub token for push.

### Optional Secrets

- `OPENCODE_AUTH_JSON`: OpenCode authentication (if using paid models)
- `RALPH_BOT_NAME`: Custom bot name (default: `ralph-bot`)
- `RALPH_BOT_EMAIL`: Custom bot email (default: `ralph-bot@users.noreply.github.com`)

### Setting Up Secrets

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add secrets as needed

## Workflow Triggers

The Ralph workflow triggers on:

1. **Manual dispatch**: Click "Run workflow" in GitHub Actions
2. **Automatic on bot push**: When `ralph-bot` pushes to:
   - `AGENTS.md`
   - `scripts/ralph/**`

**Human pushes to these paths do NOT trigger auto-runs** (only manual dispatch works).

## Testing Your Setup

After creating all files:

1. **Validate JSON files**:
   ```bash
   jq empty .opencode/opencode.json
   jq empty scripts/ralph/prd.json
   jq empty scripts/ralph/constraints.json
   jq empty scripts/ralph/failure.json
   ```

2. **Test guard script**:
   ```bash
   chmod +x scripts/ralph/guard.sh
   # Make a test change
   echo "test" >> README.md
   bash scripts/ralph/guard.sh scripts/ralph/constraints.json
   git checkout README.md
   ```

3. **Commit and push**:
   ```bash
   git add -A
   git commit -m "feat: add Ralph automation"
   git push
   ```

4. **Trigger workflow manually**:
   - Go to Actions tab
   - Select "ralph" workflow
   - Click "Run workflow"

## Customization

### Adjust Constraints

Edit `scripts/ralph/constraints.json`:
- **maxFilesChanged**: Increase if stories need to modify many files
- **maxLinesChanged**: Increase for larger changes
- **allowPaths**: Add your project directories
- **allowDependencyChanges**: Set `true` if adding packages

### Add Project-Specific Commands

Update `AGENTS.md` with your build/test commands:

```markdown
## Commands
- Tests: npm test
- Build: npm run build
- Typecheck: npm run typecheck
```

Update `scripts/ralph/progress.txt` similarly.

### Configure Failure Retries

Add to `AGENTS.md`:

```markdown
- MAX_FAILURE_RETRIES: 3
```

Default is 5 retries before auto-pause.

## Troubleshooting

### Workflow doesn't trigger automatically

- Verify `ralph-bot` is the commit author
- Check that `PAUSED: false` in `AGENTS.md`
- Ensure changes are in `AGENTS.md` or `scripts/ralph/**`

### Guard fails immediately

- Check `allowPaths` in `constraints.json` includes changed files
- Verify line count is within `maxLinesChanged`
- Ensure dependency files aren't changed if `allowDependencyChanges: false`

### Workflow fails with "prerequisites not met"

- Verify `AGENTS.md` has exactly `- PAUSED: false` (with dash and space)
- Ensure `scripts/ralph/prd.json` is valid JSON
- Check all required files exist

### OpenCode authentication fails

- Add `OPENCODE_AUTH_JSON` secret if using paid models
- For free models, authentication is optional

## Best Practices

1. **Start small**: Begin with 3-6 tiny stories (5-15 min each)
2. **One concern per story**: Keep stories focused
3. **Test locally first**: Run guard script before pushing
4. **Monitor first runs**: Watch the first few iterations closely
5. **Tune AGENTS.md**: Add only repeated footguns, keep under 70 lines
6. **Update progress.txt**: Record learnings after each successful story

## Examples of Good Initial Stories

```json
{
  "id": "S1",
  "title": "Add hello world endpoint",
  "status": "todo",
  "acceptance": ["GET /hello returns 200", "Response contains 'world'"]
}
```

```json
{
  "id": "S2", 
  "title": "Add basic error handling",
  "status": "todo",
  "acceptance": ["Errors return 500", "Errors are logged"]
}
```

```json
{
  "id": "S3",
  "title": "Update README with API docs",
  "status": "todo",
  "acceptance": ["README lists all endpoints", "Each endpoint has example"]
}
```

## Architecture

```
your-repo/
├── AGENTS.md                      # Ralph configuration & rules
├── .opencode/
│   └── opencode.json             # OpenCode model config
├── .github/
│   └── workflows/
│       └── ralph.yml             # Automation workflow
└── scripts/
    └── ralph/
        ├── prd.json              # Stories to implement
        ├── progress.txt          # Learnings & conventions
        ├── constraints.json      # Guard constraints
        ├── failure.json          # Failure tracking
        └── guard.sh              # Diff validator
```

## Related Guides

- `HOW_TO_RALPH.md`: Understanding the Ralph loop pattern
- `HOW_TO_AGENTS.md`: Crafting effective AGENTS.md files

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review `scripts/ralph/failure.json` for error details
3. Verify all files match this guide's templates
4. Ensure JSON files are valid with `jq`

---

**Ready to start?** Follow the installation steps above, commit the files, and trigger your first workflow run!
