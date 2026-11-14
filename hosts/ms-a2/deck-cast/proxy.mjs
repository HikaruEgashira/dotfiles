// Chromecast には deck を描画した画像だけを渡す。deck の API は LAN に一切出さない
import http from "node:http";
import { startSnapshots, tvPage } from "./snapshot.mjs";

const listenPort = Number(process.env.DECK_CAST_PORT ?? 14318);
const upstreamPort = Number(process.env.DECK_UPSTREAM_PORT ?? 4317);
const intervalMs = Number(process.env.DECK_CAST_REFRESH_S ?? 5) * 1000;
const allowed = new Set(
  (process.env.DECK_CAST_ALLOW ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
);

const latest = startSnapshots({
  chromium: process.env.DECK_CAST_CHROMIUM ?? "chromium",
  url: `http://127.0.0.1:${upstreamPort}/`,
  intervalMs,
});
const page = tvPage(intervalMs);

const peer = (req) => (req.socket.remoteAddress ?? "").replace(/^::ffff:/, "");

const server = http.createServer((req, res) => {
  const from = peer(req);
  const path = (req.url ?? "/").split("?")[0];
  if (!allowed.has(from) && from !== "127.0.0.1") return end(res, 403);
  if (req.method !== "GET" && req.method !== "HEAD") return end(res, 405);
  if (path === "/") {
    res.writeHead(200, {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
    });
    return res.end(page);
  }
  if (path === "/tv.jpg") {
    const img = latest();
    if (!img) return end(res, 503);
    res.writeHead(200, {
      "content-type": "image/jpeg",
      "cache-control": "no-store",
      "content-length": img.length,
    });
    return res.end(img);
  }
  if (path === "/healthz") {
    res.writeHead(latest() ? 200 : 503, { "content-type": "text/plain" });
    return res.end(latest() ? "ok" : "warming");
  }
  return end(res, 404);
});

function end(res, code) {
  if (!res.headersSent) res.writeHead(code, { "content-type": "text/plain" });
  res.end(String(code));
}

server.listen(listenPort, "0.0.0.0", () =>
  console.log(
    `deck-cast: :${listenPort} serves snapshots of 127.0.0.1:${upstreamPort}, allow ${[...allowed].join(",")}`,
  ),
);
