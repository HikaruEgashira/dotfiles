{ lib }:

let
  purposes = [
    "build"
    "edit"
    "ops"
    "comm"
    "observe"
    "play"
    "util"
  ];

  validPurpose = p: builtins.elem p purposes;

  mkEntry =
    {
      pkg,
      purpose,
      source ? "nixpkgs",
      reason,
      provenance ? null,
    }:
    assert lib.assertMsg (validPurpose purpose)
      "ledger.mkEntry: unknown purpose '${purpose}' (allowed: ${lib.concatStringsSep ", " purposes})";
    {
      inherit
        pkg
        purpose
        source
        reason
        provenance
        ;
      name = pkg.pname or pkg.name or "?";
    };

  pkgsOf = entries: map (e: e.pkg) entries;

  metaOf =
    entries:
    map (e: {
      inherit (e)
        name
        purpose
        source
        reason
        provenance
        ;
    }) entries;

  toJSON = entries: builtins.toJSON (metaOf entries);
in
{
  inherit
    mkEntry
    pkgsOf
    toJSON
    ;
}
