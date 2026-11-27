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
from diagrams.generic.device import Mobile
from diagrams.generic.os import Ubuntu
from diagrams.onprem.client import Client
from diagrams.onprem.vcs import Github
from diagrams.generic.compute import Rack

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
    with Cluster("主体"):
        human = User("人間 (hikae)\nTouch ID・SSO・ghauth\n不可逆操作の承認")
        ai = Rack("対話 AI\nClaude Code / Codex\n人間の指示で動く")
        with Cluster("自律 AI (人間は decision だけ介入)"):
            ledger = Rack("ledger\nmac-studio で常駐\n指示なしで動く")
            hikaevi = Rack("hikaevi\nms-a2 で常駐\nIssue → PR → 本番検証")

    with Cluster("信頼: 高"):
        air = Mobile("macbook-air\nシンクライアント\nsudo 鍵 (Secure Enclave)")
        studio = Client("mac-studio\nGitHub token (8h)\nAWS SSO / env.age")

    with Cluster("信頼: 低 (侵害前提)"):
        msa2 = Ubuntu("ms-a2\n認証情報なし\nAI agent / CI runner\nsudo はパスワード")

    with Cluster("AWS"):
        broker = SingleSignOn("credential broker\n(mac-studio)")
        with Cluster("main 951872725222"):
            ro = IAMRole("ReadOnlyAccess\n(sso-readonly = 既定)")
            admin = IAMRole("AdministratorAccess\n(hikae-admin-sso)")
            apply = IAMRole("iac-aws-apply\nartex-microvm-run")
            fleet = Organizations("Fleet (計画)\n全 Mac に root")
        with Cluster("sisaku-security 034111987897"):
            sisaku = IAMRole("ReadOnlyAccess のみ")
        with Cluster("lab-seccamp26d2 931932531320"):
            lab = IAMRole("OrgAccessRole →\niac-aws-apply")

    gh = Github("GitHub\nmain → CI 緑 → deploy")

    human >> Edge(color=ALLOW, label="操作 (ssh)") >> air
    human >> Edge(color=ALLOW, label="依頼・承認") >> ai
    air >> Edge(color=ALLOW, label="ssh (agent 転送あり)") >> studio
    air >> Edge(color=ALLOW, label="ssh (agent 転送なし)") >> msa2

    ai >> Edge(color=ALLOW, label="commit / push / PR / merge\napply・deploy (範囲内)") >> studio
    ai >> Edge(color=ALLOW, label="実験・CI job (使い捨て secret)") >> msa2
    human >> Edge(color=ALLOW, style="dotted", label="decision のみ") >> ledger
    human >> Edge(color=ALLOW, style="dotted", label="decision のみ") >> hikaevi
    ledger >> Edge(color=ALLOW, label="AWS は broker 経由") >> studio
    hikaevi >> Edge(color=ALLOW, label="資格情報なし") >> msa2
    hikaevi >> Edge(color=ALLOW, label="PR (bot、CI 緑で merge)") >> gh

    studio >> Edge(color=ALLOW, label="push (ghtkn)") >> gh
    studio >> Edge(color=ALLOW, label="資格情報を取得") >> broker
    broker >> Edge(color=ALLOW, label="既定") >> ro
    broker >> Edge(color=ROOT, label="明示切替時のみ") >> admin
    admin >> Edge(color=ROOT, label="role chain") >> apply
    admin >> Edge(color=ROOT, label="2-hop chain") >> lab
    broker >> Edge(color=ALLOW) >> sisaku
    gh >> Edge(color=ALLOW, label="deploy を読む") >> fleet
    fleet >> Edge(color=ROOT, style="bold", label="root script / MDM") >> air
    fleet >> Edge(color=ROOT, style="bold", label="root script / MDM") >> studio

    for dst, why in [(studio, "高区分へ書込禁止\n(tailnet ACL)"), (broker, "AWS 資格情報なし"), (fleet, "制御面へ到達禁止")]:
        msa2 >> Edge(color=DENY, style="dashed", label=f"✕ {why}") >> dst
