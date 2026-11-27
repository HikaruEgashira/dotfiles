# Architecture, threat model, mitigations: iac-aws ADR-0010 と docs/solutions/secrets/aws-credential-broker.md。
# sandbox から見える profile は credential_process で read 系 broker (unix socket) に委譲し、
# 特権 profile は sandbox が接続できない別 socket の broker だけが返す。
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
  inherit (config.dotfiles.aws) readSocket adminSocket;
  brokerFor = sock: [
    "${pkgs.python3}/bin/python3"
    "${./aws/broker.py}"
    "--socket"
    sock
  ];
  client = "${home}/.local/bin/aws-cred-client";
  adminClient = "${home}/.local/bin/aws-cred-admin-client";
  # role chain も host で assume する。sandbox の CLI は ~/.aws/cli/cache へ書けず assume-role が失敗するため。
  # sandbox の allowUnixSockets に載るのは readSocket だけなので、admin 系は sandbox から名指ししても届かない
  agents = {
    aws-cred-agent = {
      label = "dev.egahika.aws-cred-agent";
      socket = readSocket;
      profiles = [
        "sso-readonly"
        "sisaku-security-readonly-sso"
      ];
    };
    aws-cred-admin-agent = {
      label = "dev.egahika.aws-cred-admin-agent";
      socket = adminSocket;
      profiles = [
        "sso-admin"
        "iac-aws-apply-chain"
        "artex-microvm-chain"
        "seccamp-lab-apply-chain"
      ];
    };
  };
in
{
  options.dotfiles.aws.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "AWS の SSO 設定と credential broker を置く。シンクライアントは false にし、AWS には mac-studio 経由でだけ届く";
  };
  options.dotfiles.aws.readSocket = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "${config.xdg.cacheHome}/aws-cred/agent.sock";
    description = "read 系 profile だけを返す broker。ai-sandbox が許可する";
  };
  options.dotfiles.aws.adminSocket = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "${config.xdg.cacheHome}/aws-cred-admin/agent.sock";
    description = "特権 profile を返す broker。sandbox からは接続も書き込みもさせない";
  };

  config = lib.mkMerge [
    (lib.mkIf (!config.dotfiles.aws.enable) {
      # 以前の generation が残した SSO token を消し、再ログインしない限り AWS に届かないようにする
      home.activation.purgeAwsSession = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run rm -rf "${home}/.aws/sso/cache" "${home}/.aws/cli/cache"
      '';
    })
    (lib.mkIf config.dotfiles.aws.enable {
      home.file = {
        ".local/bin/aws-cred-client" = {
          text = ''
            #!/bin/sh
            exec ${lib.escapeShellArgs (brokerFor readSocket)} client "$@"
          '';
          executable = true;
        };
        ".local/bin/aws-cred-admin-client" = {
          text = ''
            #!/bin/sh
            exec ${lib.escapeShellArgs (brokerFor adminSocket)} client "$@"
          '';
          executable = true;
        };
      };

      launchd.agents = lib.mapAttrs (_: a: {
        enable = true;
        config = {
          Label = a.label;
          ProgramArguments =
            brokerFor a.socket
            ++ [
              "agent"
              "--aws"
              "${pkgs.awscli2}/bin/aws"
            ]
            ++ lib.concatMap (p: [
              "--allow"
              p
            ]) a.profiles;
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${home}/Library/Logs/${lib.removePrefix "dev.egahika." a.label}.log";
          StandardErrorPath = "${home}/Library/Logs/${lib.removePrefix "dev.egahika." a.label}.log";
        };
      }) agents;

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

        # sisaku-security (gh-intel 本番) の Identity Center ReadOnlyAccess。secret・SSM・kms:Decrypt は permission set が拒否する。
        [profile sisaku-security-readonly-sso]
        region = ap-northeast-1
        sso_session = hikae
        sso_account_id = 034111987897
        sso_role_name = ReadOnlyAccess

        [profile sisaku-security-readonly]
        region = ap-northeast-1
        credential_process = ${client} sisaku-security-readonly-sso

        # `default` = Identity Center ReadOnlyAccess permission set (長期 AKIA なし)。
        [default]
        region = ap-northeast-1
        credential_process = ${client} sso-readonly

        # terraform apply 等の特権操作 (iac-aws ADR-0010 L2)。AWS_PROFILE=hikae-admin-sso で切替。
        [profile hikae-admin-sso]
        region = ap-northeast-1
        credential_process = ${adminClient} sso-admin

        # sso-admin → iac-aws-apply の role chain (CI と権限パリティ)。
        # chaining のためセッションは 1h だが、host の CLI が無プロンプトで再 assume する。
        [profile iac-aws-apply]
        region             = ap-northeast-1
        credential_process = ${adminClient} iac-aws-apply-chain

        [profile iac-aws-apply-chain]
        region            = ap-northeast-1
        role_arn          = arn:aws:iam::951872725222:role/iac-aws-apply
        role_session_name = local-apply
        source_profile    = sso-admin

        # ARTEX の MicroVM オーケストレーション (ローカル launchd)。
        # 長期キーを持たず、sso-admin から artex-microvm-run を引受ける。
        [profile artex-microvm]
        region             = ap-northeast-1
        credential_process = ${adminClient} artex-microvm-chain

        [profile artex-microvm-chain]
        region            = ap-northeast-1
        role_arn          = arn:aws:iam::951872725222:role/artex-microvm-run
        role_session_name = artex-local
        source_profile    = sso-admin

        # lab-seccamp26d2 (931932531320, seccamp-2026-d2 の terraform 対象)。
        # iac-aws-apply@lab の trust は OrganizationAccountAccessRole のみのため 2-hop chain。
        [profile seccamp-lab-apply]
        region             = ap-northeast-1
        credential_process = ${adminClient} seccamp-lab-apply-chain

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
    })
  ];
}
