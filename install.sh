#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/tar-install"

TARGET_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
TARGET="$TARGET_DIR/tar-install"

usage() {
    cat <<EOF
Usage:
  ./install.sh
  ./install.sh --uninstall
  ./install.sh --help

Install or update tar-install:
  ./install.sh

Uninstall tar-install:
  ./install.sh --uninstall
EOF
}

detect_shell_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-}")"

    case "$shell_name" in
        bash)
            printf '%s\n' "$HOME/.bashrc"
            ;;
        zsh)
            printf '%s\n' "$HOME/.zshrc"
            ;;
        *)
            printf '%s\n' ""
            ;;
    esac
}

path_contains_target() {
    case ":${PATH:-}:" in
        *":$TARGET_DIR:"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

add_path() {
    local rc_file="$1"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ -f "$rc_file" ]] && grep -Fqx "$path_line" "$rc_file"; then
        echo "PATH entry already exists in:"
        echo "  $rc_file"
        return
    fi

    {
        echo
        echo "# Added by tar-install"
        echo "$path_line"
    } >> "$rc_file"

    echo "Added ~/.local/bin to:"
    echo "  $rc_file"
    echo
    echo "Restart your shell or run:"
    echo "  source \"$rc_file\""
}

install_tar_install() {
    if [[ ! -f "$SOURCE" ]]; then
        echo "Error: tar-install was not found:"
        echo "  $SOURCE"
        exit 1
    fi

    mkdir -p "$TARGET_DIR"

    if [[ -f "$TARGET" ]]; then
        echo "tar-install is already installed:"
        echo "  $TARGET"
        echo

        read -r -p "Update it? [Y/n] " answer
        answer="${answer:-Y}"

        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "Update cancelled."
            exit 0
        fi

        echo "Updating..."
    else
        echo "Installing..."
    fi

    local temp_file
    temp_file="$(mktemp "$TARGET_DIR/.tar-install.XXXXXX")"

    cp "$SOURCE" "$temp_file"
    chmod +x "$temp_file"
    mv -f "$temp_file" "$TARGET"

    echo
    echo "Installed:"
    echo "  $TARGET"

    if path_contains_target; then
        echo
        echo "$TARGET_DIR is already in PATH."
    else
        local rc_file
        rc_file="$(detect_shell_rc)"

        if [[ -n "$rc_file" ]]; then
            echo
            echo "$TARGET_DIR is not in PATH."
            add_path "$rc_file"
        else
            echo
            echo "Your shell is not automatically supported."
            echo
            echo 'Add this to your shell configuration:'
            echo
            echo '  export PATH="$HOME/.local/bin:$PATH"'
        fi
    fi

    echo
    echo "Done."
    echo
    echo "Run:"
    echo "  tar-install --help"
}

uninstall_tar_install() {
    if [[ ! -e "$TARGET" && ! -L "$TARGET" ]]; then
        echo "tar-install is not installed:"
        echo "  $TARGET"
        exit 0
    fi

    echo "This will remove:"
    echo "  $TARGET"
    echo
    echo "Applications installed with tar-install will NOT be removed."
    echo

    read -r -p "Uninstall tar-install? [y/N] " answer

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi

    rm -f "$TARGET"

    echo
    echo "tar-install has been uninstalled."
    echo
    echo "Installed applications were left untouched."
    echo "Your shell PATH configuration was also left untouched."
}

case "${1:-}" in
    "")
        install_tar_install
        ;;

    --uninstall|uninstall)
        uninstall_tar_install
        ;;

    --help|-h|help)
        usage
        ;;

    *)
        echo "Unknown option: $1"
        echo
        usage
        exit 1
        ;;
esac