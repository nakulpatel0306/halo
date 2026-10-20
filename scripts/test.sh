#!/bin/zsh
# Runs the test suite. With only the Command Line Tools installed (no Xcode),
# Swift Testing lives outside the default search path and its Foundation
# overlay module is missing, so point at it and skip the overlay.
set -e
cd "${0:A:h}/.."
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
if [[ -d $F/Testing.framework ]] && ! xcode-select -p | grep -q Xcode.app; then
  exec swift test -Xswiftc -F$F -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F$F -Xlinker -rpath -Xlinker $F "$@"
fi
exec swift test "$@"
