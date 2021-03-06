#!/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin:/opt/ArchiveTools
set -e # fail on error
cd /mnt/storage1/scratch
# silently compress, use logfile to watch progress
CompressAndCheck.sh --ignorenewest 1 --syslog 1 --delete 1 --worker 5 start >/dev/null 2>&1
# after compression, move the
# compressed files to the production folder
BEAMTIME=2017-12_Compton
mkdir -p ../$BEAMTIME
cp MD5SUM ../$BEAMTIME
mv -n *.dat.xz ../$BEAMTIME
