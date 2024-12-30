#!/bin/bash

PATH="$(cd "$(dirname "$0")"/../MacOS && pwd)${PATH:+:$PATH}"

set -a
# gh command uses git underneath for auth for some reason
eval "$(pkgx +gh +gum +git)"
set +a

set -eo pipefail

if gh auth status 2>/dev/null; then
    # check for required scopes
    scopes="$(gh api user -H "Authorization: token $(gh auth token)" -i | grep -i 'X-OAuth-Scopes:')"
fi

if [[ $scopes == *"admin:public_key"* && $scopes == *"write:gpg_key"* ]]; then
  true
else
  gum format \
    "# \`gh\` auth status is missing required scopes" \
    "firstly, we need to add the \`write:gpg_key\` and " \
    "\`admin:public_key\` scopes to your \`gh\` authentication" \
    "" \
    "> alternatively upload your keys manually:" \
    "> https://github.com/settings/keys"

  gh auth login -h github.com -p https -s write:gpg_key -s admin:public_key -w
fi

if test $(find ~/.ssh -name id_\*.pub | wc -l) -gt 1; then
  gum format \
    "# multiple ssh public keys found" \
    "choose which to upload" \
    "> use the arrow keys to move the cursor, space to toggle and press return when done"
  echo  #spacer

  files="$(gum choose --no-limit --selected=id_ed25519.pub,id_rsa.pub $(cd ~/.ssh && ls id_*.pub))"

  echo  #spacer

  for x in $files; do
    gum format "uploading \`$x\`…"
    gh ssh-key add ~/.ssh/"$x" --title "$(hostname -s) (added by teaBASE)"
  done
else
  x="$(ls "$HOME"/.ssh/id_*.pub)"
  gum format "# uploading \`$x\`…"
  gh ssh-key add "$x" --title "$(hostname -s) (added by teaBASE)"
fi

if GPG="$(bpb print)"; then
    gum format "# uploading your gpg public key…"

    echo "$GPG" | gh gpg-key add --title "$(hostname -s) (added by teaBASE)"
    # ^^ this errors out if the key already exists which sucks
    # ^^ TODO report bug
fi
