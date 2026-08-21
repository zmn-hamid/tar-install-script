#!/usr/bin/env bash

set -euo pipefail

APP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/tar-install"
APP_DIR="$APP_ROOT/apps"
META_DIR="$APP_ROOT/metadata"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

mkdir -p "$APP_DIR" "$META_DIR" "$BIN_DIR" "$DESKTOP_DIR"

CLI_MODE=false
CLI_NAME=""

die() {
    echo "Error: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

usage() {
    cat <<EOF
Usage:
  tar-install <archive>
  tar-install --cli <archive>
  tar-install --cli <name> <archive>

  tar-install remove <app>
  tar-install list
  tar-install help

Options:
  --cli              Install as a CLI tool
  --cli <name>       Set the CLI command name

Supported archives:
  .tar.gz
  .tgz
  .tar.xz
  .tar.zst
  .zip
EOF
}

cleanup() {
    [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT

archive_name() {
    local filename
    filename="$(basename "$1")"

    filename="${filename%.tar.gz}"
    filename="${filename%.tgz}"
    filename="${filename%.tar.xz}"
    filename="${filename%.tar.zst}"
    filename="${filename%.zip}"

    echo "$filename"
}

sanitize_name() {
    echo "$1" |
        tr '[:upper:]' '[:lower:]' |
        sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

extract_archive() {
    local archive="$1"
    local destination="$2"

    case "$archive" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$destination"
            ;;
        *.tar.xz)
            tar -xJf "$archive" -C "$destination"
            ;;
        *.tar.zst)
            tar --zstd -xf "$archive" -C "$destination"
            ;;
        *.zip)
            unzip -q "$archive" -d "$destination"
            ;;
        *)
            die "Unsupported archive format."
            ;;
    esac
}

find_installers() {
    find "$1" -type f \
        \( \
            -iname 'install.sh' -o \
            -iname 'setup.sh' -o \
            -iname 'install' -o \
            -iname 'setup' \
        \) \
        -print0
}

find_executables() {
    find "$1" -type f -executable \
        ! -name 'install.sh' \
        ! -name 'setup.sh' \
        ! -name 'uninstall.sh' \
        ! -name 'uninstall' \
        ! -name '*crashpad*' \
        ! -name '*crash_reporter*' \
        ! -name 'chrome-sandbox' \
        ! -name '*.so' \
        ! -name '*.so.*' \
        -print0
}

list_apps() {
    local found=0

    for metadata in "$META_DIR"/*.conf; do
        [[ -f "$metadata" ]] || continue

        # shellcheck disable=SC1090
        source "$metadata"

        if [[ -n "${CLI_LINK:-}" ]]; then
            printf '%-25s %-10s %s\n' \
                "$APP_ID" "[CLI]" "$APP_NAME"
        else
            printf '%-25s %s\n' \
                "$APP_ID" "$APP_NAME"
        fi

        found=1
    done

    if [[ "$found" -eq 0 ]]; then
        echo "No tar-installed applications found."
    fi
}

remove_app() {
    local app="$1"
    local metadata="$META_DIR/$app.conf"

    [[ -f "$metadata" ]] ||
        die "Application '$app' is not installed by tar-install."

    # shellcheck disable=SC1090
    source "$metadata"

    echo "Removing: ${APP_NAME:-$app}"

    [[ -n "${DESKTOP_FILE:-}" && -f "$DESKTOP_FILE" ]] &&
        rm -f "$DESKTOP_FILE"

    [[ -n "${CLI_LINK:-}" && -L "$CLI_LINK" ]] &&
        rm -f "$CLI_LINK"

    [[ -n "${INSTALL_DIR:-}" && -d "$INSTALL_DIR" ]] &&
        rm -rf "$INSTALL_DIR"

    rm -f "$metadata"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
    fi

    echo "Removed '$app'."
}

install_app() {
    local archive="$1"

    [[ -f "$archive" ]] ||
        die "File does not exist: $archive"

    archive="$(realpath "$archive")"

    TMP_DIR="$(mktemp -d)"

    info "Extracting archive..."
    extract_archive "$archive" "$TMP_DIR"

    # --------------------------------------------------------
    # Check for bundled installer
    # --------------------------------------------------------

    local installers=()

    while IFS= read -r -d '' installer; do
        installers+=("$installer")
    done < <(find_installers "$TMP_DIR")

    if (( ${#installers[@]} > 0 )); then
        echo
        echo "This archive contains an installer script:"

        for installer in "${installers[@]}"; do
            echo "  ${installer#$TMP_DIR/}"
        done

        echo
        echo "You can abort now and install this application manually"
        echo "using its provided installer."

        read -r -p "Continue with automatic installation? [y/N] " answer

        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo
            echo "Aborted."
            echo
            echo "Extracted files are available at:"
            echo "  $TMP_DIR"
            echo
            echo "You can run:"
            echo "  ${installers[0]}"

            trap - EXIT
            exit 0
        fi
    fi

    # --------------------------------------------------------
    # Find .desktop file
    # --------------------------------------------------------

    local desktop_file=""
    local desktop_candidates=()

    while IFS= read -r -d '' file; do
        desktop_candidates+=("$file")
    done < <(
        find "$TMP_DIR" \
            -type f \
            -name '*.desktop' \
            -print0
    )

    if (( ${#desktop_candidates[@]} == 1 )); then
        desktop_file="${desktop_candidates[0]}"

    elif (( ${#desktop_candidates[@]} > 1 )); then

        echo
        echo "Multiple .desktop files found:"

        local i=1

        for file in "${desktop_candidates[@]}"; do
            echo "  [$i] ${file#$TMP_DIR/}"
            ((i++))
        done

        echo

        read -r -p "Select the main .desktop file [1]: " choice
        choice="${choice:-1}"

        [[ "$choice" =~ ^[0-9]+$ ]] ||
            die "Invalid selection."

        (( choice >= 1 && choice <= ${#desktop_candidates[@]} )) ||
            die "Invalid selection."

        desktop_file="${desktop_candidates[$((choice - 1))]}"
    fi

    # --------------------------------------------------------
    # Extract desktop information
    # --------------------------------------------------------

    local app_name=""
    local exec_path=""
    local icon_path=""
    local categories=""

    if [[ -n "$desktop_file" ]]; then

        app_name="$(
            grep -m1 '^Name=' "$desktop_file" |
            cut -d= -f2- ||
            true
        )"

        local desktop_exec

        desktop_exec="$(
            grep -m1 '^Exec=' "$desktop_file" |
            cut -d= -f2- ||
            true
        )"

        icon_path="$(
            grep -m1 '^Icon=' "$desktop_file" |
            cut -d= -f2- ||
            true
        )"

        categories="$(
            grep -m1 '^Categories=' "$desktop_file" |
            cut -d= -f2- ||
            true
        )"

        # Remove command-line arguments/placeholders.
        desktop_exec="${desktop_exec%% %*}"

        if [[ -n "$desktop_exec" ]]; then

            local candidate

            candidate="$(
                find "$TMP_DIR" \
                    -type f \
                    -name "$(basename "$desktop_exec")" \
                    -print -quit \
                    2>/dev/null ||
                    true
            )"

            [[ -n "$candidate" ]] &&
                exec_path="$candidate"
        fi
    fi

    # --------------------------------------------------------
    # Find executable
    # --------------------------------------------------------

    if [[ -z "$exec_path" ]]; then

        local executables=()

        while IFS= read -r -d '' file; do
            executables+=("$file")
        done < <(find_executables "$TMP_DIR")

        if (( ${#executables[@]} == 0 )); then
            die "Could not find a suitable executable."

        elif (( ${#executables[@]} == 1 )); then
            exec_path="${executables[0]}"

        else

            echo
            echo "Multiple executable candidates found:"

            local i=1

            for file in "${executables[@]}"; do
                echo "  [$i] ${file#$TMP_DIR/}"
                ((i++))
            done

            echo

            read -r -p "Select the main application [1]: " choice
            choice="${choice:-1}"

            [[ "$choice" =~ ^[0-9]+$ ]] ||
                die "Invalid selection."

            (( choice >= 1 && choice <= ${#executables[@]} )) ||
                die "Invalid selection."

            exec_path="${executables[$((choice - 1))]}"
        fi
    fi

    # --------------------------------------------------------
    # Determine application name
    # --------------------------------------------------------

    if [[ -z "$app_name" ]]; then
        app_name="$(basename "$exec_path")"
    fi

    local app_id
    app_id="$(sanitize_name "$app_name")"

    [[ -n "$app_id" ]] ||
        app_id="$(sanitize_name "$(archive_name "$archive")")"

    # --------------------------------------------------------
    # Installation directory
    # --------------------------------------------------------

    local install_dir="$APP_DIR/$app_id"
    local metadata="$META_DIR/$app_id.conf"

    if [[ -e "$install_dir" || -f "$metadata" ]]; then

        echo
        echo "Application '$app_id' is already installed."

        read -r -p "Replace it? [y/N] " answer

        [[ "$answer" =~ ^[Yy]$ ]] ||
            die "Installation cancelled."

        if [[ -f "$metadata" ]]; then
            remove_app "$app_id"
        else
            rm -rf "$install_dir"
        fi
    fi

    # --------------------------------------------------------
    # Copy application
    # --------------------------------------------------------

    info "Installing $app_name..."

    mkdir -p "$install_dir"

    mapfile -t top_level < <(
        find "$TMP_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -printf '%f\n'
    )

    if (( ${#top_level[@]} == 1 )) &&
       [[ -d "$TMP_DIR/${top_level[0]}" ]]; then

        cp -a "$TMP_DIR/${top_level[0]}"/. "$install_dir/"

    else

        cp -a "$TMP_DIR"/. "$install_dir/"
    fi

    # --------------------------------------------------------
    # Find final executable
    # --------------------------------------------------------

    local exec_basename
    exec_basename="$(basename "$exec_path")"

    local final_exec
    final_exec="$(
        find "$install_dir" \
            -type f \
            -name "$exec_basename" \
            -print -quit
    )"

    [[ -n "$final_exec" ]] ||
        die "Could not locate executable after installation."

    chmod +x "$final_exec"

    # --------------------------------------------------------
    # CLI mode
    # --------------------------------------------------------

    local cli_link=""

    if [[ "$CLI_MODE" == true ]]; then

        local command_name

        if [[ -n "$CLI_NAME" ]]; then
            command_name="$CLI_NAME"
        else
            command_name="$exec_basename"
        fi

        command_name="$(sanitize_name "$command_name")"

        [[ -n "$command_name" ]] ||
            die "Could not determine CLI command name."

        cli_link="$BIN_DIR/$command_name"

        if [[ -e "$cli_link" || -L "$cli_link" ]]; then

            echo
            echo "CLI command '$command_name' already exists:"
            echo "  $cli_link"

            read -r -p "Replace it? [y/N] " answer

            [[ "$answer" =~ ^[Yy]$ ]] ||
                die "Installation cancelled."

            rm -f "$cli_link"
        fi

        ln -s "$final_exec" "$cli_link"

        echo
        echo "CLI command:"
        echo "  $command_name"
    fi

    # --------------------------------------------------------
    # GUI desktop entry
    # --------------------------------------------------------

    local desktop_destination=""

    if [[ "$CLI_MODE" == false ]]; then

        desktop_destination="$DESKTOP_DIR/$app_id.desktop"

        local final_icon=""

        if [[ -n "$icon_path" ]]; then

            final_icon="$(
                find "$install_dir" \
                    -type f \
                    \( \
                        -name "$(basename "$icon_path")" -o \
                        -name "$(basename "$icon_path").png" -o \
                        -name "$(basename "$icon_path").svg" \
                    \) \
                    -print -quit \
                    2>/dev/null ||
                    true
            )"
        fi

        if [[ -z "$final_icon" ]]; then
            final_icon="$(
                find "$install_dir" \
                    -type f \
                    \( \
                        -iname '*.png' -o \
                        -iname '*.svg' -o \
                        -iname '*.xpm' \
                    \) \
                    -print -quit \
                    2>/dev/null ||
                    true
            )"
        fi

        cat > "$desktop_destination" <<EOF
[Desktop Entry]
Name=$app_name
Exec=$final_exec
Type=Application
Terminal=false
Categories=${categories:-Utility;}
EOF

        if [[ -n "$final_icon" ]]; then
            echo "Icon=$final_icon" >> "$desktop_destination"
        else
            echo "Icon=application-x-executable" >> "$desktop_destination"
        fi

        chmod +x "$desktop_destination"

        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$DESKTOP_DIR" \
                >/dev/null 2>&1 ||
                true
        fi
    fi

    # --------------------------------------------------------
    # Metadata
    # --------------------------------------------------------

    cat > "$metadata" <<EOF
APP_ID=$(printf '%q' "$app_id")
APP_NAME=$(printf '%q' "$app_name")
INSTALL_DIR=$(printf '%q' "$install_dir")
EXECUTABLE=$(printf '%q' "$final_exec")
DESKTOP_FILE=$(printf '%q' "$desktop_destination")
CLI_LINK=$(printf '%q' "$cli_link")
EOF

    # --------------------------------------------------------
    # Done
    # --------------------------------------------------------

    echo
    echo "Installed successfully."
    echo
    echo "  Name:       $app_name"
    echo "  Location:   $install_dir"
    echo "  Executable: $final_exec"

    if [[ "$CLI_MODE" == true ]]; then
        echo "  CLI:        $cli_link"
    else
        echo
        echo "It should now appear in your application menu."
    fi
}

# ============================================================
# Main
# ============================================================

[[ $# -gt 0 ]] || {
    usage
    exit 1
}

case "$1" in

    help|-h|--help)
        usage
        ;;

    list)
        list_apps
        ;;

    remove|uninstall)
        [[ $# -eq 2 ]] ||
            die "Usage: tar-install remove <app>"

        remove_app "$2"
        ;;

    --cli)
        CLI_MODE=true

        if [[ $# -eq 2 ]]; then
            install_app "$2"

        elif [[ $# -eq 3 ]]; then
            CLI_NAME="$2"
            install_app "$3"

        else
            die "Usage: tar-install --cli [command-name] <archive>"
        fi
        ;;

    *)
        [[ $# -eq 1 ]] ||
            die "Expected an archive."

        install_app "$1"
        ;;

esac