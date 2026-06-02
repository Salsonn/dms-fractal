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

    # Candidate attribute names to try inside the upstream package set
    candidateNames = [ "dms-shell" "dms" "dmsShell" "default" ];

    # Helper: pick an attribute name from a package set (pkgset)
    pickAttrName = pkgset:
      let
        attrs = builtins.attrNames pkgset;
        # find candidate names that actually exist in attrs
        matches = builtins.filter (n: builtins.elem n attrs) candidateNames;
      in
        if builtins.length matches > 0 then builtins.head matches
        else if builtins.length attrs == 1 then builtins.head attrs
        else throw "dms-patch-flake: could not determine upstream package attribute. Available attrs: ${builtins.concatStringsSep \", \" attrs}";

    # Function: produce a patched derivation from an upstream derivation
    # We avoid embedding the lambda glyph in Nix; instead use Perl's \x{03BB} escape.
    makePatched = upstreamDrv:
      upstreamDrv.overrideAttrs (old: {
        postPatch = ''
          # Ensure the expected file exists in the source tree; fail early if not.
          if [ ! -f "${qmlPath}" ]; then
            echo "ERROR: expected QML path ${qmlPath} not found in source tree" >&2
            exit 1
          fi

          # Replace the entire text: "..." property with a lambda using Perl's \x{03BB}.
          # The s///s modifier makes . match newlines; -0777 reads whole file.
          perl -C -0777 -pe 's/text:\s*".*?"/text: "\x{03BB}"/s' -i ${qmlPath}

          ${optionalString (old.postPatch != null) ''
            ${old.postPatch}
          ''}
        '';
      });
  in
  {
    packages = builtins.listToAttrs (map (system:
      let
        pkgset = builtins.getAttr system dms.packages;
        upstreamName = pickAttrName pkgset;
        upstreamPkg = builtins.getAttr upstreamName pkgset;
        patched = makePatched upstreamPkg;
      in {
        name = system;
        value = {
          dms-shell-patched = patched;
          upstream = {
            name = upstreamName;
            pkg = upstreamPkg;
          };
        };
      }
    ) systems);
  }
}
