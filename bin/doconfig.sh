#!/bin/sh

# REMOVE THIS
#
# export PATH=/usr/local/bin:/usr/sbin:$PATH
# echo ${#SERVER_TYPE}
# SERVER_TYPE="aws"

if [ -z "$SERVER_TYPE" ]; then
    SERVER_TYPE="default"
fi

if [ "$OCR_ENGINE" = "kocr" ]; then
    OCR_DIR="-l ./etc/"
fi
OCR_DIR=${OCR_DIR:=""}

#
# AWS specific processing
#
if [ "$SERVER_TYPE" = "aws" -a ! -z "$AWS_ADDRESS" ]; then
    EC2USERDATA=/tmp/ec2userdata$$
    wget -O $EC2USERDATA http://$AWS_ADDRESS/latest/user-data/ >/dev/null 2>&1
    . $EC2USERDATA
    rm $EC2USERDATA
fi

if [ "$SERVER_TYPE" = "aws" -o "$SERVER_TYPE" = "docker" ]; then
    # for compatibility
    if [ ! -z "$FAXFROMADDR" ]; then
	FAX_SEND_FROM=$FAXFROMADDR
    fi

    if [ ! -z "$FAXFROMADDR" ]; then
	FAX_SEND_TARGET=$FAXTODOMAIN
    fi

    POP3_HOST=$POP3HOST
    POP3_PORT=$POP3PORT
    POP3_USER=$POP3USER
    POP3_PASSWORD=$POP3PASSWORD
    POP3_SSL=$POP3SSL

    SMTP_SSL=$SMTPSSL
    SMTP_HOST=$SMTPHOST
    SMTP_PORT=$SMTPPORT
    SMTP_USER=$SMTPUSER
    SMTP_PASSWORD=$SMTPPASSWORD
    SMTP_FROM=$SMTPFROM
    SMTP_AUTH=$SMTPAUTH

    FAX_USER=$FAXUSER
    FAX_PASS=$FAXPASS
fi

#
# for some critical parameters
#
if [ -z "$SMTP_SSL" ] ; then
    SMTP_SSL="no"
fi

if [ "$SMTP_SSL" = "true" ] ; then
    SMTP_SSL="yes"
else
    SMTP_SSL="no"
fi

if [ -z "$SMTP_HOST" ] ; then
    SMTP_HOST="no"
fi

if [ -z "$FAX_RECV_SETTING" ] ; then
    FAX_RECV_SETTING="pop3"
fi

ERROR_PDF_FILE_FOR_FAX_SENDER=${ERRORPDF:="/home/faxocr/etc/error.pdf"}

if [ -z "$BIZFAX_PROGRAM" ] ; then
    BIZFAX_PROGRAM="/home/faxocr/bin/bizfax-sendfax"
fi

if [ -z "$BIZFAX_FAX_SIZE" ] ; then
    BIZFAX_FAX_SIZE="A4"
fi

GNU_PARALLEL_LEVEL=${JOB_PARALLEL_LEVEL:="100%"}

#################
# DO NOT EDIT
#

# Directory setting (No need to edit)
DIR_RAILS="/home/faxocr/rails"
DIR_MAIL="/home/faxocr/Maildir/new"
DIR_FAX="/home/faxocr/Faxsystem"

DATE=`date +%Y%m%d`
TIME=`date +%H%M%S`
MAIL_QUEUE_DIR=$DIR_MAIL

RAILS_ROOT_DIR=$DIR_RAILS
SHEETREADER_CONF_DIR=$DIR_RAILS"/faxocr_config/receive_sheetreader"
SHEETREADER_ANALYZE_DIR=$DIR_FAX"/analyzedimage/"

MUNPACK_TMP_DIR_PREFIX=$DIR_FAX"/Tempmunpack/"$DATE$TIME
MAIL_BACKUP_DIR=$DIR_FAX"/Mailbackup/"$DATE$TIME
SEND_BACKUP_DIR=$DIR_FAX"/Sendbackup/"$DATE$TIME
FAX_BACKUP_DIR=$DIR_FAX"/Faxbackup/"$DATE$TIME
SESSION_LOG_DIR=$DIR_FAX"/Log/"$DATE$TIME
PROCFAX_TMP_DIR=$DIR_FAX"/Procfaxtmp/"$DATE$TIME
