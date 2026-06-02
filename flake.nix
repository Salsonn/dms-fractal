{
  description = "Flake that patches DankMaterialShell Clock.qml middle dot to a lambda for all systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dms.url = "github:AvengeMedia/DankMaterialShell/stable";
  };

  outputs = { self, nixpkgs, dms, ... }:
  let
    # Helper: list of systems exported by the upstream dms flake
    systems = builtins.attrNames (dms.packages or {});

    # Common attribute names to try when locating the upstream package inside the dms flake
    candidateNames = [ "dms-shell" "dms" "dmsShell" "default" ];

    # Function: given a system string, return the upstream package attribute and the package itself
    findUpstreamPackage = system:
      let
        pkgset = builtins.getAttr system dms.packages;
        findName = name:
          if builtins.hasAttr name pkgset then
            { name = name; pkg = builtins.getAttr name pkgset; }
          else null;
        found = builtins.foldl' (acc n -> if acc == null then findName n else acc) null candidateNames;
      in
        if found == null then
          # fallback: if pkgset has exactly one attr, use it
          let attrs = builtins.attrNames pkgset; in
          if builtins.length attrs == 1 then
            { name = builtins.head attrs; pkg = builtins.getAttr (builtins.head attrs) pkgset; }
          else
            # nothing found
            throw "dms-patch-flake: could not find upstream dms package attribute for system ${system}. Available attrs: ${builtins.concatStringsSep ', ' (builtins.attrNames pkgset)}";
        else found;

    # The substitution we will apply. Adjust path or strings here if upstream changes layout.
    qmlPath = "share/quickshell/dms/Modules/DankBar/Widgets/Clock.qml";
    replaceMatch = 'text: "•"';
    # replaceWithEscape = 'text: "\\u03BB"'; # writes \u03BB into the file
    replaceWithGlyph = 'text: "λ"';        # writes literal λ into the file

    # Function to produce a patched package for a given upstream package
    makePatched = upstreamPkg: upstreamPkg.overrideAttrs (old: {
      postPatch = ''
        # Ensure the file exists before attempting substitution to fail early if path changed.
        if [ -f "${qmlPath}" ]; then
          substituteInPlace ${qmlPath} --replace '${replaceMatch}' '${replaceWithGlyph}'
        else
          echo "Warning: ${qmlPath} not found in source tree; skipping substitution" >&2
        fi

        ${optionalString (old.postPatch != null) ''
          ${old.postPatch}
        ''}
      '';
    });
  in
  {
    # For each system upstream exposes, create a patched package set entry
    packages = builtins.listToAttrs (map (system:
      let upstream = findUpstreamPackage system;
          patched = makePatched upstream.pkg;
      in {
        name = system;
        value = {
          inherit (builtins.listToAttrs [{ name = "dms-fractal"; value = patched }]) dms-fractal;
          # also expose the upstream package for convenience
          upstreamName = upstream.name;
          upstream = upstream.pkg;
        };
      }
    ) systems);

    # Also expose a flat packages.<system>.dms-fractal attribute for easy referencing
    # (so other flakes can use inputs.dms-patch.packages.x86_64-linux.dms-fractal)
    # Build the attribute set dynamically:
    outputs = lib: let
      pkgsBySystem = builtins.listToAttrs (map (system:
        { name = system;
          value = (let upstream = findUpstreamPackage system; in makePatched upstream.pkg);
        }
      ) systems);
    in {
      packages = pkgsBySystem;
    };
  }
}
