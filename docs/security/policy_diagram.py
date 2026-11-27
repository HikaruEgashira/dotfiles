# /// script
# requires-python = ">=3.11"
# dependencies = ["diagrams==0.24.4"]
# ///
"""主体 (人間・AI)・端末・AWS アカウントごとの権限を図にする。

uv run docs/security/policy_diagram.py  →  docs/security/policy.png
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import User
from diagrams.aws.management import Organizations
from diagrams.aws.security import IAMRole, SingleSignOn
from diagrams.generic.compute import Rack
from diagrams.generic.device import Mobile
from diagrams.generic.os import Ubuntu
from diagrams.onprem.client import Client
from diagrams.onprem.vcs import Github

OUT = Path(__file__).with_name("policy")

ALLOW = "darkgreen"
ROOT = "firebrick"
DENY = "gray"

graph = {"rankdir": "LR", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.7", "ranksep": "1.4", "splines": "ortho", "forcelabels": "true"}
node = {"fontname": "Hiragino Sans", "fontsize": "12"}
edge = {"fontname": "Hiragino Sans", "fontsize": "11"}

with Diagram(
    "権限ポリシー: 人間 / AI / 端末 / AWS",
    filename=str(OUT),
    outformat="png",
    show=False,
    graph_attr=graph,
    node_attr=node,
    edge_attr=edge,
):
    with Cluster("信頼: 高"):
        with Cluster("macbook-air"):
            human = User("人間")
            air = Mobile("操作端末\nsudo 鍵")
        with Cluster("mac-studio"):
            studio = Client("開発機\n認証情報あり")
            ai = Rack("Claude Code / Codex")
            ledger = Rack("ledger")
            broker = SingleSignOn("AWS 認証")

    with Cluster("信頼: 低 (侵害前提)"):
        with Cluster("ms-a2"):
            msa2 = Ubuntu("開発機\n認証情報なし")
            hikaevi = Rack("hikaevi")

    with Cluster("AWS"):
        with Cluster("main 951872725222"):
            ro = IAMRole("ReadOnly")
            admin = IAMRole("Admin")
            apply = IAMRole("apply")
            fleet = Organizations("Fleet (計画)")
        with Cluster("sisaku-security 034111987897"):
            sisaku = IAMRole("ReadOnly")
        with Cluster("lab-seccamp26d2 931932531320"):
            lab = IAMRole("apply")

    gh = Github("GitHub")

    human >> Edge(color=ALLOW, xlabel="操作") >> air
    air >> Edge(color=ALLOW, xlabel="操作") >> studio
    air >> Edge(color=ALLOW, xlabel="操作") >> msa2
    air >> Edge(color=ALLOW, style="dotted", xlabel="依頼") >> ai
    air >> Edge(color=ALLOW, style="dotted", xlabel="判断") >> ledger
    air >> Edge(color=ALLOW, style="dotted", xlabel="判断") >> hikaevi

    ai >> Edge(color=ALLOW, xlabel="CI") >> gh
    ledger >> Edge(color=ALLOW, xlabel="CI") >> gh
    hikaevi >> Edge(color=ALLOW, xlabel="CI") >> gh
    ai >> Edge(color=ALLOW) >> broker
    ledger >> Edge(color=ALLOW) >> broker
    broker >> Edge(color=ALLOW) >> ro
    broker >> Edge(color=ROOT) >> admin
    admin >> Edge(color=ROOT) >> apply
    admin >> Edge(color=ROOT) >> lab
    broker >> Edge(color=ALLOW) >> sisaku
    gh >> Edge(color=ALLOW, xlabel="CD") >> fleet
    fleet >> Edge(color=ROOT, style="bold", xlabel="CD") >> air
    fleet >> Edge(color=ROOT, style="bold", xlabel="CD") >> studio

    for dst, why in [(studio, "書込禁止"), (broker, "到達禁止"), (fleet, "到達禁止")]:
        msa2 >> Edge(color=DENY, style="dashed", xlabel=f"✕ {why}") >> dst
