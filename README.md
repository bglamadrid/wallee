# Wallee

Wallee was a straightforward script that automatically changed wallpaper using
`feh` indefinitely within a certain time interval from a certain folder.
It also switched wallpapers in alphabetic order from their filenames.
This fork is a heavy rewrite of that script.

Most desktop environments (GNOME, KDE, Xfce, Cinnamon, MATE, etc) do not even
need a script to switch wallpapers.
Instead, this script is meant to be used under the i3 window manager.

## Features

Differing from the original `wallee` script:

- Pick wallpapers in a random order
- Remember recent wallpapers to avoid repetition
- Support dynamic filelist (no need to restart the script to add or change
  wallpapers to the rotation)
  - Three files are created in `~/.local/share/wallee/` to handle the index
    of wallpaper files `full_index`, `available` and `recent`
- Shell-like command-line parameters

## Requirements

- Only the Bash shell is currently supported.
  It might or might not work in other shells.
- `feh` (or an equivalent program, but then you'll have to edit the script to
  use that)

## Usage

### Syntax

```bash
wallee.sh [options]
```

### Required options

Option                       | Description
-----------------------------|-------------
`-d {}` or `--directory={}`  | The directory with image files to be used as wallpapers.
`-n {}` or `--interval={}`   | How many seconds must pass before changing wallpapers.
`-s {}` or `--memorysize={}` | How many recent wallpapers must be remembered. **If set to a natural number**: the script will check the entire directory on each interval and try to choose any file that is different from the latest "s" picks. **If set to -1**: the script will cycle through every single image file found in the directory.

### Other options

Option              | Description
--------------------|-------------
`-h` or `--help`    | Show this usage help in the CLI.
`-r` or `--reset`   | Erase indexes, start memorizing wallpapers all over again.
`-v` or `--verbose` | Explain everything that happens until an error or the `--help` option is found.

## Installation

Put this script somewhere in your system, and if you're using `i3`, add this
line to your `$XDG_CONFIG_HOME/i3/config` file:

```
exec_always /path/to/wallee.sh --directory=[dir] --interval=[interval] --memory-size=[memory_size]
```

## TODO

Some additional features might be added in the future:

- Set order of wallpapers (random, alphabetic, alphabetic-reverse)
- Read default configuration from a file in `$XDG_CONFIG_HOME`
