#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/local .build/clang-cache
swiftc -module-cache-path "$PWD/.build/clang-cache" Sources/NotchDesk/FileStore.swift scripts/verify.swift -o .build/local/verify
.build/local/verify
