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
  if [[ -z "$NGINX_CONF" ]] && [[ -e "$git_/nginx.conf" ]]; then
    NGINX_CONF="$git_/nginx.conf"
  fi
else
  conf="/etc/bind/named.conf"
fi

if [[ -z "$CONF" ]]; then
  CONF="$conf"
fi

if [[ -z "$NGINX_CONF" ]]; then
  NGINX_CONF=/etc/nginx/nginx.conf
fi

echo "Using CONF=$CONF"
echo "Using NGINX_CONF=$NGINX_CONF"

shopt -s expand_aliases

refresh_interval() {
  if [[ -z "$git_" ]]; then
    echo "WARN: Refresh not supported in non-git mode" >&2
    return 0
  fi
  while true; do
    sleep "$REFRESH_INTERVAL"
    local output=`git -C "$git_" pull`
    if [[ "$output" =~ 'Already up to date' ]]; then
      continue
    fi
    rndc reload
    nginx -s reload
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

nginx -c "$NGINX_CONF"

/usr/sbin/named -g -c "$CONF" -u bind
