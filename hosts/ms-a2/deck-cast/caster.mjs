// Cast V2 (TLS:8009 上の length-prefixed protobuf) で DashCast を起動し、TV が待機画面のときだけ deck を映し直す
import tls from "node:tls";

const device = process.env.DECK_CAST_DEVICE;
const url = process.env.DECK_CAST_URL;
const intervalMs = Number(process.env.DECK_CAST_INTERVAL_S ?? 30) * 1000;
const DASHCAST = "84912283";
const NS = {
  conn: "urn:x-cast:com.google.cast.tp.connection",
  beat: "urn:x-cast:com.google.cast.tp.heartbeat",
  recv: "urn:x-cast:com.google.cast.receiver",
  // receiver の版で es.offd / com.madmod が分かれるので、起動した app の申告から選ぶ
  dash: /dashcast$/,
};

const varint = (n) => {
  const b = [];
  while (n > 0x7f) {
    b.push((n & 0x7f) | 0x80);
    n >>>= 7;
  }
  b.push(n);
  return Buffer.from(b);
};
const field = (no, s) => {
  const v = Buffer.from(s, "utf8");
  return Buffer.concat([varint((no << 3) | 2), varint(v.length), v]);
};

export function encode(src, dst, ns, data) {
  const body = Buffer.concat([
    Buffer.from([0x08, 0x00]),
    field(2, src),
    field(3, dst),
    field(4, ns),
    Buffer.from([0x28, 0x00]),
    field(6, JSON.stringify(data)),
  ]);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(body.length);
  return Buffer.concat([len, body]);
}

export function decode(buf) {
  const out = {};
  let i = 0;
  const read = () => {
    let n = 0,
      s = 0,
      b;
    do {
      b = buf[i++];
      n |= (b & 0x7f) << s;
      s += 7;
    } while (b & 0x80);
    return n >>> 0;
  };
  while (i < buf.length) {
    const key = read(),
      no = key >> 3,
      wt = key & 7;
    if (wt === 0) {
      read();
      continue;
    }
    if (wt !== 2) break;
    const len = read();
    const s = buf.subarray(i, i + len).toString("utf8");
    i += len;
    if (no === 2) out.src = s;
    else if (no === 3) out.dst = s;
    else if (no === 4) out.ns = s;
    else if (no === 6) out.data = s;
  }
  try {
    out.data = JSON.parse(out.data);
  } catch {
    /* binary payload は使わない */
  }
  return out;
}

function session() {
  return new Promise((resolve, reject) => {
    const sock = tls.connect({
      host: device,
      port: 8009,
      rejectUnauthorized: false,
    });
    let pending = Buffer.alloc(0),
      reqId = 1;
    const waiters = new Map();
    const send = (dst, ns, data) =>
      sock.write(encode("sender-0", dst, ns, data));
    const request = (dst, ns, data) =>
      new Promise((ok, ng) => {
        const id = reqId++;
        const t = setTimeout(() => {
          waiters.delete(id);
          ng(new Error(`timeout ${data.type}`));
        }, 15000);
        waiters.set(id, (m) => {
          clearTimeout(t);
          ok(m);
        });
        send(dst, ns, { ...data, requestId: id });
      });
    sock.on("data", (chunk) => {
      pending = Buffer.concat([pending, chunk]);
      while (pending.length >= 4) {
        const len = pending.readUInt32BE(0);
        if (pending.length < 4 + len) break;
        const msg = decode(pending.subarray(4, 4 + len));
        pending = pending.subarray(4 + len);
        if (msg.ns === NS.beat && msg.data?.type === "PING")
          send(msg.src, NS.beat, { type: "PONG" });
        const w = waiters.get(msg.data?.requestId);
        if (w) {
          waiters.delete(msg.data.requestId);
          w(msg.data);
        }
      }
    });
    sock.on("error", reject);
    sock.on("secureConnect", () => {
      send("receiver-0", NS.conn, { type: "CONNECT" });
      resolve({ sock, send, request });
    });
  });
}

async function tick() {
  const s = await session();
  try {
    const status = await s.request("receiver-0", NS.recv, {
      type: "GET_STATUS",
    });
    const app = status.status?.applications?.[0];
    if (app?.appId === DASHCAST) return "showing";
    if (app && !app.isIdleScreen) return `busy:${app.displayName}`;
    const launched = await s.request("receiver-0", NS.recv, {
      type: "LAUNCH",
      appId: DASHCAST,
    });
    const dash = launched.status?.applications?.find(
      (a) => a.appId === DASHCAST,
    );
    if (!dash) return "launch-failed";
    s.send(dash.transportId, NS.conn, { type: "CONNECT" });
    const ns = dash.namespaces?.find((n) => NS.dash.test(n.name))?.name;
    if (!ns) return "no-dashcast-namespace";
    await new Promise((r) => setTimeout(r, 500));
    s.send(dash.transportId, ns, {
      url,
      force: true,
      reload: false,
      reload_time: 0,
    });
    await new Promise((r) => setTimeout(r, 2000));
    return "cast";
  } finally {
    s.sock.destroy();
  }
}

let last = "";
async function loop() {
  try {
    const state = await tick();
    if (state !== last) console.log(`deck-cast: ${state}`);
    last = state;
  } catch (err) {
    console.error(`deck-cast: ${err.message}`);
    last = "";
  }
  setTimeout(loop, intervalMs);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (!device || !url)
    throw new Error("DECK_CAST_DEVICE and DECK_CAST_URL are required");
  loop();
}
