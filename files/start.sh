#!/bin/bash

set -e

if [[ ! -z "$CONFIG_GIT" ]]; then
  echo "CONFIG_GIT defined: $CONFIG_GIT"
  git_=/etc/bind/git

  if [[ -z "$GIT_BRANCH" ]]; then
    GIT_BRANCH=main
  fi

  if [[ ! -e "$git_/.git" ]]; then
    ssh-keyscan github.com >> ~/.ssh/known_hosts
    git clone "$CONFIG_GIT" "$git_"
  else
    mkdir -pv "$git_"
    git -C "$git_" fetch origin
  fi

  git -C "$git_" checkout "$GIT_BRANCH"

  conf="$git_/named.conf"
else
  conf="/etc/bind/named.conf"
fi

shopt -s expand_aliases

refresh_interval() {
  while true; do
    sleep "$REFRESH_INTERVAL"
    if [[ ! -z "$git_" ]]; then
      local output=`git -C "$git_" pull`
      if [[ "$output" =~ 'Already up to date' ]]; then
        continue
      fi
    fi
    rndc reload
  done
}

if [[ ! -z "$REFRESH_INTERVAL" ]]; then
  if [[ "$REFRESH_INTVERAL" -lt 60 ]]; then
    REFRESH_INTERVAL=60
  fi
  echo "Using refresh interval of $REFRESH_INTERVAL seconds"

  refresh_interval &
  refreshpid="$!"
fi

service nginx start

/usr/sbin/named -g -c "$conf" -u bind
