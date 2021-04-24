#!/bin/bash

##################################################
# Run Cd'or on each analysis study on Linux Ubuntu (Cygnus)
# 1. Fix up cd-cem.cfg to use Linux path separator /
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

# Cd'or exe on Cygnus after munging cfg files run on Windows
find -maxdepth 4 -name 'cd-cem.cfg'  -type f -exec sed -i 's/\\/\//g' {} \;

CD_CEM_CFGS=(`find -maxdepth 4 -name 'cd-cem.cfg' -type f -print`)
#./ChangeDetector \
#CFGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/cd-cem.cfg \
#LOGLEVEL=TRACE \
#LOGFILE=/home/eric/data/mammo/Jordana/analysis-162-1616461963445/result-0/cem-0/logs/logfile.txt
for i in "${!CD_CEM_CFGS[@]}"
do
    # shellcheck disable=SC2086
    # ./analysis-211-1616525474084/result-0/cem-3
    CEM_DIR="$(dirname ${CD_CEM_CFGS[$i]})"
    # shellcheck disable=SC2086
    CEM_NAME="$(basename ${CEM_DIR})"
    # shellcheck disable=SC2086
    RESULT_DIR="$(dirname ${CEM_DIR})"
    # shellcheck disable=SC2086
    ANALY_DIR="$(dirname ${RESULT_DIR})"
    # shellcheck disable=SC2086
    ANALY_NAME="$(basename ${ANALY_DIR})"
    LOG_DIR="${CEM_DIR}/logs"
    # shellcheck disable=SC2086
    mkdir -p ${LOG_DIR}
    LOG_FILE="${LOG_DIR}/logfile.txt"
    echo "/home/eric/kauai/tools/ChangeDetector CFGFILE=${CD_CEM_CFGS[$i]} LOGLEVEL=TRACE LOGFILE=${LOG_FILE}"
    /home/eric/kauai/tools/ChangeDetector CFGFILE=${CD_CEM_CFGS[$i]} LOGLEVEL=TRACE LOGFILE=${LOG_FILE}
    EXIT_CODE=$?
    if [[ ${EXIT_CODE} -ne 0 ]]; then
        printf "CDor failed for case: %s %s \n" "${ANALY_NAME}" "${CEM_NAME}"
    else
        # analysis-162-1616461963445/result-0/cem-0/extra/Pre-Post-FollowuppdmAllHistograms_LogTen_AsSlice_Final_.nii
        cp ${CEM_DIR}/extra/Pre-Post-FollowuppdmAllHistograms_LogTen_AsSlice_Final_.nii ${PWD}/${ANALY_NAME}_${CEM_NAME}_Pre-Post-FollowuppdmAllHistograms_LogTen_AsSlice_Final_.nii
    fi

done

