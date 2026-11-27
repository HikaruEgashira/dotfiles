# /// script
# requires-python = ">=3.11"
# dependencies = ["diagrams==0.24.4"]
# ///
"""端末ごとに、内部のプロセス・データと外部とのデータの流れを 1 枚ずつ描く。

uv run docs/security/device_diagram.py  →  docs/security/device-<端末>.png
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import Lambda
from diagrams.aws.general import Disk, SslPadlock, User
from diagrams.aws.migration import Datasync
from diagrams.aws.security import IAMRole, SecretsManager, SingleSignOn
from diagrams.gcp.network import DNS
from diagrams.generic.compute import Rack
from diagrams.generic.device import Mobile
from diagrams.generic.network import VPN
from diagrams.ibm.compute import Key
from diagrams.k8s.podconfig import Secret
from diagrams.oci.connectivity import DNS as Resolver
from diagrams.oci.monitoring import Telemetry
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.network import Envoy, Internet
from diagrams.onprem.security import Vault
from diagrams.onprem.vcs import Github

HERE = Path(__file__).parent

ALLOW = "darkgreen"
DENY = "gray"

graph = {"rankdir": "TB", "fontname": "Hiragino Sans", "fontsize": "20", "pad": "0.5", "nodesep": "0.6", "ranksep": "0.9", "splines": "ortho", "forcelabels": "true"}
node = {"fontname": "Hiragino Sans", "fontsize": "12"}
edge = {"fontname": "Hiragino Sans", "fontsize": "11"}


def flow(src, dst, label=""):
    src >> Edge(color=ALLOW, xlabel=label) >> dst


def deny(src, dst, label):
    src >> Edge(color=DENY, style="dashed", xlabel=f"✕ {label}") >> dst


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


def mac(name, studio):
    with diagram(name):
        operator = Mobile("macbook-air") if studio else User("人間")
        lan = Internet("LAN")
        cache = Internet("Nix cache\n上流 release")

        with Cluster(name):
            with Cluster("root"):
                sudo = SslPadlock("sudo")
                resolver = Resolver("名前解決")
                if not studio:
                    key = Vault("Secretive 鍵")

            with Cluster("ユーザー"):
                with Cluster("AI agent sandbox"):
                    agent = Rack("Claude Code / Codex")
                if studio:
                    ledger = Rack("ledger")
                sync = Datasync("dotfiles-sync")
                nixstore = Disk("Nix store")
                with Cluster("資格情報"):
                    ghtkn = Vault("ghtkn\n" + ("書き込み可" if studio else "読み取り専用"))
                    if studio:
                        broker = SingleSignOn("AWS broker")
                    secrets = SecretsManager("age secret\nssh 認証鍵")
                hub = Envoy("gypxy hub")
                otel = Telemetry("telemetry collector")

        dns = DNS("NextDNS")
        tel = Internet("telemetry 送信先")
        github = Github("GitHub")
        aws = IAMRole("AWS") if studio else None
        collector = Internet("gh-intel.com")

        flow(operator, sudo, "署名" if studio else "Touch ID")
        if not studio:
            flow(key, sudo, "署名")
        deny(lan, hub, "loopback のみ")
        deny(lan, otel, "loopback のみ")
        flow(cache, sync, "検証済み package")
        flow(sync, nixstore)

        flow(agent, ghtkn, "token")
        if studio:
            flow(agent, broker, "資格情報")
        flow(agent, otel)
        deny(agent, secrets, "読めない")
        if studio:
            flow(ledger, ghtkn)
            flow(ledger, broker)

        flow(resolver, dns, "暗号化 DNS")
        deny(dns, tel, "名前を返さない")
        flow(ghtkn, hub)
        flow(hub, github, "git")
        flow(ghtkn, github, "API")
        if studio:
            flow(broker, aws, "一時資格情報")
        flow(otel, collector, "telemetry")


mac("macbook-air", studio=False)
mac("mac-studio", studio=True)

with diagram("ms-a2"):
    lan = Internet("LAN")
    tailnet = Internet("tailnet")

    with Cluster("ms-a2"):
        with Cluster("root"):
            tsd = VPN("tailscaled")
            runner = GithubActions("CI runner")
            tpm = Key("TPM 鍵")
            cenv = Secret("runner token")
        with Cluster("job ごとの使い捨て環境"):
            job = Rack("CI job")
        with Cluster("claude-runner ユーザー"):
            crunner = Rack("claude runner")
        with Cluster("ユーザー"):
            hub = Envoy("gypxy hub")

    broker = Lambda("AWS local-broker")
    github = Github("GitHub")

    deny(lan, tsd, "sshd なし")
    flow(tailnet, tsd, "ACL で許可した SSH")
    deny(lan, hub, "loopback のみ")
    flow(tpm, runner, "署名")
    flow(runner, broker, "署名した要求")
    flow(broker, github, "runner 登録")
    flow(github, runner, "job の割り当て")
    flow(runner, job, "起動")
    deny(job, tpm, "読めない")
    flow(cenv, crunner, "起動時に渡す")
    flow(hub, github, "gh-intel の git")
    flow(crunner, github, "git / API")
    flow(job, github, "git / API")
