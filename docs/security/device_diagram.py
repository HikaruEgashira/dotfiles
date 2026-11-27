# /// script
# requires-python = ">=3.11"
# dependencies = ["diagrams==0.24.4"]
# ///
"""端末ごとの内部構成を 1 端末 1 枚で (OS 層・ユーザー層・agent sandbox・資格情報・常駐) を図にする。

uv run docs/security/device_diagram.py  →  docs/security/device-<端末>.png
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.security import SecretsManager, SingleSignOn
from diagrams.generic.compute import Rack
from diagrams.aws.security import IAMRole
from diagrams.generic.network import Firewall
from diagrams.onprem.network import Internet, Powerdns
from diagrams.onprem.vcs import Github
from diagrams.onprem.client import Client
from diagrams.onprem.security import Vault

HERE = Path(__file__).parent

ALLOW = "darkgreen"
DENY = "gray"

graph = {"rankdir": "TB", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.4", "ranksep": "1.0", "splines": "ortho", "forcelabels": "true"}
node = {"fontname": "Hiragino Sans", "fontsize": "12"}
edge = {"fontname": "Hiragino Sans", "fontsize": "11"}


def deny(src, dst):
    src >> Edge(color=DENY, style="dashed", xlabel="✕") >> dst


def diagram(name):
    return Diagram(
        f"{name} の内部",
        filename=str(HERE / f"device-{name}"),
        outformat="png",
        show=False,
        graph_attr=graph,
        node_attr=node,
        edge_attr=edge,
    )


def outside(studio):
    with Cluster("外界"):
        o = {
            "lan": Internet("LAN"),
            "dns": Powerdns("NextDNS\ntelemetry denylist"),
            "tel": Internet("telemetry 送信先"),
            "gh": Github("GitHub"),
            "aws": IAMRole("AWS"),
            "cache": Internet("Nix cache\n上流 release"),
            "collector": Internet("gh-intel.com\ncollector"),
        }
        if studio is None:
            o = {k: o[k] for k in ("lan", "dns", "tel", "gh", "aws")}
    return o


def mac(name, sudo_label, gh_label, studio):
    with diagram(name):
        o = outside(studio)
        with Cluster("OS 層 nix-darwin"):
            fw = Firewall("受信遮断")
            resolver = Rack("DNS\n暗号化して問い合わせ")
            Vault(sudo_label)
            Rack("AI CLI の強制設定\ntelemetry 停止")
            Rack("tailscaled\nSSH は tailnet ACL")
            Rack("署名検証済み app")

        with Cluster("ユーザー層 home-manager"):
            pkgs = Rack("package\ncache と checksum のみ")
            with Cluster("常駐 loopback のみ"):
                sync = Rack("dotfiles-sync")
                hub = Rack("gypxy hub")
                otel = Rack("telemetry collector")
                artex = Rack("ARTEX / Postgres")
                if studio:
                    ledger = Rack("ledger")
                    Rack("CLIProxyAPI")

            with Cluster("資格情報"):
                gh = Vault(gh_label)
                aws = SingleSignOn("AWS broker")
                age = SecretsManager("age secret\nrepo ごとに渡す")
                auth = Vault("ssh 認証鍵")
                sign = Vault("署名鍵")

            with Cluster("AI agent sandbox"):
                agent = Rack("Claude Code / Codex")

        deny(o["lan"], fw)
        resolver >> Edge(color=ALLOW) >> o["dns"]
        deny(o["dns"], o["tel"])
        hub >> Edge(color=ALLOW) >> o["gh"]
        gh >> Edge(color=ALLOW) >> o["gh"]
        aws >> Edge(color=ALLOW) >> o["aws"]
        o["cache"] >> Edge(color=ALLOW, xlabel="検証して取得") >> pkgs
        otel >> Edge(color=ALLOW) >> o["collector"]

        agent >> Edge(color=ALLOW, xlabel="仲介") >> gh
        agent >> Edge(color=ALLOW, xlabel="仲介") >> aws
        agent >> Edge(color=ALLOW) >> sign
        agent >> Edge(color=ALLOW) >> otel
        for dst in (age, auth, artex):
            deny(agent, dst)
        if studio:
            ledger >> Edge(color=ALLOW) >> aws
        sync >> Edge(color=ALLOW, xlabel="適用") >> pkgs
        hub >> Edge(color=ALLOW) >> gh


mac("macbook-air", "sudo 鍵\nSecretive → Touch ID", "ghtkn\n読み取り専用", studio=False)
mac("mac-studio", "sudo\nair の鍵で署名", "ghtkn\n書き込み可", studio=True)

with diagram("ms-a2"):
    o = outside(None)
    with Cluster("OS 層 NixOS"):
        Vault("ディスク暗号化")
        net = Firewall("sshd なし\ntailnet ACL のみ")
    with Cluster("job ごとの使い捨て環境"):
        job = Rack("CI job\n専用 netns")
    runner = Rack("CI runner\ntoken なし")
    tpm = Vault("TPM 鍵")
    crunner = Rack("claude runner\n専用ユーザー")
    cenv = Vault("runner token\nroot のみ読める")
    mhub = Rack("gypxy hub")
    Rack("hikaevi")

    deny(o["lan"], net)
    runner >> Edge(color=ALLOW, xlabel="起動") >> job
    runner >> Edge(color=ALLOW) >> tpm
    tpm >> Edge(color=ALLOW, xlabel="署名で認証") >> o["aws"]
    o["aws"] >> Edge(color=ALLOW, xlabel="token を発行") >> o["gh"]
    mhub >> Edge(color=ALLOW) >> o["gh"]
    deny(crunner, cenv)
    deny(job, tpm)
