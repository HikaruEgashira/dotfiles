"""CPA の公式 catalog に、ChatGPT が今の account に配っている Codex model を足して local catalog を書く。

公式 catalog は手動 curate で upstream の新 model (gpt-daybreak-blue-latest 等) を欠くため、
Codex OAuth の `/models` を正史として general catalog の該当 plan の tier と codex-catalog を補う。
取得に失敗したら既存ファイルを残して終了する (CPA は最後に有効だった catalog を保持する)。
"""

import glob
import json
import os
import sys
import urllib.request

STATE = sys.argv[1]
CODEX_CATALOG_OUT = sys.argv[2] if len(sys.argv) > 2 else None
PROXY_MODELS = "http://127.0.0.1:8317/v1/models"
CLIENT_VERSION = "0.166.0"
GENERAL_URLS = [
    "https://raw.githubusercontent.com/router-for-me/models/refs/heads/main/models.json",
    "https://models.router-for.me/models.json",
]


def fetch(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": f"codex_cli_rs/{CLIENT_VERSION}", **(headers or {})})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def write_if_changed(path, data):
    body = json.dumps(data, indent=1, sort_keys=True) + "\n"
    try:
        if open(path).read() == body:
            return
    except FileNotFoundError:
        pass
    tmp = path + ".tmp"
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        f.write(body)
    os.replace(tmp, path)
    print(f"catalog-sync: updated {path}", file=sys.stderr)


def live_codex_models():
    for path in sorted(glob.glob(f"{STATE}/auths/codex-*.json")):
        auth = json.load(open(path))
        if auth.get("disabled") or not auth.get("access_token"):
            continue
        models = fetch(
            f"https://chatgpt.com/backend-api/codex/models?client_version={CLIENT_VERSION}",
            {
                "Authorization": f"Bearer {auth['access_token']}",
                "chatgpt-account-id": auth.get("account_id", ""),
                "originator": "codex_cli_rs",
            },
        )["models"]
        return models, auth.get("plan_type") or "pro"
    raise RuntimeError("no usable codex auth")


def general_entry(m):
    efforts = [lvl["effort"] for lvl in m.get("supported_reasoning_levels", [])]
    entry = {
        "id": m["slug"],
        "object": "model",
        "owned_by": "openai",
        "type": "openai",
        "display_name": m.get("display_name") or m["slug"],
        "description": m.get("description", ""),
        "context_length": m.get("context_window", 272000),
        "max_completion_tokens": 128000,
        "supported_parameters": ["tools"],
        "supportedInputModalities": m.get("input_modalities", ["text"]),
        "supportedOutputModalities": ["text"],
    }
    if efforts:
        entry["thinking"] = {"levels": efforts}
    return entry


def main():
    try:
        live, plan = live_codex_models()
        general = None
        for url in GENERAL_URLS:
            try:
                general = fetch(url)
                break
            except Exception as e:  # noqa: BLE001
                print(f"catalog-sync: {url}: {e}", file=sys.stderr)
        if general is None:
            raise RuntimeError("general catalog unavailable")
    except Exception as e:  # noqa: BLE001
        print(f"catalog-sync: keep previous catalog: {e}", file=sys.stderr)
        return

    codex_models = []
    for m in live:
        m = dict(m)
        m.setdefault("context_window", 272000)
        m.setdefault("max_context_window", m["context_window"])
        m.setdefault("priority", 0)
        if m.get("supported_reasoning_levels"):
            codex_models.append(m)
    write_if_changed(f"{STATE}/codex-catalog.json", {"models": codex_models})

    listed = [m for m in live if m.get("visibility") != "hide"]
    entries = general.get(f"codex-{plan}")
    if isinstance(entries, list):
        known = {e.get("id") for e in entries}
        entries.extend(general_entry(m) for m in listed if m["slug"] not in known)
    write_if_changed(f"{STATE}/models-catalog.json", general)


def export_codex_catalog():
    """Codex app は custom provider の /models を picker に使わないため、CPA が Codex に返す一覧を model_catalog_json として書き出す。"""
    try:
        key = open(f"{STATE}/client-key").read().strip()
        models = fetch(f"{PROXY_MODELS}?client_version={CLIENT_VERSION}", {"Authorization": f"Bearer {key}", "originator": "codex_cli_rs"})["models"]
    except Exception as e:  # noqa: BLE001
        print(f"catalog-sync: keep previous codex model catalog: {e}", file=sys.stderr)
        return
    write_if_changed(CODEX_CATALOG_OUT, {"models": [m for m in models if m.get("supported_reasoning_levels") is not None]})


main()
if CODEX_CATALOG_OUT:
    export_codex_catalog()
