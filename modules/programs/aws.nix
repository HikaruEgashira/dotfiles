# Architecture, threat model, mitigations: iac-aws ADR-0010 と docs/solutions/secrets/aws-credential-broker.md。
# sandbox から見える profile は credential_process で broker (unix socket) に委譲し、
# SSO token store (~/.aws/sso, ~/.aws/cli) は host 専用の source profile だけが読む。
# セッション確立 (90日毎): `aws sso login --sso-session hikae` を sandbox 外で実行する。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  sock = "${config.xdg.cacheHome}/aws-cred/agent.sock";
  broker = [
    "${pkgs.python3}/bin/python3"
    "${./aws/broker.py}"
    "--socket"
    sock
  ];
  client = "${home}/.local/bin/aws-cred-client";
  # broker が host 側で解決する profile。sandbox が直接名指ししても他は拒否する。
  # role chain も host で assume する。sandbox の CLI は ~/.aws/cli/cache へ書けず assume-role が失敗するため。
  sourceProfiles = [
    "sso-readonly"
    "sso-admin"
    "iac-aws-apply-chain"
    "artex-microvm-chain"
    "seccamp-lab-apply-chain"
  ];
in
{
  home.file.".local/bin/aws-cred-client" = {
    text = ''
      #!/bin/sh
      exec ${lib.escapeShellArgs broker} client "$@"
    '';
    executable = true;
  };

  launchd.agents.aws-cred-agent = {
    enable = true;
    config = {
      Label = "dev.egahika.aws-cred-agent";
      ProgramArguments =
        broker
        ++ [
          "agent"
          "--aws"
          "${pkgs.awscli2}/bin/aws"
        ]
        ++ lib.concatMap (p: [
          "--allow"
          p
        ]) sourceProfiles;
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/aws-cred-agent.log";
      StandardErrorPath = "${home}/Library/Logs/aws-cred-agent.log";
    };
  };

  home.file.".aws/config".text = ''
    [sso-session hikae]
    sso_start_url = https://d-9567730231.awsapps.com/start
    sso_region = ap-northeast-1
    sso_registration_scopes = sso:account:access

    # host 専用 source。sandbox では ~/.aws/sso が deny されるため直接使えない。
    [profile sso-readonly]
    region = ap-northeast-1
    sso_session = hikae
    sso_account_id = 951872725222
    sso_role_name = ReadOnlyAccess

    [profile sso-admin]
    region = ap-northeast-1
    sso_session = hikae
    sso_account_id = 951872725222
    sso_role_name = AdministratorAccess

    # `default` = Identity Center ReadOnlyAccess permission set (長期 AKIA なし)。
    [default]
    region = ap-northeast-1
    credential_process = ${client} sso-readonly

    # terraform apply 等の特権操作 (iac-aws ADR-0010 L2)。AWS_PROFILE=hikae-admin-sso で切替。
    [profile hikae-admin-sso]
    region = ap-northeast-1
    credential_process = ${client} sso-admin

    # sso-admin → iac-aws-apply の role chain (CI と権限パリティ)。
    # chaining のためセッションは 1h だが、host の CLI が無プロンプトで再 assume する。
    [profile iac-aws-apply]
    region             = ap-northeast-1
    credential_process = ${client} iac-aws-apply-chain

    [profile iac-aws-apply-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::951872725222:role/iac-aws-apply
    role_session_name = local-apply
    source_profile    = sso-admin

    # ARTEX の MicroVM オーケストレーション (ローカル launchd)。
    # 長期キーを持たず、sso-admin から artex-microvm-run を引受ける。
    [profile artex-microvm]
    region             = ap-northeast-1
    credential_process = ${client} artex-microvm-chain

    [profile artex-microvm-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::951872725222:role/artex-microvm-run
    role_session_name = artex-local
    source_profile    = sso-admin

    # lab-seccamp26d2 (931932531320, seccamp-2026-d2 の terraform 対象)。
    # iac-aws-apply@lab の trust は OrganizationAccountAccessRole のみのため 2-hop chain。
    [profile seccamp-lab-apply]
    region             = ap-northeast-1
    credential_process = ${client} seccamp-lab-apply-chain

    [profile seccamp-lab-apply-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::931932531320:role/iac-aws-apply
    role_session_name = local-apply
    source_profile    = seccamp-lab-org

    [profile seccamp-lab-org]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::931932531320:role/OrganizationAccountAccessRole
    role_session_name = local-apply
    source_profile    = sso-admin
  '';
}
