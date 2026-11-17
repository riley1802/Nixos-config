# rileyt's Home Manager config. home.stateVersion stays at the first install.
{ config, ... }:
{
  home-manager.users.${config.my.user} =
    { config, pkgs, ... }:
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
        settings = {
          user.name = "riley thomason";
          user.email = "thomasonriley0@gmail.com";
          credential = {
            "https://github.com" = {
              helper = [
                ""
                "${pkgs.gh}/bin/gh auth git-credential"
              ];
            };
            "https://gist.github.com" = {
              helper = [
                ""
                "${pkgs.gh}/bin/gh auth git-credential"
              ];
            };
          };
        };
      };

      # Alias from ~/.config/gh/config.yml. hosts.yml is the login file
      # and stays unmanaged. Credential helpers live on programs.git above.
      programs.gh = {
        enable = true;
        gitCredentialHelper.enable = false;
        settings.aliases.co = "pr checkout";
      };

      # Git prefers ~/.gitconfig over ~/.config/git/config. Link the path
      # Git already reads at the file Home Manager generates.
      home.file.".gitconfig".source = config.xdg.configFile."git/config".source;
    };
}
