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
