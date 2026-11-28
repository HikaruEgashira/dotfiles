importScripts("config.js");

async function request(origin, payload) {
  try {
    const res = await fetch(`${self.BROWSER_AUTH.approver}/v1/request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...payload, origin }),
    });
    return { status: res.status, body: await res.json() };
  } catch {
    return { status: 0 };
  }
}

chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  // sender.origin はブラウザが付ける。iframe や偽の postMessage から別 origin の資格情報を引かせない
  if (msg?.type !== "request" || !sender.origin || sender.frameId !== 0) return;
  request(sender.origin, msg.payload).then(reply);
  return true;
});

async function fillActiveTab(tab) {
  const reply = await chrome.tabs
    .sendMessage(tab.id, { type: "fill" })
    .catch(() => null);
  const text = reply?.filled ? "" : "!";
  await chrome.action.setBadgeText({ tabId: tab.id, text });
}

chrome.action.onClicked.addListener(fillActiveTab);
chrome.commands.onCommand.addListener(async (cmd, tab) => {
  if (cmd === "fill") await fillActiveTab(tab);
});
