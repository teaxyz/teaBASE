#!/usr/bin/env -S pkgx +gum bash>=4 -eo pipefail

PREFPANE="$(cd "$(dirname "$0")"/../.. && pwd)"

d="$(mktemp -dt teaBASE)"

gum format \
  "# teaBASE clean install pack" \
  "clean installing your machine regularly is good developer hygiene."
echo  #spacer

cd "$d"

if command -v brew >/dev/null 2>&1; then
  gum format "## Running \`brew bundle dump\`"
  brew bundle dump
fi

echo #spacer
gum format "## dotfiles" "adding whitelisted files"

cd "$HOME"

cnf="${XDG_CONFIG_HOME:-.config}"
cnf="${cnf/#$HOME/}"
cnf="${cnf#/}"

datahome="${XDG_DATA_HOME:-$HOME/.local/share}"
datahome="${datahome/#$HOME/}"
datahome="${datahome#/}"

dotfiles=()

# note, not space safe
#TODO some of these eg. .config/git/config are XDG aware
for x in .aws/* \
  .bash_login \
  .bash_history \
  .bashrc \
  .bash_profile \
  .*/config $cnf/**/config \
  $cnf/btop/btop.conf \
  $cnf/fish/config.fish \
  $cnf/pkgx/bpb.toml $datahome/pkgx/bpb.toml \
  .*/config.xml $cnf/**/config.xml \
  .*/config.yml $cnf/**/config.yml .*/config.yaml $cnf/**/config.yaml \
  .*/config.json $cnf/**/config.json \
  $datahome/share/fish/fish_history \
  .duckdb_history \
  .gitconfig $cnf/git/* \
  .irb_history \
  .lesshst \
  .netrc \
  .node_repl_history \
  .profile \
  .python_history \
  .*/settings.json $cnf/**/settings.json \
  .sh_history \
  .ssh/* \
  .sqlite_history \
  .vimrc \
  .zprofile \
  .zsh_history \
  .zshenv \
  .zshrc
do
  if test -f "$x"; then
    dotfiles+=("$x")
    gum format "\`~/$x\`"
  fi
done

if test -d .zsh_sessions; then
  dotfiles+=(.zsh_sessions)
  gum format "\`~/.zsh_sessions\`"
fi

tar cf "$d/dotfiles.tar" "${dotfiles[@]}"

add_file() {
  STEM="$1"

  gitdirs=()
  mapfile -d '' gitdirs < <(find "$STEM" -name .git -type d -print0)

  if [ "${#gitdirs[@]}" -eq 0 ]; then
    tar rf "$d/dotfiles.tar" "$STEM"
  else
    exclude_file="$(mktemp -t teaBASE)"

    srcdirs=()
    for gitdir in "${gitdirs[@]}"; do
      srcdir="$(dirname "$gitdir")"
      srcdirs+=("$srcdir")

      # get a list of all files except those that are ignored
      # rationale: `node_modules` etc. are gigabytes of caching
      mapfile -d '' tracked_files < <(git -C "$srcdir" ls-files --ignored --others --cached --directory --exclude-standard -z)

      for file in "${tracked_files[@]}"; do
        echo "$srcdir/$file" >> "$exclude_file"
      done
    done

    tar rf "$d/dotfiles.tar" --exclude-from="$exclude_file" "$STEM"
  fi
}

gum format \
  "# add additional files" \
  "for example, you may like to add your \`~/srcs\` directory." \
  "> we exclude files according to any discovered \`.gitignore\` files." \
  "" "or dotfiles we didn’t add above" \
  "> add dotfiles to our whitelist: https://github.com/teaxyz/teaBASE/issues/new"

while gum confirm "add additional files to pack?"
do
  file="$(gum file "$HOME" --all --file --directory)"

  STEM="${file#$HOME/}"

  if test "$STEM" = "$file"; then
    gum format "error: \`$file\` is not in \`$HOME\`" >&2
  elif test -f "$file"; then
    tar rf "$d/dotfiles.tar" "$STEM"
    gum format "\`~/$STEM\`"
  else
    export d
    export -f add_file
    gum spin --show-output --title "adding \`~/$STEM\`" -- bash -c "add_file \"$STEM\""
  fi
done

cd "$d"

if test -x /usr/local/bin/bpb && gum confirm "include GPG private key?"; then
  gum format "you will be prompted for your login password *twice*"

  BPB="$(security find-generic-password -s xyz.tea.BASE.bpb -w)"
fi

#TODO pkg brew into pkgx
cat <<EoSH >restore.command
#!/bin/bash

cd "\$(dirname "\$0")"

PATH="\$PWD/teaBASE.prefPane/Contents/MacOS:\$PATH"

set -a
eval "\$(pkgx +gum +mas)"
set +a

gum spin --title 'installing teaBASE' -- ditto teaBASE.prefPane ~/Library/PreferencePanes/teaBASE.prefPane

if gum confirm "extract dotfiles to \\\`\$HOME\\\`?"; then
  gum spin -- tar xf dotfiles.tar --cd "\$HOME"
fi

if test -f Brewfile && gum confirm 'install Homebrew; restore \`Brewfile\`?'; then
  /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  PATH="/opt/homebrew/bin:\$PATH" brew bundle install
fi

if test "$BPB"; then
  gum format "# restoring GPG private key"
  bpb import "$BPB"
fi

EoSH


unset BPB

chmod +x restore.command

for x in "$PREFPANE" ~/Library/PreferencePanes/teaBASE.prefPane /Library/PreferencePanes/teaBASE.prefPane
do
  if test "$(basename "$x")" = teaBASE.prefPane; then
    gum spin --title "copying teaBASE" -- ditto "$x" ./teaBASE.prefPane
    break
  fi
done

if ! test -d teaBASE.prefPane; then
  gum format \
    "# error: couldn’t bundle teaBASE" \
    "We will finish the bundle, but you’ll have to apply its contents yourself."
fi

gum format \
  "# creating DMG" \
  "enter an encryption password for your pack when prompted"

hdiutil create \
    -volname "teaBASE Clean Install Pack" \
    -encryption AES-256 \
    -stdinpass \
    -format UDZO \
    -srcfolder "$d" \
    ~/Downloads/Clean\ Install\ Pack.dmg

rm -rf "$d"

gum format \
    "# the pack is in ~/Downloads" \
    "**for the love of all that is good!** *verify* you can open the DMG with your password before clean installing!"
