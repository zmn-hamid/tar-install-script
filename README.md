# tar-install

A simple, user-local installer for Linux applications distributed as `.tar.gz`, `.tgz`, `.tar.xz`, `.tar.zst`, or `.zip` archives.

`tar-install` lets you install portable Linux applications without `sudo`, while automatically creating application launchers or CLI commands.

## Features

* Install applications without root access
* Supports:

  * `.tar.gz`
  * `.tgz`
  * `.tar.xz`
  * `.tar.zst`
  * `.zip`
* Automatically detects application executables
* Detects and uses included `.desktop` files
* Automatically finds application icons when possible
* Falls back to a generic application icon when no icon is available
* Detects bundled `install.sh` / `setup.sh` scripts and lets you choose whether to use them manually
* Supports CLI applications
* Handles archives where the archive name and executable name are different
* Interactive selection when multiple executables are found
* Keeps installations entirely inside the user's home directory
* Includes basic installation metadata for clean removal
* No package manager integration or system files are modified

## Installation

Clone the repository:

```bash
git clone <repository-url>
cd tar-install
```

Run the installer:

```bash
./install.sh
```

The installer will:

* Install `tar-install` to `~/.local/bin/`
* Make it executable
* Add `~/.local/bin` to your `PATH` if necessary
* Detect Bash and Zsh automatically
* Update an existing installation if `tar-install` is already installed

### Bash

If Bash is detected, the installer adds the PATH configuration to:

```text
~/.bashrc
```

### Zsh

If Zsh is detected, it adds the PATH configuration to:

```text
~/.zshrc
```

For unsupported shells, the installer will show the PATH configuration that needs to be added manually.

After installation, restart your shell or source its configuration file.

Verify the installation:

```bash
tar-install --help
```

## Updating

To update an existing installation, get the latest version of the repository and run:

```bash
./install.sh
```

If `tar-install` is already installed, the installer will ask whether you want to update it.

The update only replaces the `tar-install` executable. Applications previously installed using `tar-install` are not affected.

## Uninstallation

To uninstall `tar-install itself:

```bash
./install.sh --uninstall
```

This removes the `tar-install` executable but **does not remove applications installed with it**.

Previously installed applications remain untouched.

The PATH configuration is also intentionally left in your shell configuration so reinstalling `tar-install` does not require modifying it again.

## Installing a GUI application

Run:

```bash
tar-install application.tar.gz
```

The archive is extracted and inspected automatically.

If an application executable can be identified, the application is installed under:

```text
~/.local/share/tar-install/apps/
```

A `.desktop` launcher is created under:

```text
~/.local/share/applications/
```

The application should then appear in your desktop environment's application menu.

No `sudo` is required.

## Installing a CLI application

Use `--cli`:

```bash
tar-install --cli application.tar.gz
```

The executable is installed under the normal application directory and a symlink is created in:

```text
~/.local/bin/
```

For example:

```bash
tar-install --cli lazydocker_0.25.2_Linux_x86_64.tar.gz
```

will make:

```bash
lazydocker
```

available from any directory.

Check the command with:

```bash
which lazydocker
```

## Custom CLI command name

The archive name and executable name do not need to match.

You can explicitly specify the command name:

```bash
tar-install --cli mycommand application.tar.gz
```

The resulting command will be:

```bash
mycommand
```

## Archives with their own installer

Some applications include their own installer, such as:

```text
install.sh
setup.sh
install
setup
```

`tar-install` detects these before proceeding.

You'll be told that the archive contains an installer and given the option to abort.

For example:

```text
This archive contains an installer script:
  App/install.sh

You can abort now and install this application manually
using its provided installer.

Continue with automatic installation? [y/N]
```

Choosing `N` stops the automatic installation and leaves the extracted files available so you can use the application's own installer.

Choosing `Y` continues with `tar-install`'s automatic installation.

## Multiple executables

Some archives contain several executables:

```text
MyApp/
├── MyApp
├── helper
├── crashpad_handler
└── updater
```

When `tar-install` cannot determine the main application automatically, it presents the candidates and asks you to select one.

This avoids silently choosing the wrong executable.

## Application icons

`tar-install` attempts to find an icon automatically.

The general priority is:

1. Icon referenced by an included `.desktop` file
2. Image files included in the application
3. Generic `application-x-executable` icon

Supported image formats include common formats such as:

```text
.png
.svg
.xpm
```

An application does not need to contain an icon to be installed.

## Managing installed applications

List applications installed through `tar-install`:

```bash
tar-install list
```

Example:

```text
lazydocker                 [CLI]      lazydocker
some-gui-app                          Some GUI App
```

Remove an application:

```bash
tar-install remove lazydocker
```

or:

```bash
tar-install uninstall lazydocker
```

Removal deletes:

* The application's installation directory
* Its `.desktop` launcher, if applicable
* Its CLI symlink, if applicable
* `tar-install`'s metadata for the application

## Where applications are installed

Applications are stored in:

```text
~/.local/share/tar-install/apps/
```

Metadata is stored in:

```text
~/.local/share/tar-install/metadata/
```

CLI symlinks are stored in:

```text
~/.local/bin/
```

GUI launchers are stored in:

```text
~/.local/share/applications/
```

Everything is user-local. `tar-install` does not install applications into `/usr`, `/opt`, or other system directories.

## Usage

```text
tar-install <archive>
tar-install --cli <archive>
tar-install --cli <command-name> <archive>

tar-install list
tar-install remove <app>
tar-install uninstall <app>
tar-install help
```

### Examples

Install a GUI application:

```bash
tar-install Firefox.tar.gz
```

Install a CLI application:

```bash
tar-install --cli lazydocker.tar.gz
```

Install a CLI application with a custom command:

```bash
tar-install --cli docker-tui docker-tui.tar.gz
```

List installed applications:

```bash
tar-install list
```

Remove an application:

```bash
tar-install remove docker-tui
```

## Requirements

`tar-install` requires a standard Linux environment with:

* Bash
* `tar`
* `find`
* `grep`
* `cp`
* `ln`

For `.zip` archives:

* `unzip`

For `.tar.zst` archives:

* `tar` with Zstandard support

No additional runtime or package manager is required.

## Design

`tar-install` intentionally does not try to become a replacement for `apt`, `dnf`, or another system package manager.

It is intended for applications distributed as portable archives where the developer provides an executable rather than a native Linux package.

The application remains isolated in:

```text
~/.local/share/tar-install/apps/
```

while standard XDG locations are used for integration with the desktop environment.

This makes applications easy to install, remove, and keep separate from system-managed software.

## Limitations

`tar-install` cannot guarantee that every arbitrary archive is installable.

Some applications:

* Require additional system dependencies
* Require special environment variables
* Need system-wide libraries
* Expect to be installed in a specific location
* Require their own installer
* Use unusual executable layouts

When an archive contains its own installer, `tar-install` gives you the option to use it instead.

## License

MIT License. See [LICENSE.md](./LICENSE.md).
