# rln_ui — RLN membership app (backend:module reference implementation)

## Goal
A Basecamp app that shows a node's RLN membership status for Logos Messaging and (staged) helps set
one up. Built as the **first `"backend": "module"` app** — the pattern the platform is moving every app
to (`logos.callModule` from QML is deprecated and "removed in the next breaking release", observed
2026-11-06). This app is both a useful RLN-dogfood tool and the **reference implementation** of the
new pattern, ahead of migrating the Feedback app.

## Why this app
- Fills ecosystem#260 gap 1: RLN membership has no user-facing flow (register_membership is CLI-only).
- Proves the `backend:module` contract end to end (C++ backend consuming two core modules via lp,
  Qt Remote Objects replica to QML, direct core access blocked).
- Produces the doc-packet artifact + screenshots #260 asks for.

## Architecture
One `ui_qml` module, `rln_ui`, with `"backend": "module"`:

```
QML view (qml/Main.qml)
   │  logos.module("rln_ui") → replica;  logos.watch(backend.slot(), ok, err)
   ▼
C++ backend (src/RlnBackend.*)   ← derives <gen>SimpleSource + LogosModuleContext, interface=universal
   │  modules().dynamic("delivery_module").invoke("rlnState"/"createNode"/"start"/"getConnectionStatus")
   │  modules().dynamic("liblogos_rln_module").invoke("get_membership_state"/"get_memberships"/"get_epoch_quota")
   ▼
delivery_module (~0.4.0) + liblogos_rln_module (~0.10.0)   ← pinned deps
```

- The backend owns all core interaction. QML only reads the replica's READONLY props and calls its slots.
- Interface contract is `src/rln_ui.rep`: READONLY props (node RLN state, membership state/count, quota,
  registry, identity, epoch, delivery status) + slots (`start`, `refresh`, and the action slots).
- Grounded in the probe-verified calls (2026-11-06): logos.test preset, rlnState→Ready,
  get_membership_state→"unknown", get_memberships→[], get_epoch_quota→value when connected.

## Build & package
- `flake.nix` uses the **logos-module-builder** (`mkLogosModule`): `repc` generates the replica glue,
  `logos_module()` compiles the backend, output is a hash-signed `.lgx` (manifestVersion 0.7.0).
- Pin deps in metadata (`delivery_module ~0.4.0`, `liblogos_rln_module ~0.10.0`) — raw lp is not
  type-checked against a newer contract.
- Verify headless (res-bundle-mine inspector bundle) at 1280; note the shell's ~699px min width.

## Epics
1. **Scaffold + build system** — repo, metadata (`backend:module`, `interface:universal`, deps),
   `.rep`, CMakeLists, flake with the module builder, a skeleton that builds to a `.lgx`.
2. **Backend: status reads** — C++ backend brings up a logos.test delivery node, polls rlnState + the
   three rln reads via lp, publishes them on the replica props. (The core of the reference.)
3. **QML on the replica** — rewrite Main.qml to `logos.module` + `logos.watch` + prop bindings; remove
   every `logos.callModule`; verify the deprecation warning is gone.
4. **Membership actions** — `unlockKeystore` / `provisionWallet` / `registerMembership` slots wired to
   the rln module, surfaced in the UI (honest about the funded-account blocker).
5. **Package + verify** — `.lgx`, sign (xAlisher), headless test + screenshots, (optional) catalog.
6. **Docs / reference writeup** — a short "how a backend:module app is built" doc for the core team,
   so the Feedback migration follows a proven template.

## Risks / unknowns
- Exact `modules().dynamic(...).invoke` arg/return shapes vs the probe's logosctl JSON — resolve by
  building Epic 2 and reading the generated `logos_sdk.h`.
- Whether delivery/rln publish `.lidl` for typed wrappers (fallback: the dynamic LpClient, used here).
- The backend runs the delivery node; one node per process — fine for a standalone app.

## Status
Living plan. Each epic is a tracking issue in this repo; check boxes as they land.
