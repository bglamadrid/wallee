#!/bin/bash

print_usage_help() {
    echo 'Fork of https://github.com/K-ratos/wallee'
    echo 'This script will change the desktop wallpaper by randomly picking an image file'
    echo 'from a directory. The randomness can be configured by setting a memory size.'
    echo
    echo 'Usage:'
    echo 'wallee.sh [options]'
    echo
    echo 'Required options:'
    echo '    -d {}, --directory={}   The directory with image files to be used as'
    echo '                            wallpapers.'
    echo '    -n {}, --interval={}    How many seconds must pass before changing'
    echo '                            wallpapers.'
    echo '    -s {}, --memorysize={}  How many recent wallpapers must be remembered.'
    echo '                            If set to a natural number, the script will check.'
    echo '                            the entire directory on each interval and try to'
    echo '                            choose any file that is different from the latest'
    echo '                            "s" picks.'
    echo '                            If set to -1, the script will cycle through every.'
    echo '                            single image file found in the directory.'
    echo
    echo 'Other options:'
    echo '    -h, --help     Show this usage help.'
    echo '    -r, --reset    Erase indexes, start memorizing wallpapers all over again.'
    echo '    -v, --verbose  Explain everything that happens until an error or the --help'
    echo '                   option is found.'
}

if [ $# -lt 1 ]; then
    echo 'ERROR: Not enough parameters.'
    exit 1
fi

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
    DEFAULT_MAX_TRACKED_WALLPAPERS=-1
    DEFAULT_STATE_DIR="$HOME/.local/share/wallee"
    FULL_INDEX_FILE="$DEFAULT_STATE_DIR/full_index"
    AVAILABLE_INDEX_FILE="$DEFAULT_STATE_DIR/available"
    RECENTLY_USED_INDEX_FILE="$DEFAULT_STATE_DIR/recent"

    image_regex='^.*\.(jpe?g|png)$'
    wallpapers_directory="$DEFAULT_WALLPAPERS"
    time_interval_seconds=$((DEFAULT_TIME_MINUTES * 60))
    max_tracked_wallpapers=$DEFAULT_MAX_TRACKED_WALLPAPERS
    how_many_recent_wallpapers=0
    available_wallpaper_file_count=0
    verbose=0
    reset=0

    # parse program options
    arg_i=0
    shortarg=
    for arg in "$@"; do
        (( arg_i++ ));
        if [ -z "$arg" ]; then continue; fi
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] arg=$arg"; fi
        if [ "$arg" = '-r' ] || [ "$arg" = '--reset' ];
        then
            reset=1
            continue
        fi
        if [ "$arg" = '-v' ] || [ "$arg" = '--verbose' ]
        then
            verbose=1
            echo "[wallee.sh] == VERBOSE MODE =="
            continue
        fi
        if [ "$arg" = '-h' ] || [ "$arg" = '--help' ]; then print_usage_help; exit; fi
        longarg=$(echo "$arg" | sed -E 's/^--([a-z]{4,})=.+$/\1/; t; Q; p')
        if [ -n "$longarg" ]
        then
            longval=$(echo "$arg" | sed -E 's/^--'"$longarg"'=(.+)$/\1/; t; Q; p')
            if [ $verbose -eq 1 ]
            then
                echo "[wallee.sh] longarg=$longarg"
                echo "[wallee.sh] longval=$longval"
            fi
            case "$longarg" in
            directory)
                wallpapers_directory="$longval"
                ;;
            interval)
                time_interval_seconds=$longval
                ;;
            memorysize)
                max_tracked_wallpapers=$longval
                ;;
            esac
            longarg=
            continue
        elif [ -z "$shortarg" ]
        then
            shortarg="$(echo "$arg" | sed -E 's/^-(.)$/\1/; t; Q; p')"
            if [ -z "$shortarg" ]
            then
                echo '[wallee.sh] ERROR: Parameter order is wrong.'
                exit 1
            fi
            continue
        else
            case "$shortarg" in
            d)
                wallpapers_directory="$arg"
                ;;
            n)
                time_interval_seconds=$arg
                ;;
            s)
                max_tracked_wallpapers=$arg
                ;;
            esac
            if [ $verbose -eq 1 ]
            then
                echo "[wallee.sh] shortarg=$shortarg"
                echo "[wallee.sh] value=$arg"
            fi
            shortarg=
        fi
    done

    # debug options
    if [ $verbose -eq 1 ]
    then
        echo "[wallee.sh] wallpapers_directory=$wallpapers_directory"
        echo "[wallee.sh] time_interval_seconds=$time_interval_seconds"
        echo "[wallee.sh] max_tracked_wallpapers=$max_tracked_wallpapers"
    fi

    if [ ! -d "$DEFAULT_STATE_DIR" ]
    then
        mkdir -p "$DEFAULT_STATE_DIR"
    fi

    if [ ! -f "$FULL_INDEX_FILE" ] || [ ! -s "$FULL_INDEX_FILE" ] || \
       [ ! -f "$AVAILABLE_INDEX_FILE" ] || \
       [ ! -f "$RECENTLY_USED_INDEX_FILE" ] || \
       [ $reset -eq 1 ]
    then
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] Creating new cache files"; fi
        touch "$FULL_INDEX_FILE" \
              "$AVAILABLE_INDEX_FILE" \
              "$RECENTLY_USED_INDEX_FILE"
        # cache all image files in wallpapers directory
        find "$wallpapers_directory" -maxdepth 1 \
                           -type f,l \
                           -regextype egrep \
                           -regex $image_regex \
                           -printf '%f\n' > "$FULL_INDEX_FILE"
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] Found $(cat "$FULL_INDEX_FILE" | wc -l) wallpaper files"; fi
        cp "$FULL_INDEX_FILE" "$AVAILABLE_INDEX_FILE"
        cp /dev/null "$RECENTLY_USED_INDEX_FILE"
    fi

    # this array will keep tabs on recent wallpapers
    declare -a recent_wallpapers

    # main loop
    while true
    do
        # are there actually any image files to use?
        available_wallpaper_file_count=$(cat "$AVAILABLE_INDEX_FILE" | wc -l)
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] There are $available_wallpaper_file_count wallpapers available to select"; fi
        if [ $available_wallpaper_file_count -eq 0 ]
        then
            cp "$FULL_INDEX_FILE" "$AVAILABLE_INDEX_FILE"
            cp /dev/null "$RECENTLY_USED_INDEX_FILE"
            continue
        fi

        mapfile -t $recent_wallpapers < "$RECENTLY_USED_INDEX_FILE"
        how_many_recent_wallpapers=${#recent_wallpapers[@]}
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] In recent memory, $how_many_recent_wallpapers wallpapers have been used"; fi

        # pick a random wallpaper
        random_index=$((1 + ($RANDOM % $available_wallpaper_file_count)))
        random_file="$(cat "$AVAILABLE_INDEX_FILE" | head -"$random_index" | tail -1)"
        if [ $verbose -eq 1 ]; then echo "[wallee.sh] Picked file no. $random_index from available list: $random_file"; fi

        if [ $max_tracked_wallpapers -le -1 ]
        # remember as many wallpapers as there are
        then
            if [ $how_many_recent_wallpapers -ge $available_wallpaper_file_count ]
            # when there be more wallpapers in memory than in the directory
            then
                cp "$FULL_INDEX_FILE" "$AVAILABLE_INDEX_FILE"
                cp /dev/null "$RECENTLY_USED_INDEX_FILE"
            fi
            sed -i $random_index'd' "$AVAILABLE_INDEX_FILE"
            printf "$random_file\n" >> "$RECENTLY_USED_INDEX_FILE"
        else
            if [ $how_many_recent_wallpapers -lt $max_tracked_wallpapers ]
            then
                printf "$random_file\n" >> "$RECENTLY_USED_INDEX_FILE"
            else
                # when max amount of tracked wallpapers has been reached,
                # keep track FILO-style
                remember_i=$max_tracked_wallpapers
                while [ $remember_i -gt 0 ]
                do
                    remember_next=$(( remember_i - 1 ))
                    recent_wallpapers[$remember_i]=${recent_wallpapers[$remember_next]}
                    (( remember_i-- ))
                done
                recent_wallpapers[1]="$random_file"
                printf "%s\n" "${recent_wallpapers[@]}" > "$RECENTLY_USED_INDEX_FILE"
            fi
        fi

        # actually set the wallpaper and wait some time before going at it again
        feh --no-fehbg --bg-fill "$wallpapers_directory/$random_file"
        sleep $time_interval_seconds
    done

) 200>/var/lock/wallee.lock
