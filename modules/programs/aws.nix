{ config, ... }:

# AWS CLI shared config.
# Managed by home-manager so the MFA-required profile for hikae-admin is
# reproducible. Credentials (~/.aws/credentials) stay unmanaged because they
# hold long-term secrets.
#
# How the MFA flow works:
#   * `mfa_serial + source_profile` alone does NOT trigger sts:GetSessionToken
#     in the AWS CLI; that combination is consumed only when paired with
#     `role_arn` (assume-role flow). To get GetSessionToken from a plain
#     IAM-user profile we use `credential_process`, which calls a small
#     helper that prompts for the TOTP, caches the resulting session token,
#     and emits it in the format AWS CLI / SDKs expect.
#   * Bitwarden's WebAuthn passkey on the same user cannot drive
#     sts:GetSessionToken from CLI; a separate virtual TOTP MFA must be
#     enrolled in the IAM console. Its ARN is the `mfa_serial` below.
#
# Usage:
#   $ terraform apply           # AWS_PROFILE is already hikae-admin-mfa,
#                               # CLI prompts for the 6-digit TOTP only
#                               # when the cached session expires.
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

    [profile bootstrap]
    region = ap-northeast-1

    [profile hikae-admin-mfa]
    region             = ap-northeast-1
    credential_process = ${mfaScript} ${mfaSerial} default 43200
  '';

  home.sessionVariables.AWS_PROFILE = "hikae-admin-mfa";
}
