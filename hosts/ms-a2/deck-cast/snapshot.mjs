// Chromecast Ultra の古い Chrome は deck の JS を実行できないので、headless Chromium で描画した画面を画像で渡す
import { spawn } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function startSnapshots({
  chromium,
  url,
  width = 1920,
  height = 1080,
  intervalMs = 5000,
  port = 9333,
}) {
  let latest = null;
  const profile = mkdtempSync(join(tmpdir(), "deck-cast-"));
  const child = spawn(
    chromium,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      "--hide-scrollbars",
      `--remote-debugging-port=${port}`,
      "--remote-debugging-address=127.0.0.1",
      `--user-data-dir=${profile}`,
      `--window-size=${width},${height}`,
      "about:blank",
    ],
    { stdio: "ignore" },
  );
  child.on("exit", (code) => {
    console.error(`deck-cast: chromium exited ${code}`);
    process.exit(1);
  });

  (async () => {
    let target;
    for (let i = 0; i < 60 && !target; i++) {
      try {
        const list = await (
          await fetch(`http://127.0.0.1:${port}/json/list`)
        ).json();
        target = list.find((t) => t.type === "page");
      } catch {
        await sleep(500);
      }
    }
    if (!target) throw new Error("chromium did not expose a page");
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let id = 0;
    const waiting = new Map();
    const call = (method, params = {}) =>
      new Promise((ok, ng) => {
        const n = ++id;
        waiting.set(n, { ok, ng });
        ws.send(JSON.stringify({ id: n, method, params }));
      });
    ws.onmessage = (e) => {
      const m = JSON.parse(e.data);
      const w = waiting.get(m.id);
      if (!w) return;
      waiting.delete(m.id);
      if (m.error) w.ng(new Error(m.error.message));
      else w.ok(m.result);
    };
    ws.onclose = () => {
      console.error("deck-cast: devtools socket closed");
      process.exit(1);
    };
    await new Promise((r) => (ws.onopen = r));
    await call("Emulation.setDeviceMetricsOverride", {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: false,
    });
    // 毎回新しい profile なので、初回ツアーの既読を localStorage に入れてから開く
    await call("Page.addScriptToEvaluateOnNewDocument", {
      source: 'try{localStorage.setItem("agent-dag.tourSeen","1")}catch(e){}',
    });
    await call("Page.navigate", { url });
    for (;;) {
      await sleep(intervalMs);
      try {
        // TV では操作できないので、初回ツアー等のモーダルは開くたびに閉じる
        const { result } = await call("Runtime.evaluate", {
          expression:
            '!!document.querySelector("[role=dialog],[aria-modal=true]")',
          returnByValue: true,
        });
        if (result?.value) {
          for (const type of ["keyDown", "keyUp"])
            await call("Input.dispatchKeyEvent", {
              type,
              key: "Escape",
              code: "Escape",
              windowsVirtualKeyCode: 27,
            });
          await sleep(300);
        }
        const { data } = await call("Page.captureScreenshot", {
          format: "jpeg",
          quality: 80,
        });
        latest = Buffer.from(data, "base64");
      } catch (err) {
        console.error(`deck-cast: screenshot ${err.message}`);
      }
    }
  })().catch((err) => {
    console.error(`deck-cast: ${err.message}`);
    process.exit(1);
  });

  return () => latest;
}

// 画像の差し替えだけを行う最小ページ。古い receiver でも動く ES5 だけで書く
export const tvPage = (
  intervalMs,
) => `<!doctype html><html><head><meta charset="utf-8"><title>ccdeck</title>
<style>html,body{margin:0;height:100%;background:#000}img{width:100%;height:100%;object-fit:contain;display:block}</style></head>
<body><img id="s" src="/tv.jpg"><script>
var s=document.getElementById("s");
setInterval(function(){var n=new Image();n.onload=function(){s.src=n.src};n.src="/tv.jpg?t="+Date.now()},${intervalMs});
</script></body></html>`;
