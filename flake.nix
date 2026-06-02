{
  description = "dms-patch-flake: patch DankMaterialShell Clock.qml middle dot to lambda for all systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dms.url = "github:AvengeMedia/DankMaterialShell/stable";
  };

  outputs = { self, nixpkgs, dms, ... }:
  let
    systems = builtins.attrNames (dms.packages or {});

    qmlPath = "share/quickshell/dms/Modules/DankBar/Widgets/Clock.qml";

    candidateNames = [ "dms-shell" "dms" "dmsShell" "default" ];

    pickAttrName = pkgset:
      let
        attrs = builtins.attrNames pkgset;
        tryName = name: if builtins.elem name attrs then name else null;
        found = builtins.foldl' (acc: n: if acc == null then tryName n else acc) null candidateNames;
        sep = ", ";
      in
        if found != null then found
        else if builtins.length attrs == 1 then builtins.head attrs
        else throw "dms-patch-flake: could not determine upstream package attribute. Available attrs: ${builtins.concatStringsSep sep attrs}";

    makePatched = upstreamDrv:
      upstreamDrv.overrideAttrs (old: {
        postPatch = ''
          if [ ! -f "${qmlPath}" ]; then
            echo "ERROR: expected QML path ${qmlPath} not found in source tree" >&2
            exit 1
          fi

          perl -C -0777 -pe 's/text:\s*".*?"/text: "\\x{03BB}"/s' -i ${qmlPath}
        '' + (if builtins.hasAttr "postPatch" old then old.postPatch else "");
      });

    patchedPackages = builtins.listToAttrs (map (system:
      let
        pkgset = builtins.getAttr system dms.packages;
        upstreamName = pickAttrName pkgset;
        upstreamPkg = builtins.getAttr upstreamName pkgset;
        patched = makePatched upstreamPkg;
      in {
        name = system;
        value = {
          dms-shell-patched = patched;
          "${upstreamName}" = patched;
        };
      }
    ) systems);

    patchedDms = dms // { packages = patchedPackages; };

    # Whitelist: only forward these outputs from the upstream flake
    whitelist = [ "packages" "homeModules" "overlays" "apps" "devShells" "nixosModules" "checks" ];

    upstreamOutputNames = builtins.attrNames dms;

    # Filter upstream outputs to the whitelist
    filteredOutputs = builtins.filter (name: builtins.elem name whitelist) upstreamOutputNames;

    forwardedOutputs = builtins.foldl' (acc: name:
      acc // (builtins.listToAttrs [{ name = name; value = builtins.getAttr name patchedDms; }])
    ) {} filteredOutputs;

  in
    forwardedOutputs;
}
