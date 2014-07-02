#!/bin/bash

# written by A.Neiser, neiser@kph.uni-mainz.de

set -e # fail on error

function start {
    RUNDATADIR=$1
    EXTENSION=$2
    
    if [[ ! -d $RUNDATADIR ]]; then
        echo "Please provide rundata folder as argument"
        exit 1
    fi

    if [[ "x$EXTENSION" = "x" ]]; then
        EXTENSION='*.dat.xz'
    fi
   
    find $RUNDATADIR -name $EXTENSION  -type f -print0 | \
        xargs -0 -n1 -P4 $0 start_wrapper

    echo "Generation of Metadata finished"
}

function start_wrapper {
    FILE=$1
    echo "Working on $FILE..."
    # try AcquHead (thru wrapper)
    METADATA_ARGS=$(AcquHead-wrapper.pl $FILE)

    # call Distler's script
    eval "genxml.py $METADATA_ARGS \
        --committer 'Andreas Neiser <neiser@kph.uni-mainz.de>' \
        --user neiser --group kpha2 --uid 1342 --gid 4520 \
        --nochecksums --nocompression --noinflate -- \
        $FILE"
}

# Then, what to do finally?
case $1 in
    start)
        start "${@:2}"
        ;;
    start_wrapper)
        start_wrapper "${@:2}"
        ;;    
    *)
        echo "Usage: $0 start <RunDataDir> ['*.dat.xz']"
        exit 255
        ;;
esac

exit 0;
