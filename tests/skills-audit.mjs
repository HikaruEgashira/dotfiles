import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  renameSync,
  symlinkSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = mkdtempSync(join(tmpdir(), "skills-audit-"));
const loader = process.argv[2];
assert.ok(loader, "pass the installed Pi skills.js path");
function audit(directory = root) {
  return spawnSync(
    process.execPath,
    ["scripts/skills-audit.mjs", loader, directory],
    { encoding: "utf8" },
  );
}
function skill(directory) {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, "SKILL.md"),
    "---\nname: example\ndescription: Test skill.\n---\n",
  );
}
try {
  const local = join(root, "example");
  const synced = join(root, "synced/bucket/example");
  skill(local);
  skill(synced);
  let result = audit();
  assert.equal(result.status, 1, result.stderr);
  assert.equal(JSON.parse(result.stdout).diagnostics[0].type, "collision");
  mkdirSync(join(root, ".trash"));
  renameSync(local, join(root, ".trash/example"));
  symlinkSync(synced, join(root, "alias"));
  result = audit();
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.deepEqual(report.diagnostics, []);
  assert.equal(report.skills.length, 1);
  assert.notEqual(audit(join(root, "missing")).status, 0);
  console.log(
    "ok: collisions, hidden backups, symlink deduplication, missing root",
  );
} finally {
  rmSync(root, { recursive: true });
}
