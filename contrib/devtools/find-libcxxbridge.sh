#! /usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR="$SCRIPT_DIR/../.."

# The joy of multi-platform programming
multi_platform_stat_to_unix() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    /usr/bin/stat -f '%m %N' $@ 
    else
    # Linux
    /usr/bin/stat --format='%Y %n' $@ 
    fi
}

export -f multi_platform_stat_to_unix

# Find the most recent file by sorting by Unix epoch timestamps.
# Avoid using long opts in `cut`, as that's not part of the 
# standard macOS install.
find $ROOT_DIR/target -name libcxxbridge1.a -exec bash -c 'multi_platform_stat_to_unix "$0"' {} \; | sort -k 1 -n | cut -f 2 -d ' ' | head -1
