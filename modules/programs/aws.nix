# Architecture, threat model, mitigations: iac-aws ADR-0008.
# `default` = hikae-readonly (long-lived AKIA, 365d rotation).
# Privilege escalation: AWS_PROFILE=hikae-admin-mfa (assumes role, requires TOTP).
_: {
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
