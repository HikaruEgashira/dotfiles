{ config, ... }:

# AWS CLI shared config.
# Managed by home-manager so all profile definitions are reproducible.
# Credentials (~/.aws/credentials) stay unmanaged because they hold
# long-term secrets.
#
# Default profile holds the read-only daily driver. ~/.aws/credentials
# must contain a [default] section with the access keys for the
# `hikae-readonly` IAM user; until that placeholder is filled `aws` will
# fail with NoCredentialProviders, which is intentional — never silently
# fall back to admin credentials.
#
# Trade-off accepted vs. AssumeRole+MFA: zero re-auth friction for daily
# CLI work at the cost of credential durability. Mitigations:
#   * Read-only at the IAM level (defined in iac-aws/projects/shared/iam.tf).
#   * Explicit Deny on secretsmanager:GetSecretValue / ssm:GetParameter* /
#     kms:Decrypt so a leaked key cannot lift secrets.
#   * Manual 365-day rotation tracked via the rotation_interval_days tag
#     on the IAM user and Bitwarden item history.
#
# Write operations go through [profile hikae-admin-mfa]:
#   * Long-term keys for hikae-admin live under [hikae-admin] in
#     ~/.aws/credentials (NOT under [default] anymore — default is reserved
#     for hikae-readonly).
#   * `mfa_serial + source_profile` alone does NOT trigger sts:GetSessionToken
#     in the AWS CLI; that combination is consumed only when paired with
#     `role_arn` (assume-role flow). credential_process is the workaround
#     for a plain IAM-user MFA flow.
#   * Bitwarden's WebAuthn passkey on the same user cannot drive
#     sts:GetSessionToken from CLI; a separate virtual TOTP MFA must be
#     enrolled in the IAM console. Its ARN is the `mfa_serial` below.
#
# Usage:
#   $ aws s3 ls                                    # default = hikae-readonly
#   $ AWS_PROFILE=hikae-admin-mfa terraform apply  # write ops, prompts TOTP
let
  mfaScript = "${config.home.homeDirectory}/.local/bin/aws-mfa-creds";
  mfaSerial = "arn:aws:iam::951872725222:mfa/hikae-admin-mfa";
in
{
  home.file.".local/bin/aws-mfa-creds" = {
    source = ../settings/aws-mfa-creds.sh;
    executable = true;
  };

  home.file.".aws/config".text = ''
    [default]
    region = ap-northeast-1

    [profile hikae-admin-mfa]
    region             = ap-northeast-1
    credential_process = ${mfaScript} ${mfaSerial} hikae-admin 43200
  '';
}
