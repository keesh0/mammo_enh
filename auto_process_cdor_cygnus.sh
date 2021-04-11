#!/bin/bash

##################################################
# Run Cd'or on each analysis study on Linux Ubuntu (Cygnus)
# 1. Fixup cd-cem.cfg to use Linux path separator /
# 2. Run Cd'or based on each cd-cem.cfg file.
# 3. Rename each Pre-Post-FollowuppdmAllHistograms_LogTen_AsSlice_Final_.nii file as per each cd-cem.cfg file.
#
# Run from a folder with folders called analysis-162-1616461963445.
##################################################
#Bash handling
##################################################
set -o errexit
set -o pipefail
set -o nounset

# find /home/m008480 -maxdepth 1 -name 'cava_*' -type f -print  #or -print0

# Cd'or exe on Cygnus after munging cfg files run on Windows
find -maxdepth 4 -name 'cd-cem.cfg'  -type f -exec sed -i 's/\\/\//g' {} \;

CD_CEM_CFGS=(`find -maxdepth 4 -name 'cd-cem.cfg' -type f -print`)
#./ChangeDetector \
#CFGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/cd-cem.cfg \
#LOGLEVEL=TRACE \
#LOGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/logs/logfile.txt
for i in "${!CD_CEM_CFGS[@]}"
do
    # TODO-- make log dir
    LOGFILE="$(dirname ${CD_CEM_CFGS[$i]})/logs/logfile.txt"
    echo "./ChangeDetector ${CD_CEM_CFGS[$i]} LOGLEVEL=TRACE LOFILE=$LOGFILE"
done


#./ChangeDetector \
#CFGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/cd-cem.cfg \
#LOGLEVEL=TRACE \
#LOGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/logs/logfile.txt


SOURCE_ARRAY=()
DEST_ARRAY=()
for i in "${!SOURCE_ARRAY[@]}"
do
    echo "${DEST_ARRAY[$i]}"
    if [[ -f ${SOURCE_ARRAY[$i]} ]]; then
        TEMP="$(md5sum "${SOURCE_ARRAY[$i]}")"
        echo "${TEMP}" >> "${LOCAL_MD5}"
        echo "${TEMP}" | sed "s|${SOURCE_ARRAY[$i]}|${DEST_ARRAY[$i]}|" >> "tmp"
    fi
done

DELETE_ARRAY=( )

#Also test append to empty array with nounset set

#DELETE_ARRAY+=( "foobar" )

#DELETE_ARRAY=("foo" "bar")


SOURCE_ARRAY=( )
for i in "${!DELETE_ARRAY[@]}"; do
    #echo "${DELETE_ARRAY[$i]:-}"
    SOURCE_ARRAY+=( "${DELETE_ARRAY[@]}" )
done

exit 0


#NUM_DEL_ITEMS=${#DELETE_ARRAY[@]}
#for ((i = 0 ; i < ${NUM_DEL_ITEMS} ; i++)); do
for dir in "${DELETE_ARRAY[@]:-}"; do
    #dir="${DELETE_ARRAY[$i]}"
    echo "${DELETE_ARRAY[0]:-}"
    echo $dir
done