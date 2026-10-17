{
  config,
  ...
}:

let
  home = config.home.homeDirectory;
  runnerDir = "${home}/actions-runner";
in
{
  # label `hikae` の self-hosted runner。darwin の activation 破壊を検出・修復する workflow 専用。
  # runner 本体は自己更新するため配置は ~/actions-runner (stateful)、plist だけ宣言管理する。
  launchd.agents.github-runner = {
    enable = true;
    config = {
      Label = "dev.egahika.github-runner";
      ProgramArguments = [
        "/bin/bash"
        "${runnerDir}/bin/runsvc.sh"
      ];
      WorkingDirectory = runnerDir;
      EnvironmentVariables.ACTIONS_RUNNER_SVC = "1";
      ProcessType = "Interactive";
      SessionCreate = true;
      RunAtLoad = true;
      StandardOutPath = "${home}/.cache/github-runner.log";
      StandardErrorPath = "${home}/.cache/github-runner.err";
    };
  };
}
