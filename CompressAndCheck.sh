#!/bin/bash

# written by A.Neiser, neiser@kph.uni-mainz.de

set -e # fail on error


function start {
    FILES=$(ls *.dat)
    echo $FILES
}

function start_wrapper {
    FILE=$1
    FILEXZ=$FILE.xz

    # skip if already there
    if [ -s $FILEXZ ] ; then
        echo "$FILEXZ already exists, skipping."
        return
    fi
    FILESIZE=$(stat -c %s $FILE)

    # hash and compress
    echo "md5sum'ing and xz'ing '$FILE', size=$FILESIZE..."
    MD5SUM=$(cat $FILE | pv -s $FILESIZE | \
        tee >(xz -4 > $FILEXZ) \
        | md5sum | cut -d' ' -f1)
    echo "md5sum of input file: $MD5SUM"

    #cp test2.dat.xz test1.dat.xz
    
    # uncompress and check, write
    echo "md5sum'ing and unxz'ing '$FILEXZ'..."
    MD5SUM_CHECK=$(cat $FILEXZ | \
        tee >(md5sum | sed s/-/$FILEXZ/ >> MD5SUM) | \
        xzcat | md5sum | cut -d' ' -f1)
    echo "md5sum of uncompressed file: $MD5SUM_CHECK"
    if [ "x$MD5SUM" != "x$MD5SUM_CHECK" ]; then
        echo "ERROR $FILE: MD5SUMs don't match."
        exit 1
    fi
    echo "rm'ing $FILE"
    
    echo "SUCCESS $FILE"
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
        echo "Usage: $0 start"
        exit 255
        ;;
esac

exit 0;


