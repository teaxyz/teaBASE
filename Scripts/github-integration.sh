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
    "firstly, we need to add the \`write:gpg_key\` and " \
    "\`admin:public_key\` scopes to your \`gh\` authentication" \
    "" \
    "> alternatively upload your keys manually:" \
    "> https://github.com/settings/keys"

  gh auth login -h github.com -p https -s write:gpg_key -s admin:public_key -w
fi

if ls ~/.ssh/id_* &>/dev/null; then
  gum format \
    "Found SSH public keys in your ~/.ssh directory." \
    "Do you want to:" \
    "1. Upload only your primary key (id_rsa.pub or id_ed25519.pub)" \
    "2. Upload all public keys (id_*.pub)" \
    "3. Skip"

  choice=$(gum choose "Upload primary key only" "Upload all keys" "Skip")
  if [ -n "$choice" ]; then
    case "$choice" in
      "Upload primary key only")
        for x in ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub; do
          if [ -f "$x" ]; then
            gum format "uploading $(basename "$x")…"
            gh ssh-key add "$x" --title "$(hostname -s) (added by teaBASE)"
          fi
        done
        ;;
      "Upload all keys")
        for x in ~/.ssh/id_*.pub; do
          gum format "uploading $(basename "$x")…"
          gh ssh-key add "$x" --title "$(hostname -s) (added by teaBASE)"
        done
        ;;
      "Skip")
        gum format "Skipping SSH key upload"
        ;;
    esac
  fi
fi


gum format "uploading your gpg public key…"

if GPG="$(bpb print)"; then
    echo "$GPG" | gh gpg-key add --title "$(hostname -s) (added by teaBASE)"
    # ^^ this errors out if the key already exists which sucks
    # ^^ TODO report bug
fi
