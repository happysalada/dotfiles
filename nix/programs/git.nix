{
  enable = true;
  userEmail = "raphael@megzari.com";
  userName = "happysalada";
  ignores = [ "*~" ".DS_Store" ];
  extraConfig = {
    core = {
      editor = "nvim";
    };

    url = {
      "git@github.com:" = {
        insteadOf = "https://github.com/";
      };
    };

    push.default = "upstream";

    pull.rebase = true;

    rebase = {
      autoSquash = true;
      autoStash = true;
    };
  };
}