{
  description = "rln_ui — RLN membership app for Basecamp (first backend:module reference implementation)";

  inputs = {
    # Pinned to the rev bc-shell-clone builds its backend:module fixtures with.
    logos-module-builder.url = "github:logos-co/logos-module-builder/de169fd45d7bdf6e28ce1f151b4c34880523ace9";
    flake-utils.follows = "logos-module-builder/flake-utils";

    # Dependency module flakes, keyed by MODULE name so the builder can read their .lidl and
    # generate the modules().<dep> wrappers. delivery public source tops out at v0.3.3 (live is
    # 0.4.0, unreleased); rln's logos-rln-module subdir flake is 0.12.0 (matches live). The
    # backend uses the version-tolerant modules().dynamic(...).invoke surface, so the .lidl
    # version only needs to carry the methods we call (createNode/start/rlnState; rln reads).
    delivery_module.url = "github:logos-co/logos-delivery-module/v0.3.3";
    liblogos_rln_module.url = "github:logos-co/logos-rln-modules?dir=logos-rln-module";
  };

  outputs = { self, logos-module-builder, flake-utils, delivery_module, liblogos_rln_module, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      (logos-module-builder.lib.mkLogosModule {
        src = ./.;
        configFile = ./metadata.json;
        flakeInputs = {
          inherit logos-module-builder delivery_module liblogos_rln_module;
        };
      }).packages.${system}
    );
}
