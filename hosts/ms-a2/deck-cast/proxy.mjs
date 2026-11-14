// ccdeck は Host が loopback の要求しか通さないので、Chromecast からの閲覧だけを読み取り専用で中継する
import http from "node:http";

const listenPort = Number(process.env.DECK_CAST_PORT ?? 14318);
const upstreamPort = Number(process.env.DECK_UPSTREAM_PORT ?? 4317);
const allowed = new Set(
  (process.env.DECK_CAST_ALLOW ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
);
// 共有アカウントの email・招待トークン・設定は表示に不要で、LAN に出すと鍵になる
const denied = [
  /^\/api\/lan(\/|$)/,
  /^\/api\/prefs(\/|$)/,
  /^\/api\/claude-accounts(\/|$)/,
  /^\/api\/claude-settings(\/|$)/,
  /^\/api\/tool-audit(\/|$)/,
  /^\/api\/system\/traffic-radar(\/|$)/,
  /(secret|token|invite|login|share|export|backup|credential)/i,
];

const peer = (req) => (req.socket.remoteAddress ?? "").replace(/^::ffff:/, "");

const server = http.createServer((req, res) => {
  const from = peer(req);
  const path = (req.url ?? "/").split("?")[0];
  if (!allowed.has(from) && from !== "127.0.0.1") return end(res, 403);
  if (req.method !== "GET" && req.method !== "HEAD") return end(res, 405);
  if (denied.some((re) => re.test(path))) return end(res, 404);

  const headers = {
    accept: req.headers.accept ?? "*/*",
    "accept-language": req.headers["accept-language"] ?? "ja",
    "user-agent": req.headers["user-agent"] ?? "deck-cast",
    host: `127.0.0.1:${upstreamPort}`,
    referer: `http://127.0.0.1:${upstreamPort}/`,
    "sec-fetch-site": "same-origin",
  };
  if (req.headers["last-event-id"])
    headers["last-event-id"] = req.headers["last-event-id"];

  const up = http.request(
    {
      host: "127.0.0.1",
      port: upstreamPort,
      method: req.method,
      path: req.url,
      headers,
    },
    (upstream) => {
      const out = { ...upstream.headers };
      delete out["set-cookie"];
      res.writeHead(upstream.statusCode ?? 502, out);
      upstream.pipe(res);
    },
  );
  up.on("error", () => end(res, 502));
  res.on("close", () => up.destroy());
  up.end();
});

function end(res, code) {
  if (!res.headersSent) res.writeHead(code, { "content-type": "text/plain" });
  res.end(String(code));
}

server.listen(listenPort, "0.0.0.0", () =>
  console.log(
    `deck-cast proxy :${listenPort} -> 127.0.0.1:${upstreamPort}, allow ${[...allowed].join(",")}`,
  ),
);
