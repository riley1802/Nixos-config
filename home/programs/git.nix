{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Riley Thomason";
        email = "thomasonriley0@gmail.com";
      };
      # gh auth login cannot write into the HM-managed git config (read-only),
      # so wire its credential helper up declaratively instead.
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };
  };
}
