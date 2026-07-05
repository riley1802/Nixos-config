{ config, ... }:

{
  age.secrets.hermes-env = {
    file = ../../../secrets/hermes-env.age;
    owner = "hermes";
    group = "hermes";
    mode = "0640";
  };

  services.hermes-agent.environmentFiles = [
    config.age.secrets.hermes-env.path
  ];
}
