#!/bin/bash

###############################################################################
# fork of https://github.com/K-ratos/wallee
###############################################################################
#
# This script will repeatedly see all image files, pick one at random, and
# avoid repetition
#
# USAGE: wallee.sh [wallpaper_dir] [interval_seconds] [memory_size]
#
# [wallpaper_dir]: a directory with image files in it
# [interval_seconds]: how many seconds before switching to another wallpaper
# [memory_size]: how many wallpapers will be kept tabs on
#
# TODO
# - read default configuration from within $XDG_CONFIG_HOME
#
###############################################################################

# this outer construct explained in https://stackoverflow.com/a/169969
(

    # if possible, remove the lockfile when finished
    trap "rm /var/lock/wallee.lock; exit $?" INT
    trap "rm /var/lock/wallee.lock; exit $?" TERM

    # wait up to 10 seconds for the lockfile to be released
    flock -x -w 10 200 || exit 1

    # and so it begins
    DEFAULT_WALLPAPERS="$HOME/pictures/wallpapers"
    DEFAULT_TIME_MINUTES=5
    DEFAULT_TRACKED_WALLPAPERS_AMOUNT=5

    image_regex='^.*\.(jpe?g|png)$'
    wallpapers=$DEFAULT_WALLPAPERS
    time_interval_seconds=$((DEFAULT_TIME_MINUTES * 60))
    total_tracked_wallpapers=$DEFAULT_TRACKED_WALLPAPERS_AMOUNT
    how_many_recent_wallpapers=0

    # accept valid options, otherwise skip them
    if [ -n "$1" ]
    then
        wallpapers="$1"
    fi
    if [ -n "$2" ] && [[ "$2" =~ ^[0-9]{1,2}$ ]] && [ $2 -gt 0 ]
    then
        time_interval_seconds=$2
    fi
    if [ -n "$3" ] && [[ "$3" =~ ^[0-9]{1,2}$ ]] && [ $3 -ge 0 ]
    then
        total_tracked_wallpapers=$3
    fi

    # this array will keep tabs on recent wallpapers
    declare -a recent_wallpapers

    # main loop
    while true
    do
        # cache all image files in directory
        # this might be expensive but it works pretty good for this purpose
        files=$(find "$wallpapers" -maxdepth 1 -type f -regextype egrep -regex $image_regex -printf '%f\n')

        # are there actually any image files in the directory?
        file_count=$(echo "$files" | wc -l)
        if [ $file_count = 0 ]
        then
            echo "No image files found in $wallpapers"
            sleep $time_interval_seconds
            continue # don't hurry to kill the script if not
        fi

        # pick a random wallpaper
        random_index=$((1 + ($RANDOM % $file_count)))
        random_file=$(echo "$files" | head -"$random_index" | tail -1)

        # was this wallpaper picked too recently? if so, try again
        if [ $how_many_recent_wallpapers -gt 0 ]
        then
            compare_i=1
            while [ $compare_i -le $how_many_recent_wallpapers ]
            do
                this_wallpaper=${recent_wallpapers[$compare_i]}
                (( compare_i++ ))
                if [ "$random_file" = "$this_wallpaper" ]
                then
                    continue 2
                fi
            done
        fi

        # remember the most recent wallpapers
        if [ $how_many_recent_wallpapers -lt $total_tracked_wallpapers ]
        then
            # push all until the array is filled
            (( how_many_recent_wallpapers++ ))
            recent_wallpapers[$how_many_recent_wallpapers]="$random_file"
        else
            # then keep track "first-in, last-out"-style
            remember_i=$total_tracked_wallpapers
            while [ $remember_i -gt 0 ]
            do
                remember_next=$(( remember_i - 1 ))
                recent_wallpapers[$remember_i]=${recent_wallpapers[$remember_next]}
                (( remember_i-- ))
            done
            recent_wallpapers[1]="$random_file"
        fi

        # actually set the wallpaper and wait some time before going at it again
        feh --no-fehbg --bg-fill "$wallpapers/$random_file"
        sleep $time_interval_seconds
    done

) 200>/var/lock/wallee.lock
