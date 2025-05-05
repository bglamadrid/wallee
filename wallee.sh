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

if [ -f '/var/lock/wallee.lock' ]
then
    exit
fi

_log() {
    echo "[wallee.sh] $1"
}

# this outer construct explained in https://stackoverflow.com/a/169969
(

    # if possible, remove the lockfile when finished
    trap "rm /var/lock/wallee.lock; exit $?" INT
    trap "rm /var/lock/wallee.lock; exit $?" TERM

    # wait up to 10 seconds for the lockfile to be released
    flock -x -w 10 200 || exit 1

    # and so it begins
    DEFAULT_MAX_TRACKED_WALLPAPERS=-1
    DEFAULT_STATE_DIR="$HOME/.local/share/wallee"

    walls_full_index_filepath="$DEFAULT_STATE_DIR/full_index"
    available_walls_index_filepath="$DEFAULT_STATE_DIR/available"
    recent_walls_index_filepath="$DEFAULT_STATE_DIR/recent"
    image_regex='^.*\.(jpe?g|png)$'

    declare -a recent_wallpapers
    how_many_recent_wallpapers=0
    available_wallpaper_file_count=0
    verbose=0
    reset=0

    # these we should read from XDG_CONFIG
    wallpapers_directory=
    time_interval_seconds=
    max_tracked_wallpapers=

    ### parsing parameters ###
    arg_i=0
    longarg=
    shortarg=
    for arg in "$@"; do
        (( arg_i++ ));
        if [ -z "$arg" ]; then continue; fi
        if [ $verbose -eq 1 ]; then _log "arg=$arg"; fi
        if [ "$arg" = '-r' ] || [ "$arg" = '--reset' ];
        then
            reset=1
            continue
        fi
        if [ "$arg" = '-v' ] || [ "$arg" = '--verbose' ]
        then
            verbose=1
            _log "== VERBOSE MODE =="
            continue
        fi
        if [ "$arg" = '-h' ] || [ "$arg" = '--help' ]; then print_usage_help; exit; fi
        longarg="$(echo "$arg" | sed -E 's/^--([a-z]{4,})=.+$/\1/; t; Q; p')"
        if [ -n "$longarg" ]
        then
            longval="$(echo "$arg" | sed -E 's/^--'"$longarg"'=(.+)$/\1/; t; Q; p')"
            if [ $verbose -eq 1 ]
            then
                _log "longarg=$longarg"
                _log "longval=$longval"
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
                _log 'ERROR: Parameter order is wrong.'
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
                _log "shortarg=$shortarg"
                _log "value=$arg"
            fi
            shortarg=
        fi
    done

    ### debug options ###
    if [ $verbose -eq 1 ]
    then
        _log "wallpapers_directory=$wallpapers_directory"
        _log "time_interval_seconds=$time_interval_seconds"
        _log "max_tracked_wallpapers=$max_tracked_wallpapers"
    fi

    ### safeguarding initial program states ###
    if [ ! -d "$DEFAULT_STATE_DIR" ]
    then
        mkdir -p "$DEFAULT_STATE_DIR"
    fi

    if [ ! -f "$walls_full_index_filepath" ] || [ ! -s "$walls_full_index_filepath" ] || \
       [ ! -f "$available_walls_index_filepath" ] || \
       [ ! -f "$recent_walls_index_filepath" ] || \
       [ $reset -eq 1 ]
    then
        if [ $verbose -eq 1 ]; then _log 'Creating new cache files'; fi
        touch "$walls_full_index_filepath" \
              "$available_walls_index_filepath" \
              "$recent_walls_index_filepath"
        # cache all image files in wallpapers directory
        find "$wallpapers_directory" -maxdepth 1 \
                           -type f,l \
                           -regextype egrep \
                           -regex $image_regex \
                           -printf '%f\n' > "$walls_full_index_filepath"
        if [ $verbose -eq 1 ]; then _log "Found $(cat "$walls_full_index_filepath" | wc -l) wallpaper files"; fi
        cp "$walls_full_index_filepath" "$available_walls_index_filepath"
        cp /dev/null "$recent_walls_index_filepath"
    fi

    ### main loop ###
    while true
    do
        # are there actually any image files to use?
        available_wallpaper_file_count=$(cat "$available_walls_index_filepath" | wc -l)
        if [ $verbose -eq 1 ]; then _log "There are $available_wallpaper_file_count wallpapers available to select"; fi
        if [ $available_wallpaper_file_count -eq 0 ]
        then
            cp "$walls_full_index_filepath" "$available_walls_index_filepath"
            cp /dev/null "$recent_walls_index_filepath"
            continue
        fi

        mapfile -t $recent_wallpapers < "$recent_walls_index_filepath"
        how_many_recent_wallpapers=${#recent_wallpapers[@]}
        if [ $verbose -eq 1 ]; then _log "In recent memory, $how_many_recent_wallpapers wallpapers have been used"; fi

        # pick a random wallpaper
        random_index=$((1 + ($RANDOM % $available_wallpaper_file_count)))
        random_file="$(cat "$available_walls_index_filepath" | head -"$random_index" | tail -1)"
        if [ $verbose -eq 1 ]; then _log "Picked file no. $random_index from available list: $random_file"; fi
        if [ ! -f "$wallpapers_directory/$random_file" ]
        then
            _log "Resetting caches because this wallpaper file does not exist: $random_file"
            find "$wallpapers_directory" -maxdepth 1 \
                               -type f,l \
                               -regextype egrep \
                               -regex $image_regex \
                               -printf '%f\n' > "$walls_full_index_filepath"
            if [ $verbose -eq 1 ]; then _log "Found $(cat "$walls_full_index_filepath" | wc -l) wallpaper files"; fi
            cp "$walls_full_index_filepath" "$available_walls_index_filepath"
            cp /dev/null "$recent_walls_index_filepath"
            continue
        fi

        if [ $max_tracked_wallpapers -le -1 ]
        # remember as many wallpapers as there are
        then
            if [ $how_many_recent_wallpapers -ge $available_wallpaper_file_count ]
            # when there be more wallpapers in memory than in the directory
            then
                cp "$walls_full_index_filepath" "$available_walls_index_filepath"
                cp /dev/null "$recent_walls_index_filepath"
            fi
            sed -i $random_index'd' "$available_walls_index_filepath"
            printf "$random_file\n" >> "$recent_walls_index_filepath"
        else
            if [ $how_many_recent_wallpapers -lt $max_tracked_wallpapers ]
            then
                printf "$random_file\n" >> "$recent_walls_index_filepath"
            else
                # when max amount of tracked wallpapers has been reached,
                # keep track FILO-style
                remember_i=$max_tracked_wallpapers
                while [ $remember_i -gt 0 ]
                do
                    remember_next=$(( remember_i - 1 ))
                    recent_wallpapers[$remember_i]="${recent_wallpapers[$remember_next]}"
                    (( remember_i-- ))
                done
                recent_wallpapers[1]="$random_file"
                printf "%s\n" "${recent_wallpapers[@]}" > "$recent_walls_index_filepath"
            fi
        fi

        # actually set the wallpaper and wait some time before going at it again
        feh --no-fehbg --bg-fill "$wallpapers_directory/$random_file"
        sleep $time_interval_seconds
    done

) 200>/var/lock/wallee.lock
