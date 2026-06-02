# dms-fractal

A small flake that patches DankMaterialShell's Clock.qml to use a lambda (λ) as the middle separator.

## How it works

- The flake inspects the upstream DMS flake's `packages` attribute and produces a patched `dms-fractal` package for every system the upstream exposes.
- The patch replaces the `text: "•"` line in:
  `share/quickshell/dms/Modules/DankBar/Widgets/Clock.qml`
  with `text: "λ"`.

## Usage

1. Add this flake as an input in your flake:
```nix
inputs = {
  dms-fractal = {
    url = "github:salsonn/dms-fractal";
  };
  # keep your existing inputs...
};
