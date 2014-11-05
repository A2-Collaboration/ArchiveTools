#!/bin/bash

# written by A.Neiser, neiser@kph.uni-mainz.de

set -e # fail on error

LOCKFILE=.lock-CompressAndCheck.sh

# default options
DELETE=0
WORKER=4
IGNORENEWEST=0
TOSYSLOG=0

while :
do
    case $1 in
        --delete)
            DELETE=$2
            shift 2
            ;;
	      --ignorenewest)
            IGNORENEWEST=$2
            shift 2
            ;;
	      --syslog)
            TOSYSLOG=$2
            shift 2
            ;;
        --worker)
            WORKER=$2
            shift 2
            ;;
        --) # End of all options
            shift
            break
            ;;
        *)  # no more options. Stop while loop
            break
            ;;
    esac
done

STARTDATE=$(date +%F-%R:%S)

function echo_log {
    if [[ $TOSYSLOG = 1 ]]; then
	      echo $1 | logger -t "CompressAndCheck.sh"
    else
	      echo $1 >> $(basename $0)-$STARTDATE.log
    fi    
}

function error_exit {
    ERRMSG="Error: $1"
    echo $ERRMSG
    echo_log $ERRMSG
    exit 1
}


function start {   
    # gather some infos...
    TOTALSIZE_G=$(du --apparent-size -B G -c *.dat | grep total | cut -f1)
    TOTALSIZE=$(du --apparent-size -b -c *.dat | grep total | cut -f1)
    
    if [[ $IGNORENEWEST = 1 ]]; then
        NEWESTFILE=$(ls -1rt *.dat | tail -1)
	      GREP_CMD="grep -v $NEWESTFILE"
    else
	      GREP_CMD="cat"
    fi

    echo_log "Starting compression..."

    # do the jobs, pass some arguments
    find . -name '*.dat' -type f | $GREP_CMD | \
        xargs -n1 -P$WORKER $0 --delete $DELETE --syslog $TOSYSLOG start_wrapper $STARTDATE

    # gather some more infos and print summary to log
    if [[ $TOSYSLOG = 1 ]]; then
	      SUCCESS="Unknown"
	      ERROR="Unknown"
    else
	      SUCCESS=$(grep SUCCESS $(basename $0)-$STARTDATE.log | wc -l)
	      ERROR=$(grep ERROR $(basename $0)-$STARTDATE.log | wc -l)
    fi
    TOTALSIZE_XZ_G=$(du --apparent-size -B G -c *.dat.xz | grep total | cut -f1 || echo 0) 
    TOTALSIZE_XZ=$(du --apparent-size -b -c *.dat.xz | grep total | cut -f1 || echo 0)
    echo_log "Finished compression of $TOTALSIZE_G to $TOTALSIZE_XZ_G"
    echo_log "Ratio: $(echo "$TOTALSIZE_XZ/$TOTALSIZE" | bc -l)"
    echo_log "Errors: $ERROR, Successful: $SUCCESS"
}

function start_wrapper {
    STARTDATE=$1
    FILE=$(basename $2)
    FILEXZ=$FILE.xz

    # skip if already there
    if [ -s $FILEXZ ] ; then
        echo_log "$FILE: $FILEXZ already exists, SUCCESS."
        return
    fi
    FILESIZE=$(stat -c %s $FILE)

    # hash and compress
    echo_log "$FILE: md5sum'ing and xz'ing '$FILE', size=$FILESIZE..."
    trap "rm -f $FILEXZ" INT TERM # cleanup if interrupted
    MD5SUM=$(cat $FILE | pv -s $FILESIZE -cN $FILE | \
        tee >(xz -4 > $FILEXZ) \
        | md5sum | cut -d' ' -f1)
    echo_log "$FILE: md5sum of input file $FILE: $MD5SUM"

    # print newline to make pv output a little better...
    echo ""
    
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
    cat $FILE.MD5SUM >> MD5SUM
    rm -f $FILE.MD5SUM
    if [[ $DELETE = 1 ]]; then
	      echo_log "$FILE: rm'ing $FILE"
        rm -f $FILE
    fi
    echo_log "$FILE: SUCCESS"
    # print newline to make pv output a little better...
    echo ""
}

# Then, what to do finally?
case $1 in
    start)
        {
            flock -n 9 || error_exit "Cannot acquire lock, exiting."
            start "${@:2}"
        } 9>$LOCKFILE
        ;;
    start_wrapper)
        start_wrapper "${@:2}"
        ;;
    *)
        echo "Usage: $0 [--syslog 0] [--delete 0] [--worker 4] [--ignorenewest 0] start"
        exit 255
        ;;
esac

exit 0;


