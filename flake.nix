{
  description = "dms-patch-flake: patch DankMaterialShell Clock.qml middle dot to lambda for all systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dms.url = "github:AvengeMedia/DankMaterialShell/stable";
  };

  outputs = { self, nixpkgs, dms, ... }:
  let
    # Systems exported by the upstream dms flake
    systems = builtins.attrNames (dms.packages or {});

    # QML path inside the dms-shell derivation source tree (adjust if upstream moves it)
    qmlPath = "share/quickshell/dms/Modules/DankBar/Widgets/Clock.qml";

    # Match and replacement strings
    matchLine = 'text: "•"';
    # Use literal glyph:
    replacementLine = 'text: "λ"';
    # Or use escaped unicode sequence instead:
    # replacementLine = 'text: "\\u03BB"';

    # Candidate attribute names to try inside the upstream package set
    candidateNames = [ "dms-shell" "dms" "dmsShell" "default" ];

    # Helper: pick an attribute name from a package set (pkgset)
    pickAttrName = pkgset:
      let
        attrs = builtins.attrNames pkgset;
        tryName = name: if builtins.elem name attrs then name else null;
        found = builtins.foldl' (acc n -> if acc == null then tryName n else acc) null candidateNames;
      in
        if found != null then found
        else if builtins.length attrs == 1 then builtins.head attrs
        else throw "dms-patch-flake: could not determine upstream package attribute. Available attrs: ${builtins.concatStringsSep \", \" attrs}";

    # Function: produce a patched derivation from an upstream derivation
    makePatched = upstreamDrv:
      upstreamDrv.overrideAttrs (old: {
        postPatch = ''
          # Fail early if the expected file is not present in the source tree.
          if [ ! -f "${qmlPath}" ]; then
            echo "ERROR: expected QML path ${qmlPath} not found in source tree" >&2
            exit 1
          fi

          substituteInPlace ${qmlPath} --replace '${matchLine}' '${replacementLine}'

          ${optionalString (old.postPatch != null) ''
            ${old.postPatch}
          ''}
        '';
      });
  in
  {
    # Expose a packages set with patched derivations per system
    packages = builtins.listToAttrs (map (system:
      let
        pkgset = builtins.getAttr system dms.packages;
        upstreamName = pickAttrName pkgset;
        upstreamPkg = builtins.getAttr upstreamName pkgset;
        patched = makePatched upstreamPkg;
      in {
        name = system;
        value = {
          # Primary exported attribute for convenience
          dms-shell-patched = patched;
          # Also expose upstream info for debugging
          upstream = {
            name = upstreamName;
            pkg = upstreamPkg;
          };
        };
      }
    ) systems);
  }
}
