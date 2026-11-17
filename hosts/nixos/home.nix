# rileyt's Home Manager config. home.stateVersion stays at the first install.
{ config, ... }:
{
  home-manager.users.${config.my.user} =
    { config, ... }:
    {
      programs.home-manager.enable = true;
      # Set once. Do not bump it when Home Manager updates.
      home.stateVersion = "26.05";

      # Git already reads ~/.gitconfig. These are the only values in it.
      # gh's module adds the credential helper to the same file.
      programs.git = {
        enable = true;
        # git is already installed for the whole system.
        package = null;
        settings.user = {
          name = "riley thomason";
          email = "thomasonriley0@gmail.com";
        };
      };

      # Alias from ~/.config/gh/config.yml. hosts.yml is the login file
      # and stays unmanaged. gitCredentialHelper defaults to on and writes
      # the helper programs.git used to hardcode as a store path.
      programs.gh = {
        enable = true;
        settings.aliases.co = "pr checkout";
      };

      # Git prefers ~/.gitconfig over ~/.config/git/config. Link the path
      # Git already reads at the file Home Manager generates.
      home.file.".gitconfig".source = config.xdg.configFile."git/config".source;
    };
}
