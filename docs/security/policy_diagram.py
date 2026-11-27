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

graph = {"rankdir": "LR", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.7", "ranksep": "1.4"}
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
            human = User("人間 (hikae)\n不可逆操作と decision を承認")
            air = Mobile("シンクライアント\nsudo 鍵 (Secure Enclave)")
        with Cluster("mac-studio"):
            studio = Client("開発機\nGitHub token (8h)\nAWS SSO / env.age")
            ai = Rack("Claude Code / Codex\n人間の依頼で動く")
            ledger = Rack("ledger\n常駐エージェント")
            broker = SingleSignOn("AWS credential broker")

    with Cluster("信頼: 低 (侵害前提)"):
        with Cluster("ms-a2"):
            msa2 = Ubuntu("開発機\n認証情報なし\nCI runner\nsudo はパスワード")
            hikaevi = Rack("hikaevi\n常駐エージェント\nIssue → PR → 本番検証")

    with Cluster("AWS"):
        with Cluster("main 951872725222"):
            ro = IAMRole("ReadOnlyAccess\n(既定)")
            admin = IAMRole("AdministratorAccess")
            apply = IAMRole("iac-aws-apply\nartex-microvm-run")
            fleet = Organizations("Fleet (計画)\n全 Mac に root")
        with Cluster("sisaku-security 034111987897"):
            sisaku = IAMRole("ReadOnlyAccess のみ")
        with Cluster("lab-seccamp26d2 931932531320"):
            lab = IAMRole("iac-aws-apply")

    gh = Github("GitHub\nmain → CI 緑 → deploy")

    human >> Edge(color=ALLOW, label="操作") >> air
    air >> Edge(color=ALLOW, label="ssh (sudo 鍵を転送)") >> studio
    air >> Edge(color=ALLOW, label="ssh (鍵を転送しない)") >> msa2
    air >> Edge(color=ALLOW, style="dotted", label="依頼・decision") >> ai
    air >> Edge(color=ALLOW, style="dotted", label="decision のみ") >> ledger
    air >> Edge(color=ALLOW, style="dotted", label="decision のみ") >> hikaevi

    ai >> Edge(color=ALLOW, label="commit / push / PR / merge") >> gh
    ledger >> Edge(color=ALLOW, label="PR") >> gh
    hikaevi >> Edge(color=ALLOW, label="PR (bot)") >> gh
    studio >> Edge(color=ALLOW, label="push") >> gh
    ai >> Edge(color=ALLOW) >> broker
    ledger >> Edge(color=ALLOW) >> broker
    broker >> Edge(color=ALLOW, label="既定") >> ro
    broker >> Edge(color=ROOT, label="明示切替時のみ") >> admin
    admin >> Edge(color=ROOT) >> apply
    admin >> Edge(color=ROOT) >> lab
    broker >> Edge(color=ALLOW) >> sisaku
    gh >> Edge(color=ALLOW, label="deploy を読む") >> fleet
    fleet >> Edge(color=ROOT, style="bold", label="root / MDM") >> air
    fleet >> Edge(color=ROOT, style="bold", label="root / MDM") >> studio

    for dst, why in [(studio, "高区分へ書込禁止"), (broker, "AWS 資格情報なし"), (fleet, "制御面へ到達禁止")]:
        msa2 >> Edge(color=DENY, style="dashed", label=f"✕ {why}") >> dst
