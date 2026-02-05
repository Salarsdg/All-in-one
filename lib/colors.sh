#!/usr/bin/env bash
# ANSI colors (auto-disable if not a TTY)
if [[ -t 1 ]]; then
  RED=$'\e[31m'
  GREEN=$'\e[32m'
  YELLOW=$'\e[33m'
  BLUE=$'\e[34m'
  BOLD=$'\e[1m'
  NC=$'\e[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; NC=""
fi
