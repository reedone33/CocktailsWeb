#!/bin/bash
# Double-click this to rebuild and publish by hand.
# It just runs publish.sh interactively - that script is the single source of
# truth for what publishing actually does.
cd "$(dirname "$0")"
./publish.sh
echo ""
read -n 1 -s -r -p "Press any key to close..."
