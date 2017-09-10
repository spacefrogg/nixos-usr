{ config, lib, ... }:

with lib;

{
  options = {
    foo = mkOption {
      type = types.bool;
      default = false;
      description = "Foo option";
    };
  };
}
