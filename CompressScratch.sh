#!/bin/bash
set -e # fail on error
cd /mnt/rundata/scratch
# silently compress, use logfile to watch progress
CompressAndCheck.sh --ignorenewest 1 --delete 1 --worker 5 start >/dev/null 2>&1
# after compression, move the 
# compressed files to the production folder
BEAMTIME=2014-07_EPT_Prod
mkdir -p ../$BEAMTIME
cp MD5SUM ../$BEAMTIME
mv -n *.dat.xz ../$BEAMTIME
