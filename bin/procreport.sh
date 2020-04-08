#!/bin/sh

export PATH=/usr/local/bin:/usr/sbin:$PATH

# get configuration

CONF_FILE=/home/faxocr/faxocr/etc/faxocr.conf
CONF_PROC=/home/faxocr/faxocr/bin/doconfig.sh

. $CONF_FILE
. $CONF_PROC

SURVEYID=$1
REPYEAR=$2
REPMONTH=$3
REPDAY=$4
SENDNUMBER=$5

REPHTML="/tmp/procrep"$$".html"
REPMAIL="/tmp/procrep"$$".eml"
LOG=$SESSION_LOG_DIR"/procrep.log"

mkdir $SEND_BACKUP_DIR 2> /dev/null

#
# generate the report and send it (NEEDS CHECK)
#
$RAILS_ROOT_DIR/script/send_daily_report.rb $DATE $TIME $SHEETREADER_ANALYZE_DIR $SEND_BACKUP_DIR \
    $FAX_SEND_FROM $FAX_SEND_TARGET

if [ "`ls $SEND_BACKUP_DIR`" = '' ]; then
    rm -r $SEND_BACKUP_DIR
fi

