# /// script
# requires-python = ">=3.11"
# dependencies = ["diagrams==0.24.4"]
# ///
"""端末ごとの内部構成 (OS 層・ユーザー層・agent sandbox・資格情報・常駐) を図にする。

uv run docs/security/device_diagram.py  →  docs/security/device.png
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.security import SecretsManager, SingleSignOn
from diagrams.generic.compute import Rack
from diagrams.generic.network import Firewall
from diagrams.onprem.client import Client
from diagrams.onprem.security import Vault

OUT = Path(__file__).with_name("device")

ALLOW = "darkgreen"
DENY = "gray"

graph = {"rankdir": "TB", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.4", "ranksep": "1.0", "splines": "ortho", "forcelabels": "true"}
node = {"fontname": "Hiragino Sans", "fontsize": "12"}
edge = {"fontname": "Hiragino Sans", "fontsize": "11"}


def deny(src, dst):
    src >> Edge(color=DENY, style="dashed", xlabel="✕") >> dst


with Diagram(
    "端末の内部",
    filename=str(OUT),
    outformat="png",
    show=False,
    graph_attr=graph,
    node_attr=node,
    edge_attr=edge,
):
    with Cluster("macbook-air / mac-studio"):
        with Cluster("OS 層 nix-darwin"):
            fw = Firewall("受信遮断\nDNS 暗号化")
            sudo = Vault("sudo\nSecretive 鍵 → Touch ID")
            managed = Rack("AI CLI の強制設定\ntelemetry 停止")
            tsd = Rack("tailscaled\nSSH は tailnet ACL")
            apps = Rack("署名検証済み app")

        with Cluster("ユーザー層 home-manager"):
            pkgs = Rack("package\ncache と checksum のみ")
            with Cluster("常駐 loopback のみ"):
                sync = Rack("dotfiles-sync")
                hub = Rack("gypxy hub")
                otel = Rack("telemetry collector")
                artex = Rack("ARTEX / Postgres")
                ledger = Rack("ledger\nstudio のみ")

            with Cluster("資格情報"):
                gh = Vault("ghtkn\nstudio は書込・air は読取")
                aws = SingleSignOn("AWS broker")
                age = SecretsManager("age secret\nrepo ごとに渡す")
                auth = Vault("ssh 認証鍵")
                sign = Vault("署名鍵")

            with Cluster("AI agent sandbox"):
                agent = Rack("Claude Code / Codex")

    agent >> Edge(color=ALLOW, xlabel="仲介") >> gh
    agent >> Edge(color=ALLOW, xlabel="仲介") >> aws
    agent >> Edge(color=ALLOW) >> sign
    agent >> Edge(color=ALLOW) >> otel
    for dst in (age, auth, artex):
        deny(agent, dst)
    ledger >> Edge(color=ALLOW) >> aws
    sync >> Edge(color=ALLOW, xlabel="適用") >> pkgs
    hub >> Edge(color=ALLOW) >> gh

    with Cluster("ms-a2 NixOS"):
        with Cluster("OS 層"):
            disk = Vault("ディスク暗号化")
            net = Firewall("sshd なし\ntailnet ACL のみ")
        with Cluster("job ごとの使い捨て環境"):
            job = Rack("CI job\n専用 netns")
        runner = Rack("CI runner\ntoken なし")
        tpm = Vault("TPM 鍵")
        crunner = Rack("claude runner\n専用ユーザー")
        cenv = Vault("runner token\nroot のみ読める")
        mhub = Rack("gypxy hub")
        hikaevi = Rack("hikaevi")

    runner >> Edge(color=ALLOW, xlabel="起動") >> job
    runner >> Edge(color=ALLOW, xlabel="AWS 経由で認証") >> tpm
    deny(crunner, cenv)
    deny(job, tpm)
