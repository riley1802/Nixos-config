{ ... }:

{
  # Passwordless pkexec for rileyt — single-user workstation; enables agent-driven
  # nixos-rebuild, nix-collect-garbage, and other admin commands without a TTY prompt.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          subject.user == "rileyt") {
        return polkit.Result.YES;
      }
    });
  '';
}
