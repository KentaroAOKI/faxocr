#!/bin/sh


# export PATH=/usr/local/bin:/usr/sbin:$PATH
export PATH=/usr/local/bin:/usr/sbin:/home/faxocr/bin/:"$PATH"

#
# import configuration
#
CONF_FILE=/home/faxocr/etc/faxocr.conf
CONF_PROC=/home/faxocr/bin/doconfig.sh
UTIL_FILE=/home/faxocr/bin/procfax_utils.sh

if [ -z "$SERVER_TYPE" -o $SERVER_TYPE = "default" ]; then
  . $CONF_FILE
fi
. $CONF_PROC
. $UTIL_FILE

set -u

#
# global variables
#
LOG_FILE_FOR_THIS_SESSION="$SESSION_LOG_DIR"/procfax.log

#
# set working directory of this script
#
cd /home/faxocr

#
# have not to run multiple instances
#
session_lock_file="$DIR_FAX"/"`basename $0`".lock
trap 'echo "trapped."; rm -f ${session_lock_file}; exit 1' 1 2 3 15

if ! ln -s $$ "${session_lock_file}"; then
	show_message_to_console 'Cannot run multiple instances.'
	exit 1
fi

#
# retrieve fax from a pop server
#
if [ "$FAX_RECV_SETTING" = "pop3" ]; then
	sh /home/fax/getfax
	show_cmd_result $? retrieving Fax via a pop server
fi

#
# check new arrival mail
#
if [ "`ls $MAIL_QUEUE_DIR`" = '' ]; then
	show_info_message NOT FOUND: not found new email
	rm "$session_lock_file"
	show_cmd_result $? removing lock "file($session_lock_file)"
	exit
fi

#
# prepare some directories before main process
#
mkdir "$MAIL_BACKUP_DIR" 2> /dev/null
mkdir "$FAX_BACKUP_DIR" 2> /dev/null
mkdir -p "$PROCFAX_TMP_DIR" 2> /dev/null
mkdir "$SESSION_LOG_DIR" 2> /dev/null

#
# main
#
ruby rails/script/getsrml.rb > "$SHEETREADER_CONF_DIR"/srml/faxocr.xml
show_cmd_result_and_logfile $? generating faxocr.xml

RAILS_ENV=${RAILS_ENV:="undefined"}
if [ x"$RAILS_ENV" = x"undefined" ]; then
	rails_current_running_mode=`get_current_running_mode_of_rails`
	export RAILS_ENV=${rails_current_running_mode:="production"}
fi

ls "$MAIL_QUEUE_DIR" | (export \
	LOG_FILE_FOR_THIS_SESSION="$LOG_FILE_FOR_THIS_SESSION" \
	DATE="$DATE" TIME="$TIME" \
	MAIL_QUEUE_DIR="$MAIL_QUEUE_DIR" \
	MAIL_BACKUP_DIR="$MAIL_BACKUP_DIR" \
	MUNPACK_TMP_DIR_PREFIX="$MUNPACK_TMP_DIR_PREFIX" \
	FAX_BACKUP_DIR="$FAX_BACKUP_DIR" \
	SHEETREADER_CONF_DIR="$SHEETREADER_CONF_DIR" \
	OCR_DIR="$OCR_DIR" \
	SHEETREADER_ANALYZE_DIR="$SHEETREADER_ANALYZE_DIR" \
	ERROR_PDF_FILE_FOR_FAX_SENDER="$ERROR_PDF_FILE_FOR_FAX_SENDER" \
	RAILS_ROOT_DIR="$RAILS_ROOT_DIR" \
	PROCFAX_TMP_DIR="$PROCFAX_TMP_DIR" \
	\
	FAX_SEND_TYPE="$FAX_SEND_TYPE" \
	; \
	IFS=""; \
	RESULT_MESSAGE=`parallel --gnu -N1 --jobs "$GNU_PARALLEL_LEVEL" "(export MAIL_FILE_NAME={}; \
		./bin/procfax_1mail.sh > \"$PROCFAX_TMP_DIR\"/{}.log 2>&1; \
		echo $? > \"$PROCFAX_TMP_DIR\"/{}.exit_status; \
		cat \"$PROCFAX_TMP_DIR\"/{}.log \
		)" 2>&1`; \
	echo "$RESULT_MESSAGE" >> "$LOG_FILE_FOR_THIS_SESSION"; \
	echo "$RESULT_MESSAGE"; \
)


#
# calculate result of each fax processing
#
sum ()
{
	_total=0

	for targetFile in "$@"; do
		_val=`cat "$targetFile"`
		_total=`expr $_total + $_val`
	done
	return $_total
}

sum `ls "$PROCFAX_TMP_DIR"/*.fax_count`
fax_count=$?
sum `ls "$PROCFAX_TMP_DIR"/*.fax_error_count`
fax_error_count=$?
sum `ls "$PROCFAX_TMP_DIR"/*.sheet_count`
sheet_count=$?
sum `ls "$PROCFAX_TMP_DIR"/*.sheet_error_count`
sheet_error_count=$?

show_info_message_and_logfile "INFO: Number of fax processed:$fax_count"
show_info_message_and_logfile "INFO: Number of sheet processed:$sheet_count"
show_info_message_and_logfile "INFO: Number of error occurred processing fax:$fax_error_count"
show_info_message_and_logfile "INFO: Number of error occurred processing sheet:$sheet_error_count"

rm "$PROCFAX_TMP_DIR"/*
show_cmd_result_and_logfile $? cleaning up files in "$PROCFAX_TMP_DIR"
rmdir "$PROCFAX_TMP_DIR"
show_cmd_result_and_logfile $? removing "directory($PROCFAX_TMP_DIR)"

rm "$session_lock_file"
show_cmd_result_and_logfile $? removing lock "file($session_lock_file)"
