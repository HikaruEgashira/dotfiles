# Architecture, threat model, mitigations: iac-aws ADR-0010 (supersedes ADR-0008).
# Identity Center 移行中の過渡構成: sso-session / hikae-admin-sso を追加済み、
# 旧経路 (default AKIA + hikae-admin-mfa) は SSO 疎通確認後に削除する。
# Privilege escalation: AWS_PROFILE=hikae-admin-sso (同一 SSO セッション内の切替)。
{ config, ... }:
{
  home.file.".aws/config".text = ''
    [sso-session hikae]
    sso_start_url = https://d-9567730231.awsapps.com/start
    sso_region = ap-northeast-1
    sso_registration_scopes = sso:account:access

    [default]
    region = ap-northeast-1

    # terraform apply 等の特権操作 (iac-aws ADR-0010 L2)。
    # `aws sso login --profile hikae-admin-sso` でセッション確立 (90日)。
    [profile hikae-admin-sso]
    region = ap-northeast-1
    sso_session = hikae
    sso_account_id = 951872725222
    sso_role_name = AdministratorAccess

    [profile seccamp]
    region             = ap-northeast-1
    credential_process = ${config.home.homeDirectory}/.config/secrets/seccamp-credential-process

    [profile hikae-admin-mfa]
    region           = ap-northeast-1
    role_arn         = arn:aws:iam::951872725222:role/hikae-stepup-admin
    source_profile   = default
    mfa_serial       = arn:aws:iam::951872725222:mfa/hikae-readonly
    duration_seconds = 43200

    # terraform 等 SDK ツールから iac-aws-apply を使うための profile。
    # SDK は ~/.aws/cli/cache を読まないため、credential_process で AWS CLI に
    # 解決を委譲し、cache 済み MFA セッション(12h)を再利用させる。
    # MFA プロンプトは cache が切れた時のみ。terraform 実行前に
    # `aws sts get-caller-identity --profile seccamp-apply` で warm しておく。
    [profile seccamp-apply]
    region             = ap-northeast-1
    credential_process = ${config.home.homeDirectory}/.nix-profile/bin/aws configure export-credentials --profile seccamp-apply-chain --format process

    # hikae-admin-mfa (stepup-admin, MFA+12h cache) → iac-aws-apply の role chain。
    # chaining のためセッションは 1h だが、CLI が無プロンプトで再 assume する。
    [profile seccamp-apply-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::951872725222:role/iac-aws-apply
    role_session_name = local-apply
    source_profile    = hikae-admin-mfa

    # lab-seccamp26d2 (931932531320, seccamp-2026-d2 の terraform 対象)。
    # iac-aws-apply@lab の trust は OrganizationAccountAccessRole のみのため 2-hop chain。
    [profile seccamp-lab-apply]
    region             = ap-northeast-1
    credential_process = ${config.home.homeDirectory}/.nix-profile/bin/aws configure export-credentials --profile seccamp-lab-apply-chain --format process

    [profile seccamp-lab-apply-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::931932531320:role/iac-aws-apply
    role_session_name = local-apply
    source_profile    = seccamp-lab-org

    [profile seccamp-lab-org]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::931932531320:role/OrganizationAccountAccessRole
    role_session_name = local-apply
    source_profile    = hikae-admin-mfa
  '';
}
