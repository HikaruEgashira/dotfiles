# Architecture, threat model, mitigations: iac-aws ADR-0010.
# `default` = Identity Center ReadOnlyAccess permission set (長期 AKIA なし)。
# Privilege escalation: AWS_PROFILE=hikae-admin-sso (同一 SSO セッション内の切替)。
# セッション確立 (90日毎): `aws sso login` (パスワード + passkey)。
{ config, ... }:
{
  home.file.".aws/config".text = ''
    [sso-session hikae]
    sso_start_url = https://d-9567730231.awsapps.com/start
    sso_region = ap-northeast-1
    sso_registration_scopes = sso:account:access

    [default]
    region = ap-northeast-1
    sso_session = hikae
    sso_account_id = 951872725222
    sso_role_name = ReadOnlyAccess

    # terraform apply 等の特権操作 (iac-aws ADR-0010 L2)。
    [profile hikae-admin-sso]
    region = ap-northeast-1
    sso_session = hikae
    sso_account_id = 951872725222
    sso_role_name = AdministratorAccess

    [profile seccamp]
    region             = ap-northeast-1
    credential_process = ${config.home.homeDirectory}/.config/secrets/seccamp-credential-process

    # terraform 等 SDK ツールから iac-aws-apply を使うための profile。
    # SDK には SSO cache を読めないものがあるため、credential_process で
    # AWS CLI に解決を委譲する。
    [profile iac-aws-apply]
    region             = ap-northeast-1
    credential_process = ${config.home.homeDirectory}/.nix-profile/bin/aws configure export-credentials --profile iac-aws-apply-chain --format process

    # hikae-admin-sso → iac-aws-apply の role chain (CI と権限パリティ)。
    # chaining のためセッションは 1h だが、CLI が無プロンプトで再 assume する。
    [profile iac-aws-apply-chain]
    region            = ap-northeast-1
    role_arn          = arn:aws:iam::951872725222:role/iac-aws-apply
    role_session_name = local-apply
    source_profile    = hikae-admin-sso

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
    source_profile    = hikae-admin-sso
  '';
}
