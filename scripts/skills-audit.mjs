import { realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const [loader, requestedRoot] = process.argv.slice(2);
const root = realpathSync(
  requestedRoot ?? resolve(homedir(), ".agents/skills"),
);
if (!statSync(root).isDirectory())
  throw new Error("skill root must be a directory");
const { loadSkills } = await import(pathToFileURL(loader).href);
const result = loadSkills({
  cwd: root,
  agentDir: root,
  skillPaths: [root],
  includeDefaults: false,
});
console.log(JSON.stringify(result, null, 2));
process.exitCode = result.diagnostics.length === 0 ? 0 : 1;
