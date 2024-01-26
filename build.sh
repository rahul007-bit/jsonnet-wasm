#!/bin/bash
# Call this script as `./build.sh <remove-older>` eg. `./build.sh false`

set -e

# Remove older build
if [ "$1" != "false" ]; then
    echo "Removing older build..."
    # check if pkg folder exists
    if [ -d "pkg" ]; then
        echo "Removing pkg folder..."
        rm -rf pkg
    fi
fi
OUT_FOLDER="pkg"
OUT_JSON="${OUT_FOLDER}/package.json"
OUT_TARGET="bundler"
OUT_NPM_NAME="jsonnet_wasm"
WASM_BUILD_PROFILE="release"

echo "Using build profile: \"${WASM_BUILD_PROFILE}\""

# Check if wasm-pack is installed
if ! command -v wasm-pack &> /dev/null
then
    echo "wasm-pack could not be found, installing now..."
    curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
fi

echo "Building query-engine-wasm using $WASM_BUILD_PROFILE profile"
CARGO_PROFILE_RELEASE_OPT_LEVEL="z" wasm-pack build "--$WASM_BUILD_PROFILE" --target $OUT_TARGET --out-name jsonnet_wasm

WASM_OPT_ARGS=(
    "-Os"                                 # execute size-focused optimization passes
    "--vacuum"                            # removes obviously unneeded code
    "--duplicate-function-elimination"    # removes duplicate functions
    "--duplicate-import-elimination"      # removes duplicate imports
    "--remove-unused-module-elements"     # removes unused module elements
    "--dae-optimizing"                    # removes arguments to calls in an lto-like manner
    "--remove-unused-names"               # removes names from location that are never branched to
    "--rse"                               # removes redundant local.sets
    "--gsi"                               # global struct inference, to optimize constant values
    "--gufa-optimizing"                   # optimize the entire program using type monomorphization
    "--strip-dwarf"                       # removes DWARF debug information
    "--strip-producers"                   # removes the "producers" section
    "--strip-target-features"             # removes the "target_features" section
)

# case "$WASM_BUILD_PROFILE" in
#     release)
#         # In release mode, we want to strip the debug symbols.
#         wasm-opt "${WASM_OPT_ARGS[@]}" \
#             "--strip-debug" \
#             "${OUT_FOLDER}/query_engine_bg.wasm" \
#             -o "${OUT_FOLDER}/query_engine_bg.wasm"
#         ;;
#     profiling)
#         # In profiling mode, we want to keep the debug symbols.
#         wasm-opt "${WASM_OPT_ARGS[@]}" \
#             "--debuginfo" \
#             "${OUT_FOLDER}/query_engine_bg.wasm" \
#             -o "${OUT_FOLDER}/query_engine_bg.wasm"
#         ;;
#     *)
#         # In other modes (e.g., "dev"), skip wasm-opt.
#         echo "Skipping wasm-opt."
#         ;;
# esac

sleep 1

enable_cf_in_bindings() {
    # Enable Cloudflare Workers in the generated JS bindings.
    # The generated bindings are compatible with:
    # - Node.js
    # - Cloudflare Workers / Miniflare

    local FILE="$1" # e.g., `query_engine.js`
    local BG_FILE="jsonnet_wasm_bg.js"
    local OUTPUT_FILE="${OUT_FOLDER}/jsonnet_wasm.js"

    cat <<EOF > "$OUTPUT_FILE"
import * as imports from "./${BG_FILE}";

// switch between both syntax for Node.js and for workers (Cloudflare Workers)
import * as wkmod from "./${BG_FILE%.js}.wasm";
import * as nodemod from "./${BG_FILE%.js}.wasm";
if ((typeof process !== 'undefined') && (process.release.name === 'node')) {
    imports.__wbg_set_wasm(nodemod);
} else {
    const instance = new WebAssembly.Instance(wkmod.default, { "./${BG_FILE}": imports });
    imports.__wbg_set_wasm(instance.exports);
}

export * from "./${BG_FILE}";
EOF
}

enable_cf_in_bindings "query_engine.js"
