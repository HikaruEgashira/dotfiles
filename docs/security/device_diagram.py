# /// script
# requires-python = ">=3.11"
# dependencies = ["diagrams==0.24.4"]
# ///
"""端末ごとの内部構成 (OS 層・ユーザー層・agent sandbox・資格情報・常駐・更新元) を図にする。

uv run docs/security/device_diagram.py  →  docs/security/device.png
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.management import Organizations
from diagrams.aws.security import SecretsManager, SingleSignOn
from diagrams.generic.compute import Rack
from diagrams.generic.os import IOS, LinuxGeneral
from diagrams.onprem.client import User
from diagrams.onprem.security import Vault
from diagrams.onprem.vcs import Github

OUT = Path(__file__).with_name("device")

ALLOW = "darkgreen"
ROOT = "firebrick"
DENY = "gray"

graph = {"rankdir": "LR", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.5", "ranksep": "1.2", "splines": "ortho", "forcelabels": "true"}
node = {"fontname": "Hiragino Sans", "fontsize": "12"}
edge = {"fontname": "Hiragino Sans", "fontsize": "11"}

with Diagram(
    "端末の内部: 層 / sandbox / 資格情報 / 更新元",
    filename=str(OUT),
    outformat="png",
    show=False,
    graph_attr=graph,
    node_attr=node,
    edge_attr=edge,
):
    gh = Github("dotfiles\nmain / deploy")
    fleet = Organizations("Fleet (計画)")

    with Cluster("macbook-air (信頼: 高)"):
        air_os = IOS("nix-darwin")
        air_home = User("home-manager")
        air_key = Vault("sudo 鍵\n(Secretive)")
        air_tok = Vault("ghtkn token\n(読み取り専用)")
        air_sync = Rack("dotfiles-sync")
        air_hub = Rack("gypxy hub")

    with Cluster("mac-studio (信頼: 高)"):
        studio_os = IOS("nix-darwin")
        studio_home = User("home-manager")
        with Cluster("AI agent sandbox"):
            agent = Rack("Claude Code / Codex")
        with Cluster("sandbox の外の資格情報"):
            tok = Vault("ghtkn token")
            broker = SingleSignOn("AWS 認証 broker")
            age = SecretsManager("age secret")
        ledger = Rack("ledger")
        studio_sync = Rack("dotfiles-sync")
        studio_hub = Rack("gypxy hub")

    with Cluster("ms-a2 (信頼: 低、侵害前提)"):
        msa2_os = LinuxGeneral("NixOS\n+ home-manager")
        hikaevi = Rack("hikaevi")
        runner = Rack("CI runner\n(job ごと使い捨て)")
        msa2_hub = Rack("gypxy hub")

    gh >> Edge(color=ROOT, xlabel="deploy") >> fleet
    fleet >> Edge(color=ROOT, style="bold", xlabel="root") >> air_os
    fleet >> Edge(color=ROOT, style="bold", xlabel="root") >> studio_os
    gh >> Edge(color=ALLOW, xlabel="main pull") >> air_sync
    gh >> Edge(color=ALLOW, xlabel="main pull") >> studio_sync
    air_sync >> Edge(color=ALLOW) >> air_home
    studio_sync >> Edge(color=ALLOW) >> studio_home
    air_os >> Edge(color=ALLOW) >> air_home
    studio_os >> Edge(color=ALLOW) >> studio_home

    agent >> Edge(color=ALLOW, xlabel="仲介") >> tok
    agent >> Edge(color=ALLOW, xlabel="仲介") >> broker
    agent >> Edge(color=DENY, style="dashed", xlabel="✕ 読めない") >> age
    ledger >> Edge(color=ALLOW) >> broker
