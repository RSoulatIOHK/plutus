#!/usr/bin/env bash

# Build Haddock documentation for all packages in Plutus, including internal 
# libraries.
#
# Usage: ./combined-haddock.sh DIR [COMPS ...]
#
#   DIR 
#     Where to put the generated pages, the default is 'haddock'.
#
#   COMPS 
#     The components to re-build haddocks for, or 'all' to rebuild everything
#     The default is "", which does not rebuild anything (useful for debugging
#     this script).

# Due to our custom setup, creating a standalone haddock for the Plutus project is not trivial.
# This is mostly because the html generated by `cabal haddock` contains broken links that point to 
# files inside the dist-newstyle folder and to various folders in the /nix/store.
# What we want is to have relative urls for the plutus packages and components, and links to 
# hackage for all other packages. Finally we need to treat the cardano-crypt-class edge case separately.

OUTPUT_DIR=${1:-haddock}

REGENERATE=("${@:2}")

BUILD_DIR=dist-newstyle

CABAL_OPTS=(
  --builddir "${BUILD_DIR}"
  --enable-documentation
)

# Haddock webpages have a header with the following items: 
# Quick Jump - Instances - Sources - Contents - Index
# Contents and Index are usually package or component-wide, but this can be 
# overritten. Here we make them point to the top-level, project-wide Contents 
# and Index, by using the --use-contents and --use-index flags respectively.
HADDOCK_OPTS=(
  --haddock-internal
  --haddock-html
  --haddock-hyperlink-source
  --haddock-option "--show-all"
  --haddock-option "--pretty-html"
  --haddock-option "--use-unicode"
  --haddock-option="--base-url=.."
  --haddock-option="--use-index=../index.html"
  --haddock-option="--use-contents=../doc-index.html"
  --haddock-quickjump
)

if (( "${#REGENERATE[@]}" > 0 )); then
  cabal update
  cabal freeze
  cabal build   "${CABAL_OPTS[@]}" "${REGENERATE[@]}"
  cabal haddock "${CABAL_OPTS[@]}" "${REGENERATE[@]}" "${HADDOCK_OPTS[@]}"
fi


if [[ "$?" != "0" ]]; then 
  echo "Failed to build haddock for plutus."
  exit 1
fi 


rm    -rf "${OUTPUT_DIR}"
mkdir -p  "${OUTPUT_DIR}"

GHC_VERSION="$(ghc --numeric-version)"

OS_ARCH="$(jq -r '"\(.arch)-\(.os)"' "${BUILD_DIR}/cache/plan.json")"

BUILD_CONTENTS="${BUILD_DIR}/build/${OS_ARCH}/ghc-${GHC_VERSION}"

PLUTUS_VERSION="$(find ${BUILD_CONTENTS}/plutus-core-* -printf '%f\n' -quit | sed "s/plutus-core-//g")"

GIT_REV="$(git rev-parse HEAD)"


# Here we merge each package's internal libraries into a single folder, for example:
# Merge:
#   plutus-core-1.29.0.0/l/index-envs/*
#   plutus-core-1.29.0.0/l/plutus-core-execlib/*
#   plutus-core-1.29.0.0/l/plutus-core-testlib/*
#   plutus-core-1.29.0.0/l/plutus-ir/*
#   plutus-core-1.29.0.0/l/plutus-ir-cert/*
#   plutus-core-1.29.0.0/l/satint/*
# Into: 
#   plutus-core/*
# 
# The same merging logic applies to source files:
# Merge: 
#   plutus-core-1.29.0.0/l/*/src/*
# Into: 
#   plutus-core/src/*
# 
# Because all modules have unique names, this is safe to do.
# We don't care that we override the doc-index-*.html files, since we always
# use the top-level ones.
echo "Copying contents"
for package_dir in "${BUILD_CONTENTS}"/*; do 
  package=$(basename "${package_dir}" | sed 's/-[0-9]\+\(\.[0-9]\+\)*//')
  if ! [ -d "${package_dir}/doc/html" ]; then continue; fi 
  mkdir -p "${OUTPUT_DIR}/${package}/src"
  cp -rn "${package_dir}/doc/html/${package}" "${OUTPUT_DIR}"
  if ! [ -d "${package_dir}/l" ]; then continue; fi 
  for sublib_dir in "${package_dir}"/l/*; do 
    package_lib=$(basename "${sublib_dir}")
    mkdir -p "${OUTPUT_DIR}/${package}/${package_lib}"
    cp -n "${sublib_dir}/doc/html/${package}"/*.html             "${OUTPUT_DIR}/${package}"
    cp -n "${sublib_dir}/doc/html/${package}/src"/*.html         "${OUTPUT_DIR}/${package}/src"
    cp -f "${sublib_dir}/doc/html/${package}/src"/{*.js,*.css}   "${OUTPUT_DIR}/${package}/src"
    cp -n "${sublib_dir}/doc/html/${package}/${package}.haddock" "${OUTPUT_DIR}/${package}/${package_lib}/${package}.haddock"
    cp -n "${sublib_dir}/doc/html/${package}/doc-index.json"     "${OUTPUT_DIR}/${package}/${package_lib}.doc-index.json"
  done 
done 


echo "Collecting --read-interface options"
INTERFACE_OPTIONS=()
for haddock_file in $(find "${OUTPUT_DIR}" -name "*.haddock"); do
  package=$(basename -s .haddock "${haddock_file}")
  INTERFACE_OPTIONS+=("--read-interface=${package},${haddock_file}")
done


echo "Writing the prologue"
cat << EOF > "${BUILD_DIR}/haddock.prologue"
== Handy module entrypoints

  * "PlutusTx": Compiling Haskell to PLC (Plutus Core; on-chain code).
  * "PlutusTx.Prelude": Haskell prelude replacement compatible with PLC.
  * "PlutusCore": Programming language in which scripts on the Cardano blockchain are written.
  * "UntypedPlutusCore": On-chain Plutus code.
EOF


echo "Generating top-level index and contents"
haddock \
  -o "${OUTPUT_DIR}" \
  --title "Combined Plutus ${PLUTUS_VERSION} Documentation" \
  --gen-index \
  --gen-contents \
  --quickjump \
  --prolog "${BUILD_DIR}/haddock.prologue" \
  "${INTERFACE_OPTIONS[@]}"


echo "Assembling top-level doc-index.json"
for file in $(find "${OUTPUT_DIR}" -name "*doc-index.json"); do
  project=$(basename "$(dirname "$file")");
  jq ".[] | .link = \"${project}/\(.link)\"" "${file}"
done | 
  jq -s . >"${OUTPUT_DIR}/doc-index.json"


echo "Generating sed file"
cat << EOF > "${BUILD_DIR}/sedscript.txt"
# From e.g.
#   href="file:///Volumes/Repos/plutus/dist-newstyle/build/aarch64-osx/ghc-9.6.5/plutus-core-1.29.0.0/doc/html/plutus-core/src/PlutusCore.Arity.html#Arity
# To
#   href="../../plutus-core/src/PlutusCore.Arity.html#Arity"
#  
s|href=\"file:///.*dist-newstyle/.*/doc/html/(.*)\"|href=\"../../\1\"|g

# From e.g.
#   href="file:///nix/store/ing9848aasbnza8aibjii5dznrd2cril-base64-bytestring-lib-base64-bytestring-1.2.1.0-haddock-doc/share/doc/base64-bytestring/html/src/Data.ByteString.Base64.html"
# To
#   href="https://hackage.haskell.org/package/base64-bytestring-1.2.1.0/docs/src/Data.ByteString.Base64.html" 
#
s|href=\"file:///nix/store/.{32}-.+-([0-9\.]+)-haddock-doc/share/doc/([^/]+)/html/([^\"]+)\"|href=\"https://hackage.haskell.org/package/\2-\1/docs/\3\"|g

# From e.g.
#   href="file:///nix/store/4rj4zlhhsl011g890xj4dq689x6zxb4x-ghc-9.6.5-doc/share/doc/ghc-9.6.5/html/libraries/base-4.18.2.1/src/GHC.Base.html#%3C%3E"
# To
#   href="https://hackage.haskell.org/package/base-4.18.2.1/docs/src/GHC.Base.html#%3C%3E"
# 
s|href=\"file:///nix/store/.{32}-ghc-${GHC_VERSION}-doc/share/doc/ghc-${GHC_VERSION}/html/libraries/([^/]+)/([^\"]+)\"|href=\"https://hackage.haskell.org/package/\1/docs/\2\"|g

# In cabal.project.freeze from e.g.
#   any.mono-traversable ==0.14.4,
# To
#   s|href=".*/mono-traversable/([^"]+)"|href="https://hackage.haskell.org/package/mono-traversable-1.0.15.3/docs/\1"|g
# And so from e.g.
#   href="../mono-traversable/Data-MonoTraversable.html#t:MonoFoldable"
# To
#   href="https://hackage.haskell.org/package/mono-traversable-1.0.15.3/docs/Data-MonoTraversable.html#t:MonoFoldable"
$(sed -E "s|\s*any\.([^=]*) ==([^,]*),|s\|href=\".*/\1/([^\"]+)\"\|href=\"https://hackage.haskell.org/package/\1-\2/docs/\\\1\"\|g|g" cabal.project.freeze | sed -E "/^[^s]/d")
EOF
# Note the embedded sed above: we refer to cabal.project.freeze to obtain all package versions.
# Then for each package-version we produce a different sed substitution.


NUM_FILES=$(find "${OUTPUT_DIR}" -type f -name "*.html" | wc -l)
echo "Applying sed to ${NUM_FILES} files"
time find "${OUTPUT_DIR}" -name "*.html" | xargs sed -i -E -f "${BUILD_DIR}/sedscript.txt"


echo "Checking that all hrefs to /nix/store were replaced"
if grep -qr "/nix/store" "${OUTPUT_DIR}"; then
  echo "internal error: not all /nix/store hrefs were replaced"
  exit 1
fi


echo "Checking that all hrefs to /dist-newstyle were replaced"
if grep -qr "dist-newstyle" "${OUTPUT_DIR}"; then 
  echo "internal error: not all href to dist-newstyle were replaced"
  exit 1
fi


echo "Looking for linkchecker"
if ! command -v linkchecker &> /dev/null; then
  echo "linkchecker not found"
  exit 0
fi 


echo "Running linkchecker"
time linkchecker "${OUTPUT_DIR}/index.html" \
  --check-extern \
  --no-warnings \
  --output failures \
  --file-output text 


if [[ "$?" != "0" ]]; then 
  echo "Found broken or unreachable 'href=' links in the files above (also see ./linkchecker-out.txt)"
fi 