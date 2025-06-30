#!/usr/bin/env bash

set -euo pipefail

case $1:$2 in
  ubuntu:start)
    /run/current-system/sw/bin/resolvectl dns virbr0 100.64.0.2
    /run/current-system/sw/bin/resolvectl domain virbr0 deutsche-boerse.de oa.pnrad.net dbgcloud.io
    /run/current-system/sw/bin/resolvectl default-route virbr0 no
    ;;
esac
