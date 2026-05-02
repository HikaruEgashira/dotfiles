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
      expires ? null,
      reason ? "",
    }:
    assert lib.assertMsg (validPurpose purpose)
      "ledger.mkEntry: unknown purpose '${purpose}' (allowed: ${lib.concatStringsSep ", " purposes})";
    {
      inherit
        pkg
        purpose
        source
        expires
        reason
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
        expires
        reason
        ;
    }) entries;

  toJSON = entries: builtins.toJSON (metaOf entries);
in
{
  inherit
    mkEntry
    pkgsOf
    metaOf
    toJSON
    purposes
    ;
}
