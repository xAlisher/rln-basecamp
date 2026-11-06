# rln_ui — RLN Membership (backend:module reference)

A Basecamp app that shows a node's RLN membership status for Logos Messaging and (staged) helps set
one up. Built as the **first `"backend": "module"` app** — the pattern the platform is moving every app
to, now that `logos.callModule` from QML is deprecated ("removed in the next breaking release").

It is both a useful RLN-dogfood tool (fills logos-co/ecosystem#260 gap 1: RLN membership has no
user-facing flow) and the **reference implementation** of the backend-module pattern, ahead of
migrating the Feedback app.

## How it's built (the pattern)

One `ui_qml` module with `"backend": "module"`:

- **QML view** (`qml/Main.qml`) has **no direct core access**. It reads its backend replica via
  `logos.module("rln_ui")` and calls slots with `logos.watch(backend.slot(), onOk, onErr)`.
- **C++ backend** (`src/RlnBackend.*`, `interface: "universal"`) derives the generated replica source
  + `LogosModuleContext`, and does all core interaction: it calls `delivery_module` and
  `liblogos_rln_module` through the `modules()` aggregate (the untyped `modules().dynamic(...).invoke`
  surface here) and publishes RLN status onto the replica's READONLY props.
- **`src/rln_ui.rep`** is the Qt Remote Objects interface between the two.
- **Dependencies** are pinned in `metadata.json` (`delivery_module ~0.4.0`, `liblogos_rln_module
  ~0.12.0`), since raw lp is not type-checked against a newer contract.

See [PLAN.md](PLAN.md) for the architecture, epics and risks.

## Build

```
nix build            # -> result/... the module (then nix bundle --bundler nix-bundle-lgx#portable .#ui for a .lgx)
```

Uses the logos-module-builder (`mkLogosModule`): `repc` generates the replica glue, `logos_module()`
compiles the backend.

## Status

Scaffold + plan in place; the build and the backend's live reads are tracked as epics in this repo.
Grounded in probe-verified RLN calls on the logos.test fleet (2026-11-06). The membership-setup actions
are staged: registration needs a funded account on the LEZ registry, which is still being wired.
