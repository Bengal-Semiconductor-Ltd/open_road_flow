#!/usr/bin/env bash
#########################################################################
#  Build and install Yosys (+ slang plugin), OpenROAD, KLayout,         #
#  Verilator and cocotb, each with a versioned modulefile.              #
#                                                                       #
#  Run with:  bash install_all_tools.sh                                 #
#                                                                       #
#  Optional overrides (environment variables):                          #
#    ROOT_INSTALLATION=yes|no  install under /opt (sudo) or $HOME       #
#    SRC_DIR=<dir>             where sources are cloned (default $HOME) #
#    JOBS=<n>                  parallel build jobs (default nproc);     #
#                              lower it if WSL runs out of memory       #
#########################################################################

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "Do not source this script; run it with: bash ${BASH_SOURCE[0]}" >&2
    return 1
fi

set -euo pipefail
shopt -s inherit_errexit

#########################################################################
#                   define installation directory                       #
#########################################################################

ROOT_INSTALLATION="${ROOT_INSTALLATION:-yes}"
SRC_DIR="${SRC_DIR:-$HOME}"
JOBS="${JOBS:-$(nproc)}"

if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
    INSTALLATION_DIR="/opt/tools"
    MODULE_FILE_DIR="/opt/modulefiles"
else
    INSTALLATION_DIR="$HOME/tools"
    MODULE_FILE_DIR="$HOME/modulefiles"
fi
ENV_FILE="$INSTALLATION_DIR/env.sh"

#########################################################################
#                              helpers                                  #
#########################################################################

# Run a command as root only for a root installation. Builds always run as
# the normal user; only installation into $INSTALLATION_DIR uses this.
as_root() {
    if [[ "$ROOT_INSTALLATION" == "yes" ]]; then sudo "$@"; else "$@"; fi
}

log() { echo -e "\n===== $* =====\n" >&2; }

# Clone (or update) a repo, check out its latest tag and print that tag.
checkout_latest_tag() {
    local url=$1 dir=$2 ver
    if [[ -d "$dir/.git" ]]; then
        if [[ -n "$(find "$dir" -user root -print -quit)" ]]; then
            echo "ERROR: $dir contains root-owned files (left by an earlier sudo build)." >&2
            echo "       Fix with: sudo chown -R $USER: $dir" >&2
            exit 1
        fi
        git -C "$dir" fetch --tags --prune origin >&2
        git -C "$dir" remote set-head origin --auto >&2
    else
        git clone "$url" "$dir" >&2
    fi
    ver=$(git -C "$dir" describe --tags --abbrev=0 origin/HEAD)
    git -C "$dir" checkout --force "tags/$ver" >&2
    git -C "$dir" submodule update --init --recursive >&2
    echo "$ver"
}

# write_modulefile <tool> <version> <HOME_VAR> <home> <modulefile lines...>
# Overwrites the modulefile, so re-running never duplicates lines.
write_modulefile() {
    local tool=$1 ver=$2 var=$3 home=$4
    shift 4
    as_root mkdir -p "$MODULE_FILE_DIR/$tool"
    {
        echo '#%Module1.0'
        echo "setenv $var $home"
        printf '%s\n' "$@"
    } | as_root tee "$MODULE_FILE_DIR/$tool/$ver" > /dev/null
}

# Record "module load <tool>/<ver>" in the central env.sh, replacing any
# older version of the same tool.
register_env() {
    local tool=$1 ver=$2
    as_root touch "$ENV_FILE"
    as_root sed -i "\|^module load $tool/|d" "$ENV_FILE"
    echo "module load $tool/$ver" | as_root tee -a "$ENV_FILE" > /dev/null
}

#########################################################################
#                       directories and MODULEPATH                      #
#########################################################################

as_root mkdir -p "$INSTALLATION_DIR" "$MODULE_FILE_DIR"
mkdir -p "$SRC_DIR"

MODULE_USE_LINE="module use $MODULE_FILE_DIR"
if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
    # Own file instead of appending to the package-owned modules.sh. The "zz-"
    # prefix makes it run after modules.sh, which defines the module command.
    echo "$MODULE_USE_LINE" | sudo tee /etc/profile.d/zz-eda-modules.sh > /dev/null
    # Remove the lines that earlier versions of this script appended to modules.sh.
    if [[ -e /etc/profile.d/modules.sh ]]; then
        sudo sed -i --follow-symlinks "\|^$MODULE_USE_LINE\$|d" /etc/profile.d/modules.sh
    fi
else
    grep -qxF "$MODULE_USE_LINE" ~/.bashrc 2> /dev/null || echo "$MODULE_USE_LINE" >> ~/.bashrc
fi

#########################################################################
#                            Install yosys                              #
#########################################################################
log "Yosys"
YOSYS_SRC="$SRC_DIR/yosys"
YOSYS_VER=$(checkout_latest_tag https://github.com/YosysHQ/yosys.git "$YOSYS_SRC")
YOSYS_HOME="$INSTALLATION_DIR/yosys/$YOSYS_VER"

### Build and Install
# PREFIX is passed to the build as well as the install, so yosys-config
# reports the real install paths (needed by the slang plugin build).
make -C "$YOSYS_SRC" -j"$JOBS" PREFIX="$YOSYS_HOME"
as_root make -C "$YOSYS_SRC" install PREFIX="$YOSYS_HOME"

write_modulefile yosys "$YOSYS_VER" YOSYS_HOME "$YOSYS_HOME" \
    'prepend-path PATH $env(YOSYS_HOME)/bin' \
    'prepend-path LD_LIBRARY_PATH $env(YOSYS_HOME)/lib'
register_env yosys "$YOSYS_VER"

### slang plugin (SystemVerilog support), formerly yosys-slang, now sv-elab ###
# Optional: if it fails (e.g. this Yosys version is not supported by the
# plugin), the rest of the installation still continues.
build_slang() {
    local src="$SRC_DIR/sv-elab"
    if [[ -d "$src/.git" ]]; then
        git -C "$src" pull --ff-only >&2 || return 1
    else
        git clone https://github.com/povik/sv-elab.git "$src" >&2 || return 1
    fi
    git -C "$src" submodule update --init --recursive >&2 || return 1
    # Put the new Yosys first in PATH so its yosys-config is the one found.
    PATH="$YOSYS_HOME/bin:$PATH" cmake -S "$src" -B "$src/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DYOSYS_CONFIG="$YOSYS_HOME/bin/yosys-config" || return 1
    PATH="$YOSYS_HOME/bin:$PATH" cmake --build "$src/build" -j"$JOBS" || return 1
    as_root mkdir -p "$YOSYS_HOME/share/yosys/plugins" || return 1
    as_root cp "$src/build/slang.so" "$YOSYS_HOME/share/yosys/plugins/" || return 1
}
log "Yosys slang plugin"
if ! build_slang; then
    echo "WARNING: slang plugin build failed; Yosys is installed without it." >&2
fi

#########################################################################
#                            Install OpenROAD                           #
#########################################################################
log "OpenROAD"
OPENROAD_SRC="$SRC_DIR/OpenROAD"
OPENROAD_VER=$(checkout_latest_tag https://github.com/The-OpenROAD-Project/OpenROAD.git "$OPENROAD_SRC")
OPENROAD_HOME="$INSTALLATION_DIR/openroad/$OPENROAD_VER"
OPENROAD_BUILD="$OPENROAD_SRC/build_$OPENROAD_VER"

### Build and Install
# The dependency installer installs system packages, so it always needs sudo.
(cd "$OPENROAD_SRC" && sudo ./etc/DependencyInstaller.sh -all)
cmake -S "$OPENROAD_SRC" -B "$OPENROAD_BUILD" -DCMAKE_INSTALL_PREFIX="$OPENROAD_HOME"
cmake --build "$OPENROAD_BUILD" -j"$JOBS"
as_root cmake --install "$OPENROAD_BUILD"

write_modulefile openroad "$OPENROAD_VER" OPENROAD_HOME "$OPENROAD_HOME" \
    'prepend-path PATH $env(OPENROAD_HOME)/bin' \
    'prepend-path LD_LIBRARY_PATH $env(OPENROAD_HOME)/lib'
register_env openroad "$OPENROAD_VER"

#########################################################################
#                            Install klayout                            #
#########################################################################
log "KLayout"
KLAYOUT_SRC="$SRC_DIR/klayout"
KLAYOUT_VER=$(checkout_latest_tag https://github.com/KLayout/klayout.git "$KLAYOUT_SRC")
KLAYOUT_HOME="$INSTALLATION_DIR/klayout/$KLAYOUT_VER"

### Build and Install
# Build as the normal user into a staging dir, then copy it into place.
(cd "$KLAYOUT_SRC" && ./build.sh \
    -build "build_$KLAYOUT_VER" \
    -bin "bin_$KLAYOUT_VER" \
    -option "-j$JOBS" \
    -noruby)
as_root mkdir -p "$KLAYOUT_HOME/bin"
as_root cp -a "$KLAYOUT_SRC/bin_$KLAYOUT_VER/." "$KLAYOUT_HOME/bin/"

# KLayout keeps its shared libraries next to the executables in bin/.
write_modulefile klayout "$KLAYOUT_VER" KLAYOUT_HOME "$KLAYOUT_HOME" \
    'prepend-path PATH $env(KLAYOUT_HOME)/bin' \
    'prepend-path LD_LIBRARY_PATH $env(KLAYOUT_HOME)/bin'
register_env klayout "$KLAYOUT_VER"

#########################################################################
#                         Install Verilator                             #
#########################################################################
log "Verilator"
unset VERILATOR_ROOT
VERILATOR_SRC="$SRC_DIR/verilator"
VERILATOR_VER=$(checkout_latest_tag https://github.com/verilator/verilator.git "$VERILATOR_SRC")
VERILATOR_HOME="$INSTALLATION_DIR/verilator/$VERILATOR_VER"

### Build and Install
(
    cd "$VERILATOR_SRC"
    autoconf
    ./configure --prefix "$VERILATOR_HOME"
    make -j"$JOBS"
)
as_root make -C "$VERILATOR_SRC" install

write_modulefile verilator "$VERILATOR_VER" VERILATOR_HOME "$VERILATOR_HOME" \
    'prepend-path PATH $env(VERILATOR_HOME)/bin' \
    'prepend-path LD_LIBRARY_PATH $env(VERILATOR_HOME)/lib'
register_env verilator "$VERILATOR_VER"

#########################################################################
#                           Install cocotb                              #
#########################################################################
log "cocotb"
# Deliberately pinned to the 1.9.x series; cocotb 2.x has breaking API changes.
COCOTB_VER="v1.9.2"
COCOTB_HOME="$INSTALLATION_DIR/cocotb/$COCOTB_VER"
COCOTB_PIP="$COCOTB_HOME/venv/bin/pip"

# Virtual environment owned by this cocotb version
as_root mkdir -p "$COCOTB_HOME"
as_root python3 -m venv "$COCOTB_HOME/venv"
as_root "$COCOTB_PIP" install --upgrade pip
# One pip call, with cocotb pinned, so no extra package can upgrade cocotb.
as_root "$COCOTB_PIP" install \
    "cocotb[bus]==${COCOTB_VER#v}" \
    cocotb-coverage \
    cocotb-test \
    pytest \
    numpy

# The venv's bin/ (python3, pip, cocotb-config, pytest) goes first in PATH;
# its python finds the venv's site-packages by itself, so no PYTHONPATH.
write_modulefile cocotb "$COCOTB_VER" COCOTB_HOME "$COCOTB_HOME" \
    'prepend-path PATH $env(COCOTB_HOME)/venv/bin' \
    'conflict cocotb'
register_env cocotb "$COCOTB_VER"

#########################################################################
log "Done"
echo "Modulefiles: $MODULE_FILE_DIR"
echo "Load all tools in a new shell with: source $ENV_FILE"
