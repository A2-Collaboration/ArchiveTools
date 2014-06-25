#!/bin/bash

# written by A.Neiser, neiser@kph.uni-mainz.de

set -e # fail on error


function echo_log {
    echo $1 >> $(basename $0)-$STARTDATE.log
}

function start {
    STARTDATE=$(date +%F-%R:%S)
    ls *.dat | xargs -n1 -P2 $0 start_wrapper $STARTDATE    
}

function start_wrapper {
    STARTDATE=$1
    FILE=$2
    FILEXZ=$FILE.xz

    # skip if already there
    if [ -s $FILEXZ ] ; then
        echo_log "$FILE: $FILEXZ already exists, skipping."
        return
    fi
    FILESIZE=$(stat -c %s $FILE)

    # hash and compress
    echo_log "$FILE: md5sum'ing and xz'ing '$FILE', size=$FILESIZE..."
    MD5SUM=$(cat $FILE | pv -s $FILESIZE -cN $FILE | \
        tee >(xz -4 > $FILEXZ) \
        | md5sum | cut -d' ' -f1)
    echo_log "$FILE: md5sum of input file $FILE: $MD5SUM"

    # destroy data for test cases
    #cp test2.dat.xz test1.dat.xz
    #dd if=/dev/urandom of=test1.dat.xz bs=4M count=1
    
    # uncompress and check, write
    echo_log "$FILE: md5sum'ing and unxz'ing '$FILEXZ'..."
    FILESIZEXZ=$(stat -c %s $FILE)
    MD5SUM_CHECK=$(cat $FILEXZ | pv -s $FILESIZE -cN $FILEXZ | \
        tee >(md5sum | sed s/-/$FILEXZ/ > $FILE.MD5SUM) | \
        xzcat | md5sum | cut -d' ' -f1)
    echo_log "$FILE: md5sum of uncompressed file $FILEXZ: $MD5SUM_CHECK"
    if [ "x$MD5SUM" != "x$MD5SUM_CHECK" ]; then
        rm -f $FILE.MD5SUM
        echo "$FILE: ERROR: MD5SUMs don't match..."
        exit 1
    fi
    # after successful check, add the MD5SUM and remove the original
    echo_log "$FILE: rm'ing $FILE"
    cat $FILE.MD5SUM >> MD5SUM
    rm -f $FILE.MD5SUM
    #rm -f $FILE 
    echo_log "$FILE: SUCCESS"
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


