#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
if [[ "$PWD" != "$repo_root" ]]; then
  echo "Run this command from the repository root: $repo_root" >&2
  exit 1
fi

{
  git status --porcelain=v1
  git diff --binary --no-ext-diff HEAD
  git ls-files --others --exclude-standard -z \
    | sort -z \
    | xargs -0 -r sha256sum --
} | sha256sum | awk '{print $1}'
