#!/bin/bash

set -e
shopt -s expand_aliases

alias git=/usr/bin/git
alias named=/usr/sbin/named
alias named-checkconf=/usr/sbin/named-checkconf
alias nginx=/usr/sbin/nginx
alias printf=/usr/bin/printf
alias rndc=/usr/sbin/rndc
alias service=/usr/sbin/service
alias ssh-keyscan=/usr/bin/ssh-keyscan

hr='------------------------------------------------------------'

printh() {
  printf '%s\n%s\n%s\n' "$hr" "$1" "$hr"
}

restart_nginx() {
  local nginxconf
  if [[ -z "$NGINX_CONF" ]] && [[ ! -z "$git_" ]] && [[ -e "$git_/nginx.conf" ]]; then
    nginxconf="$git_/nginx.conf"
  else
    nginxconf="/etc/nginx/nginx.conf"
  fi
  if service nginx status ; then
    printf '%s\n' 'Stopping nginx'
    nginx -s stop || true
  fi
  printf '%s\n' 'Starting nginx'
  printh "Using nginx config: $nginxconf"
  nginx -c "$nginxconf"
}

reload_bind() {
  printh "Reloading bind config"
  rndc reload
  printh "Reloaded bind config"
}

update_static() {
  local www_="/var/www"
  local fcommit="$www_/commit.txt" fconf="$www_/config.txt"
  if [[ ! -z "$git_" ]]; then
    git -C "$git_" log -1 2>&1 > "$fcommit" || true
  fi
  named-checkconf -p "$CONF" 2>&1 > "$fconf" || true
}

refresh_interval() {
  if [[ -z "$git_" ]]; then
    printh "WARN: Refresh not supported in non-git mode" >&2
    return 0
  fi
  while true; do
    sleep "$REFRESH_INTERVAL"
    local output=`git -C "$git_" pull`
    if [[ "$output" =~ 'Already up to date' ]]; then
      continue
    fi
    reload_bind
    restart_nginx
    update_static
  done
}

if [[ ! -z "$CONFIG_GIT" ]]; then
  printh "CONFIG_GIT defined: $CONFIG_GIT"
  git_="/etc/bind/git"

  if [[ -z "$GIT_BRANCH" ]]; then
    GIT_BRANCH="main"
  fi

  if [[ ! -e "$git_/.git" ]]; then
    if [[ "$CONFIG_GIT" =~ 'github.com' ]]; then
      ssh-keyscan github.com >> ~/.ssh/known_hosts
    fi
    if [[ ! -z "$SSH_SCAN" ]]; then
      for host in $SSH_SCAN ; do
        ssh-keyscan "$host" >> ~/.ssh/known_hosts
      done
    fi
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

if [[ -z "$CONF" ]]; then
  CONF="$conf"
fi

printh "Using named config: $CONF"

if [[ ! -z "$REFRESH_INTERVAL" ]]; then
  if [[ "$REFRESH_INTVERAL" -lt 60 ]]; then
    REFRESH_INTERVAL=60
  fi
  printh "Using refresh interval of $REFRESH_INTERVAL seconds"

  refresh_interval &
  refreshpid="$!"
fi

restart_nginx
update_static
printh "Starting bind"
named -g -c "$CONF" -u bind
