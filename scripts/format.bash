#!/usr/bin/env bash

set -euo pipefail

current_script_path="${BASH_SOURCE[0]}"
script_dir="$(dirname "$current_script_path")"

export SHFMT_ACTION="--write"

# shellcheck source=lint.bash
source "${script_dir}/lint.bash"
