_:

# AWS CLI shared config.
# Managed by home-manager so all profile definitions are reproducible.
# Credentials (~/.aws/credentials) stay unmanaged because they hold
# long-term secrets.
#
# Architecture (see iac-aws ADR-0008):
#   * The only long-lived AKIA in the account belongs to `hikae-readonly`
#     and lives under [default] in ~/.aws/credentials. Daily-driver,
#     365-day manual rotation tracked via the rotation_interval_days tag
#     on the IAM user and Bitwarden item history.
#   * Privilege escalation goes through `sts:AssumeRole` into the
#     `hikae-stepup-admin` IAM role. The role's trust policy enforces
#     `aws:MultiFactorAuthPresent = true` and a 12h MFA age cap, so an
#     AKIA leak alone cannot reach admin.
#   * AWS CLI's standard `role_arn + source_profile + mfa_serial` flow
#     drives this — the previous `credential_process` workaround
#     (aws-mfa-creds.sh) is no longer needed because `mfa_serial` works
#     natively when paired with `role_arn`.
#   * MFA device is registered on the readonly IAM user (TOTP, virtual
#     MFA name `hikae-readonly`). Bitwarden Authenticator holds the seed.
#
# Mitigations on the readonly key (in case of leak):
#   * Read-only at the IAM level (defined in iac-aws/projects/shared/iam.tf).
#   * Explicit Deny on secretsmanager:GetSecretValue / ssm:GetParameter* /
#     kms:Decrypt so a leaked key cannot lift secrets.
#   * Cannot reach admin without MFA (trust policy condition).
#
# Usage:
#   $ aws s3 ls                                    # default = hikae-readonly
#   $ AWS_PROFILE=hikae-admin-mfa terraform apply  # write ops, prompts TOTP
#                                                  # then caches 12h in
#                                                  # ~/.aws/cli/cache/
{
  home.file.".aws/config".text = ''
    [default]
    region = ap-northeast-1

    [profile hikae-admin-mfa]
    region           = ap-northeast-1
    role_arn         = arn:aws:iam::951872725222:role/hikae-stepup-admin
    source_profile   = default
    mfa_serial       = arn:aws:iam::951872725222:mfa/hikae-readonly
    duration_seconds = 43200
  '';
}
