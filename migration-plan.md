# brew → Nix flake (home-manager) 移行プラン

監査日: 2026-04-30
対象: `/Users/hikae/dotfiles` (home-manager + flake)
判定方法: `nix --extra-experimental-features 'nix-command flakes' search nixpkgs "^<name>$" --json` を全件並列実行。`aarch64-darwin` で attribute が返るかで存在判定。
既存 Nix 側: `modules/packages.nix` に `cachix, pinentry-curses, lato, mise, devenv, ghq, gh, ripgrep, fd, gitleaks`。`modules/programs/cli-tools.nix` に `programs.fzf/bat/lsd/aria2/starship` が `enable = true`。
既存 Nix module: `modules/programs/{aws,cli-tools,cmux,ghostty,git,tmux,zsh}.nix`。

## 凡例
- `nix-builtin`: home-manager の `programs.<name>.enable` で宣言できる (設定もNix化推奨)
- `already-nix`: 既に Nix 側で管理済み → brew から削除するだけ
- `nixpkgs`: `pkgs.<name>` をそのまま `packages.nix` に追加
- `nixpkgs-named-different`: nixpkgs 名が違う
- `darwin-cask-only`: GUI / cask 限定で nixpkgs 等価なし
- `unused-candidate`: 移行不要に見える / 削除候補
- `keep-brew`: 妥当な理由で brew のまま

---

## CLI formulae (brew leaves)

| name | 分類 | nix側名前 | 備考 |
| --- | --- | --- | --- |
| act | nixpkgs | pkgs.act | GitHub Actions ローカル実行 |
| actionlint | nixpkgs | pkgs.actionlint | |
| aria2 | already-nix | programs.aria2 | `cli-tools.nix` で enable 済 |
| ast-grep | nixpkgs | pkgs.ast-grep | |
| automake | nixpkgs | pkgs.automake | |
| aws-sam-cli | nixpkgs | pkgs.aws-sam-cli | |
| awscli | nixpkgs-named-different | pkgs.awscli2 | brew は `awscli`(=v2)。nix は `awscli2` を推奨 |
| bat | already-nix | programs.bat | enable 済 |
| binaryen | nixpkgs | pkgs.binaryen | wasm-opt 等。本当に必要か再検討 (unused-candidate 寄り) |
| bitwarden-cli | nixpkgs | pkgs.bitwarden-cli | |
| checkov | nixpkgs | pkgs.checkov | IaC スキャナ |
| cliclick | keep-brew | - | nixpkgs に **存在しない**。macOS only ツール。brew のまま (将来 overlay 化候補) |
| cloudflared | nixpkgs | pkgs.cloudflared | |
| cmake | nixpkgs | pkgs.cmake | |
| cocoapods | nixpkgs | pkgs.cocoapods | iOS 開発依存。Xcode と組で使うなら mise/Brewfile か検討 |
| coreutils | nixpkgs | pkgs.coreutils | GNU 版。`g`-prefix ではなく PATH 上書き相当に注意 |
| curl | nixpkgs | pkgs.curl | macOS 同梱があるので unused-candidate 寄り |
| deno | nixpkgs | pkgs.deno | mise でも管理可。重複に注意 |
| devcontainer | nixpkgs | pkgs.devcontainer | |
| docker-buildx | nixpkgs | pkgs.docker-buildx | |
| dotenvx | nixpkgs | pkgs.dotenvx | brew は tap (`dotenvx/brew/dotenvx`) だが nixpkgs に存在 |
| driftctl | nixpkgs | pkgs.driftctl | |
| duckdb | nixpkgs | pkgs.duckdb | |
| duti | nixpkgs | pkgs.duti | |
| fd | already-nix | pkgs.fd | `packages.nix` に有 |
| flyctl | nixpkgs | pkgs.flyctl | |
| frogmouth | nixpkgs | pkgs.frogmouth | brew は tap (`textualize/homebrew/frogmouth`) だが nixpkgs に有 |
| fzf | already-nix | programs.fzf | enable 済 |
| gh | already-nix | pkgs.gh | `packages.nix` に有 (programs.gh も検討余地) |
| git | nix-builtin | programs.git | 既に `modules/programs/git.nix` がある想定。brew 側は不要 |
| git-lfs | nix-builtin | programs.git-lfs / pkgs.git-lfs | home-manager に programs.git-lfs あり |
| github-mcp-server | nixpkgs | pkgs.github-mcp-server | |
| golangci-lint | nixpkgs | pkgs.golangci-lint | |
| graphviz | nixpkgs | pkgs.graphviz | |
| htop | nix-builtin | programs.htop | home-manager `programs.htop` で設定可 |
| httrack | nixpkgs | pkgs.httrack | unused-candidate 寄り (用途レア) |
| iproute2mac | nixpkgs | pkgs.iproute2mac | |
| jj | nixpkgs | pkgs.jj | jujutsu。`programs.jujutsu` があるなら nix-builtin |
| jq | nixpkgs | pkgs.jq | home-manager `programs.jq` も有 |
| just | nixpkgs | pkgs.just | `programs.just` も有 |
| libimobiledevice | nixpkgs | pkgs.libimobiledevice | iOS デバッグ用。使ってなければ削除候補 |
| lima | nixpkgs | pkgs.lima | podman/qemu と機能重複。要整理 |
| lsd | already-nix | programs.lsd | enable 済 |
| marp-cli | nixpkgs | pkgs.marp-cli | |
| mas | nixpkgs | pkgs.mas | Mac App Store CLI |
| mosh | nixpkgs | pkgs.mosh | |
| nmap | nixpkgs | pkgs.nmap | |
| nushell | nix-builtin | programs.nushell | home-manager に programs.nushell |
| ollama | nixpkgs | pkgs.ollama | unfree 設定不要。サービス化なら nix-darwin の launchd を検討 |
| opam | nixpkgs | pkgs.opam | OCaml 使うなら |
| openvpn | nixpkgs | pkgs.openvpn | |
| pandoc | nixpkgs | pkgs.pandoc | |
| pinact | nixpkgs | pkgs.pinact | |
| pipx | nixpkgs | pkgs.pipx | uv に統合候補 (CLAUDE.md は uv 推奨) → unused-candidate |
| pkgconf | nixpkgs-named-different | pkgs.pkg-config | nix では `pkg-config` |
| podman | nixpkgs | pkgs.podman | macOS では `podman` + `qemu` セット運用 |
| poppler | nixpkgs | pkgs.poppler | PDF utils。pdftotext 等 |
| postgresql@14 | nixpkgs-named-different | pkgs.postgresql_14 | `_14` 表記 |
| pueue | nixpkgs | pkgs.pueue | |
| qemu | nixpkgs | pkgs.qemu | lima の依存と重複の可能性 |
| radare2 | nixpkgs | pkgs.radare2 | |
| rclone | nixpkgs | pkgs.rclone | `programs.rclone` 検討 |
| redis | nixpkgs | pkgs.redis | サービスなら nix-darwin |
| rtk | nixpkgs | pkgs.rtk | (nixpkgs にヒット — 用途確認推奨) |
| sccache | nixpkgs | pkgs.sccache | |
| sn0int | nixpkgs | pkgs.sn0int | |
| sops | nixpkgs | pkgs.sops | |
| sox | nixpkgs | pkgs.sox | |
| sqlc | nixpkgs | pkgs.sqlc | |
| sshpass | nixpkgs | pkgs.sshpass | brew は tap (`hudochenkov/sshpass`)。nix に普通に存在 |
| telnet | nixpkgs-named-different | pkgs.inetutils | nix の `inetutils` に telnet が同梱。`telnet` 単体は無し |
| terminal-notifier | nixpkgs | pkgs.terminal-notifier | |
| terraformer | nixpkgs | pkgs.terraformer | |
| tfenv | nixpkgs | pkgs.tfenv | mise で terraform 管理しているなら unused-candidate |
| tmux | already-nix | programs.tmux | `modules/programs/tmux.nix` 有 |
| tree | nixpkgs | pkgs.tree | |
| tree-sitter | nixpkgs | pkgs.tree-sitter | |
| tree-sitter-go | unused-candidate | - | 通常はエディタ拡張側で持つ。明示インストールは不要なはず |
| tree-sitter-python | unused-candidate | - | 同上 |
| trivy | nixpkgs | pkgs.trivy | |
| trufflehog | nixpkgs | pkgs.trufflehog | |
| mole | nixpkgs | pkgs.mole | brew は tap (`tw93/tap/mole`) |
| vhs | nixpkgs | pkgs.vhs | charm.sh ターミナル録画 |
| wasmtime | nixpkgs | pkgs.wasmtime | |
| wget | nixpkgs | pkgs.wget | curl と重複気味。要否確認 |
| wrkflw | nixpkgs | pkgs.wrkflw | |
| yt-dlp | nixpkgs | pkgs.yt-dlp | |
| z3 | nixpkgs | pkgs.z3 | SMT ソルバ。用途確認 (unused-candidate 寄り) |
| zbar | nixpkgs | pkgs.zbar | バーコード。unused-candidate 寄り |
| zig | nixpkgs | pkgs.zig | バージョン固定したいなら `pkgs.zig_0_14` 等 |
| zsh-autosuggestions | nix-builtin | programs.zsh.autosuggestion.enable | `modules/programs/zsh.nix` で設定済の可能性。brew からは外す |

## Casks (brew list --cask)

| name | 分類 | 代替 | 備考 |
| --- | --- | --- | --- |
| android-commandlinetools | nixpkgs-named-different | pkgs.android-tools | sdkmanager 系は別途 |
| android-platform-tools | nixpkgs-named-different | pkgs.android-tools | adb/fastboot 含む |
| applite | darwin-cask-only | - | brew の GUI 管理ラッパ。Nix 移行後は不要 → 削除候補 |
| arc | darwin-cask-only | - | nixpkgs等価なし。Arc は手動DLか cask 維持 |
| authy | darwin-cask-only | - | サ終済み。**削除候補** (公式は 2024 年に desktop 廃止) |
| bitwarden | nixpkgs-named-different | pkgs.bitwarden-desktop | unfree 注意 |
| block-goose | darwin-cask-only | - | nixpkgs に同名なし。`pkgs.goose` は別物 (DB migration tool)。cask のまま |
| calibre | nixpkgs | pkgs.calibre | darwin で動くか要検証。動かないなら cask |
| codex | nixpkgs | pkgs.codex | Open AI codex CLI。cask になっているがCLI/GUIどちらか確認 |
| cursor | nixpkgs-named-different | pkgs.code-cursor | (`pkgs.cursor` は別物。`code-cursor` を使う) |
| discord | nixpkgs | pkgs.discord | unfree |
| entire | darwin-cask-only | - | (出自不明なツール — 用途確認、未使用なら削除) |
| font-plemol-jp-nf | nix-builtin | fonts (modules/fonts.nix) | `pkgs.plemoljp-nf` または NerdFonts override で取得可 |
| fuse-t | darwin-cask-only | - | macFUSE 互換 kext 不要版。Nix 等価なし。cask 維持 |
| fuse-t-sshfs | darwin-cask-only | - | 同上 |
| gcloud-cli | nixpkgs-named-different | pkgs.google-cloud-sdk | brew は cask だが nix の CLI 版あり |
| ghir | darwin-cask-only | - | nixpkgs 等価なし。cask 維持 or 削除検討 |
| ghostty | already-nix | modules/programs/ghostty.nix | 既に Nix 側で設定有 → cask 削除 |
| git-it | darwin-cask-only | - | git 学習アプリ。**削除候補** |
| google-chrome | nixpkgs | pkgs.google-chrome | darwin での実際の動作確認が必要。動かなければ cask |
| google-cloud-sdk | nixpkgs | pkgs.google-cloud-sdk | gcloud-cli と重複。**統合** |
| iterm2 | nixpkgs | pkgs.iterm2 | ghostty 使用なら **削除候補** |
| macfuse | keep-brew | - | kext を含むのでカーネル拡張承認が必要。brew/手動が現実的 |
| mitmproxy | nixpkgs | pkgs.mitmproxy | CLI 版なら formula へ移行検討 |
| ngrok | nixpkgs | pkgs.ngrok | unfree |
| obs | nixpkgs-named-different | pkgs.obs-studio | darwin ビルド要確認 |
| raycast | nixpkgs | pkgs.raycast | darwin 用 cask。nixpkgs にあるが起動確認推奨 |
| sequel-ace | darwin-cask-only | - | MAS 配布 / cask。nixpkgs なし。cask 維持 |
| session-manager-plugin | darwin-cask-only | - | AWS SSM Session Manager plugin。nixpkgs なし。cask 維持 |
| slack | nixpkgs | pkgs.slack | unfree。darwin ビルド要確認 |
| spotify | nixpkgs | pkgs.spotify | unfree。darwin 動作要確認 |
| visual-studio-code | nixpkgs-named-different | pkgs.vscode | unfree。`programs.vscode` モジュールで設定一元化推奨 |

---

## サマリ

- CLI formulae 総数: 88 (tap 含む)
  - already-nix: 7 (aria2, bat, fd, fzf, gh, lsd, tmux 等の既設定組)
  - nix-builtin (programs.* に置換推奨): 6 (git, git-lfs, htop, jj, jq, just, nushell, zsh-autosuggestions のうち `programs.*` で書ける物)
  - nixpkgs (pkgs.<name> にそのまま): 約 60
  - nixpkgs-named-different: 5 (awscli→awscli2, pkgconf→pkg-config, postgresql@14→postgresql_14, telnet→inetutils, dotenvx の tap→pkgs.dotenvx)
  - keep-brew: 1 (cliclick)
  - unused-candidate: 6 (binaryen, curl, httrack, libimobiledevice, pipx, tfenv, tree-sitter-go, tree-sitter-python, wget, z3, zbar — 用途次第)
- Casks 総数: 31
  - already-nix: 1 (ghostty)
  - nix移行可能 (pkgs.*): 11 (android-tools, calibre, codex, cursor→code-cursor, discord, google-chrome, google-cloud-sdk, mitmproxy, ngrok, obs-studio, raycast, slack, spotify, vscode, bitwarden-desktop) — **ただし darwin で実際に GUI として動作するかは要 1 個ずつ検証**
  - darwin-cask-only (cask 維持): 8 (arc, applite, block-goose, fuse-t, fuse-t-sshfs, ghir, sequel-ace, session-manager-plugin, macfuse)
  - 削除候補: 3 (authy, git-it, entire)
  - 重複/不要: gcloud-cli + google-cloud-sdk (片方に統合), iterm2 (ghostty 移行済なら不要)
- nixpkgs 不在で brew のまま必要: cliclick, fuse-t/fuse-t-sshfs, macfuse, sequel-ace, session-manager-plugin, arc, ghir, block-goose

## 技術負債の指摘 (Secure By Design)

1. **mise / nix / brew の三重管理**: deno, zig, terraform(tfenv), python(pipx) など複数経路で同じ言語ランタイムが管理可能。`mise` を言語ランタイム専用、`nix` を CLI/GUI 専用にレイヤを切る方針を明文化すべき。
2. **`packages.nix` がフラット**: 用途別にカテゴリ化(secure-tools, dev-tools, media-tools)し、`imports = [ ./packages/dev.nix ./packages/security.nix ];` 構造にすると追加時のハッシュピン管理が容易。
3. **flake.lock のピン更新ポリシー未定義**: SLSA L3 を狙うなら `nix flake update` の頻度・トリガを `Workflow` に追記が必要 (例: 月次 PR 自動化)。
4. **unfree 許可の宣言場所**: slack/vscode/spotify/discord/google-chrome を nix 化すると `nixpkgs.config.allowUnfreePredicate` を home.nix で宣言する必要が出る → 明示リストで pin する方が監査性高い。
5. **cask ⇄ nix の二重インストール検出が未整備**: 移行時に「brew にも nix にも入っている」状態を検知する pre-activation スクリプトを `home.activation` に入れるべき。

## 次にやるべきこと (実行順)

1. `modules/packages.nix` に `awscli2, pkg-config, postgresql_14, inetutils` と nixpkgs 直行組 60 個を追加 → activate でビルド確認。
2. `modules/programs/{git,git-lfs,htop,jq,just,jujutsu,nushell}.nix` を新設し home-manager の programs.* で宣言。`zsh-autosuggestions` は `programs.zsh.autosuggestion.enable = true;` に統合。
3. unfree 許可を `home.nix` か `flake.nix` で `nixpkgs.config.allowUnfreePredicate` 宣言。`vscode/slack/discord/spotify/chrome` を nix 化して darwin で起動確認 (動かないものは cask に戻す)。
4. brew 側で重複するもの (`brew uninstall <name>` / `brew uninstall --cask <name>`) を一括削除。`brew bundle dump` で残骸 Brewfile を作って差分監査。
5. authy, git-it, entire, tree-sitter-go, tree-sitter-python, binaryen 等の unused-candidate を実際に最後に使った日 (`brew info --json=v2 <name>` の `installed_on_request`) で確認、未使用なら削除。
6. cliclick / macfuse / fuse-t / sequel-ace / session-manager-plugin / arc / ghir / block-goose のみ Brewfile に残し、`brew bundle --file=~/dotfiles/Brewfile` で宣言的管理 (Nix 化できない部分も宣言化)。
7. `flake.lock` 自動更新の GitHub Actions と、移行後の `home.activation` で「brew で残ってる重複パッケージを警告する」hook を追加。
