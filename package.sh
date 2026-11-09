#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
zsh build.sh
pkgbuild --component Morrow.app \
  --install-location /Applications \
  --identifier nl.codex.morrow \
  --version 0.1.0 \
  Morrow.pkg
echo "Built: $PWD/Morrow.pkg"
