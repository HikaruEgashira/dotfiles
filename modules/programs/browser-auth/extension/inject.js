// MAIN world で navigator.credentials.get を横取りし、passkey の署名を macbook-air に頼む
(() => {
  const orig = navigator.credentials.get.bind(navigator.credentials);
  const b64u = (buf) =>
    btoa(
      String.fromCharCode(
        ...new Uint8Array(
          buf instanceof ArrayBuffer
            ? buf
            : buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength),
        ),
      ),
    )
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  const unb64u = (s) => {
    const bin = atob(
      s.replace(/-/g, "+").replace(/_/g, "/") +
        "=".repeat((4 - (s.length % 4)) % 4),
    );
    return Uint8Array.from(bin, (c) => c.charCodeAt(0)).buffer;
  };
  let seq = 0;
  const ask = (payload) =>
    new Promise((resolve) => {
      const id = `bwb-${Date.now()}-${seq++}`;
      const onMsg = (ev) => {
        if (
          ev.source !== window ||
          ev.data?.__bwBridge !== "res" ||
          ev.data.id !== id
        )
          return;
        window.removeEventListener("message", onMsg);
        resolve(ev.data.result);
      };
      window.addEventListener("message", onMsg);
      window.postMessage({ __bwBridge: "req", id, payload }, location.origin);
    });

  navigator.credentials.get = async function (options) {
    const pk = options?.publicKey;
    // conditional mediation はページ読込ごとに呼ばれるので、スマホへの通知を出さず元の実装に任せる
    if (!pk || options.mediation === "conditional") return orig(options);
    const result = await ask({
      kind: "passkey",
      rpId: pk.rpId,
      challenge: b64u(pk.challenge),
      allowCredentials: (pk.allowCredentials || []).map((c) => b64u(c.id)),
    });
    if (result?.status === 404) return orig(options);
    if (!result || result.status !== 200)
      throw new DOMException(
        "The operation was not allowed.",
        "NotAllowedError",
      );
    const r = result.body;
    const response = {
      clientDataJSON: unb64u(r.clientDataJSON),
      authenticatorData: unb64u(r.authenticatorData),
      signature: unb64u(r.signature),
      userHandle: r.userHandle ? unb64u(r.userHandle) : null,
    };
    Object.setPrototypeOf(response, AuthenticatorAssertionResponse.prototype);
    const cred = {
      id: r.id,
      rawId: unb64u(r.rawId),
      type: "public-key",
      authenticatorAttachment: "cross-platform",
      response,
      getClientExtensionResults: () => ({}),
      toJSON: () => ({
        id: r.id,
        rawId: r.rawId,
        type: "public-key",
        authenticatorAttachment: "cross-platform",
        response: {
          clientDataJSON: r.clientDataJSON,
          authenticatorData: r.authenticatorData,
          signature: r.signature,
          userHandle: r.userHandle ?? null,
        },
        clientExtensionResults: {},
      }),
    };
    Object.setPrototypeOf(cred, PublicKeyCredential.prototype);
    return cred;
  };
})();
