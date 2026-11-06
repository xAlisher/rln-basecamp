{
  description = "rln_ui — RLN membership app for Basecamp (first backend:module reference implementation)";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    flake-utils.follows = "logos-module-builder/flake-utils";

    # Dependency module flakes, keyed by MODULE name so the builder can read their .lidl and
    # generate the modules().<dep> wrappers. Epic 1 pins exact refs to match metadata.json
    # (delivery_module ~0.4.0, liblogos_rln_module ~0.12.0).
    delivery_module.url = "github:logos-co/logos-delivery-module";
    liblogos_rln_module.url = "github:logos-co/logos-rln-modules";
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
