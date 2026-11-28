// ページの要求を background に中継する。origin はページではなく background が sender から決める
window.addEventListener("message", (ev) => {
  if (ev.source !== window || ev.data?.__bwBridge !== "req") return;
  const { id, payload } = ev.data;
  if (payload?.kind !== "passkey") return;
  chrome.runtime.sendMessage({ type: "request", payload }, (result) => {
    window.postMessage({ __bwBridge: "res", id, result }, location.origin);
  });
});

const visible = (el) =>
  el.offsetParent !== null && !el.disabled && !el.readOnly;

function setValue(el, value) {
  const setter = Object.getOwnPropertyDescriptor(
    HTMLInputElement.prototype,
    "value",
  ).set;
  el.focus();
  setter.call(el, value);
  el.dispatchEvent(new Event("input", { bubbles: true }));
  el.dispatchEvent(new Event("change", { bubbles: true }));
}

function fill({ username, password, totp }) {
  const inputs = [...document.querySelectorAll("input")].filter(visible);
  const pw = inputs.find((i) => i.type === "password");
  const user =
    inputs.find((i) => /username|email/.test(i.autocomplete)) ||
    (pw
      ? inputs
          .slice(0, inputs.indexOf(pw))
          .reverse()
          .find((i) => ["text", "email"].includes(i.type))
      : inputs.find((i) => ["text", "email"].includes(i.type)));
  const otp = inputs.find((i) => i.autocomplete === "one-time-code");
  if (user && username) setValue(user, username);
  if (pw) setValue(pw, password);
  if (otp && totp) setValue(otp, totp);
  return Boolean(pw || user || otp);
}

chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
  if (msg?.type !== "fill") return;
  chrome.runtime.sendMessage(
    { type: "request", payload: { kind: "password" } },
    (result) => {
      reply(
        result?.status === 200
          ? { filled: fill(result.body) }
          : { error: result?.status ?? "unreachable" },
      );
    },
  );
  return true;
});
