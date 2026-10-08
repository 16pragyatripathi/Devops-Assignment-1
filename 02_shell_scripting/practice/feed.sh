#!/bin/bash
# feed.sh - types answers into an interactive script through a pseudo-terminal,
# one answer every half second, so the read -p prompts and the answers appear
# on screen the same way they do when I type them by hand.
# usage: ./feed.sh <script> <answer1> [answer2 ...]

target=$1
shift
( for answer in "$@"; do sleep 0.5; echo "$answer"; done ) \
  | script -qec "$target" /dev/null | tr -d '\r'
