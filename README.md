# Wallee

Wallee was a straightforward script that automatically changed wallpaper using
`feh` indefinitely within a certain time interval from a certain folder.
It also switched wallpapers in alphabetic order from their filenames.
This fork is a heavy rewrite of that script.

Most desktop environments do not even need a script to switch wallpapers.
This is instead meant to be used under the i3 window manager.

# Features

Differing from the original `wallee` script:

- Pick wallpapers in a random order
- Remember recent wallpapers to avoid repitition
- Support content changes in the wallpapers folder
  - No need to restart the script to add or change wallpapers
- Command-line parameters for
  - Wallpapers folder
  - Time interval to switch, in seconds
  - How many wallpapers to remember

# Requirements

Only the Bash shell is currently supported.
It might or might not work in other shells.

Make sure to install `feh` as well.

# Usage

`wallee.sh [dir] [interval] [memory_size]`

- _dir_: a directory with image files in it
    - default: `~/pictures/wallpapers`
- _interval_: how many **seconds** before switching to another wallpaper
    - default: 300
- _memory_size_: how many wallpapers will be kept tabs on
    - default: 5

# Installation

Put this script somewhere in your system, and if you're using `i3`, add this
line to your `$XDG_CONFIG_HOME/i3/config` file:

`exec_always /path/to/wallee.sh [dir] [interval] [memory_size]`

# TODO

Some additional features might be added in the future:

- Set order of wallpapers (random, alphabetic, alphabetic-reverse)
- Read default configuration from a file in `$XDG_CONFIG_HOME`
