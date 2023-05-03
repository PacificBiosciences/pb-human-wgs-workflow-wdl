#!/bin/bash
#run-wdl-pacbio-pipeline.sh -- bash script to run wdl-pacbio-pipeline for a cohort of sample(s)
#
#author: Chengpeng Bi
#
#last modified: 2022-11-28
#

set -o errexit

source etc/wdl-input.env

usage ()
{
    cat << EOF
usage: $0 -i INPUT_WDL.json  -l LOGFILE

OPTIONS:
  -h    show this message
  -p    host-portal -- http://10.100.88.11:8000 -- default value
  -w    web address to agape_thin.wdl -- default value
  -z    zipped pacbio-workflow-wdl -- default file
  -o    options.json -- default
  -i    json file of wdl-input.json -- must be provided
  -l    logfile -- must be provided
EOF
}

while getopts hp:w:i:l:o:z: OPTION
do
    case $OPTION in
       h)
           usage
           exit 1
           ;;
       p)
           PORTAL=$OPTARG
           ;;
       w)
           WORKFLOW_WDL=$OPTARG
           ;;
       z)
           WORKFLOW_ZIP=$OPTARG
           ;;
       l)
           LOGFILE=$OPTARG
           ;;
       o)
           OPTIONS=$OPTARG
           ;;
       i)
           INPUT_WDL=$OPTARG
           ;;
   esac
done

if [[ -z "$PORTAL" || -z "$WORKFLOW_WDL" || -z "$WORKFLOW_ZIP" || -z "$INPUT_WDL" || -z "$OPTIONS" || -z "$LOGFILE" ]]; then
    usage
    exit 1
else
    echo "command-line: $0 $@"
    echo
fi

echo Host-port = $PORTAL
echo Workflow-WDL = $WORKFLOW_WDL
echo Logfile = $LOGFILE
echo Options = $OPTIONS
echo wdl-inputfile = $INPUT_WDL
echo cromwell submit -h $PORTAL -i $INPUT_WDL -o $OPTIONS --imports $WORKFLOW_ZIP $WORKFLOW_WDL \>$LOGFILE

source ~byoo/miniconda3/bin/activate cromwell
cromwell submit -h $PORTAL -i $INPUT_WDL -o $OPTIONS --imports $WORKFLOW_ZIP $WORKFLOW_WDL >$LOGFILE

