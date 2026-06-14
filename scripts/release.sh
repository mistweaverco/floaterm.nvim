#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"

gh release create --generate-notes "$GH_TAG"
