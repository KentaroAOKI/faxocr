#!/bin/sh

# export PATH=/usr/local/bin:/usr/sbin:$PATH
export PATH=/usr/local/bin:/usr/sbin:/home/faxocr/bin/:$PATH

# get configuration

CONF_FILE=~faxocr/etc/faxocr.conf
CONF_PROC=~faxocr/bin/doconfig.sh

. $CONF_FILE
. $CONF_PROC

# receive fax
if [ "$FAX_RECV_SETTING" = "pop3" ]; then
    getfax
fi

# temp files
ERRORMAIL="/tmp/error"$$".eml"
ECHOFILE="/tmp/echofile"$$
ECHOMAIL="/tmp/echofile"$$".eml"
LOG=$LOGDIR"/procfax.log"
TIME=`date +%H%M%S`
SHEET_COUNT=0

if [ "`ls $MDIR`" = '' ]; then
    exit
fi

mkdir $MBACKDIR 2> /dev/null
mkdir $FBACKDIR 2> /dev/null
mkdir $LOGDIR 2> /dev/null
mkdir $UNTMPDIR 2> /dev/null

ruby rails/script/getsrml.rb > $SHEETREADERCONF/srml/faxocr.xml
for MFILE in `ls $MDIR`
do
	#
	# directory setting / preprocessing
	#
	echo FOUND: $MDIR/$MFILE
	echo FOUND: $MDIR/$MFILE >> $LOG
	echo BACKUP MAIL: $MBACKDIR/$MFILE
	echo BACKUP MAIL: $MBACKDIR/$MFILE >> $LOG
	cp $MDIR/$MFILE $MBACKDIR

	# removes messages from root
	ISFROMROOT=`grep "From: " $MDIR/$MFILE | grep root | head -1`
	if [ "$ISFROMROOT" != "" ]; then
		rm $MDIR/$MFILE
		continue;
	fi

	#
	# recognize from/to number (based on fax service type)
	#
	ISFAXIMO=`grep "faximo.jp" $MDIR/$MFILE | head -1`
	ISMESSAGEPLUS=`grep "everynet.jp" $MDIR/$MFILE | head -1`
	ISBIZFAX=`grep "050fax.jp" $MDIR/$MFILE | head -1`
	SRHMODE="faximo"
	if [ "$ISFAXIMO" != "" ]; then
		SRHMODE="faximo"
	fi
	if [ "$ISMESSAGEPLUS" != "" ]; then
		SRHMODE="messageplus"
	fi
	if [ "$ISBIZFAX" != "" ]; then
		SRHMODE="bizfax"
	fi
	if [ x"$ISFAXIMO" = x"" -a x"$ISMESSAGEPLUS" = x"" -a x"$ISBIZFAX" = x"" ]; then
		echo FAX: ERROR: cannot recognize a fax service from Mail >&2
		echo FAX: ERROR: cannot recognize a fax service from Mail
		echo FAX: ERROR: cannot recognize a fax service from Mail >> $LOG
	fi
	FFROM=`srhelper -m from -s $SRHMODE $MDIR/$MFILE`
	if [ "$FFROM" = "" ]; then
		FFROM="UNNUMBER"
	fi
	FTO=`srhelper -m to -s $SRHMODE $MDIR/$MFILE`
	if [ "$FTO" = "" ]; then
		FTO="UNNUMBER"
	fi
	echo FAX: from:$FFROM to:$FTO
	echo FAX: from:$FFROM to:$FTO >> $LOG

	#
	# unpack the fax image file
	#
 	cat $MDIR/$MFILE | munpack -C $UNTMPDIR 2>> $LOG 1>> $LOG
	rm $MDIR/$MFILE

	UNTMPDIR_FILES=`ls $UNTMPDIR/* | wc -l`
	if [ "$UNTMPDIR_FILES" -gt "0" ]; then
	    ATTACHED_TIFF=`ls $UNTMPDIR/* | grep -ie TIF$ 2>> $LOG |head -1`
	fi
	if [ "$ATTACHED_TIFF" != "" ]; then
		# When a tiff file has only one page, old version of converter
		# command generates "single%d.tif" instead of "single0.tif".
		# On the other hand a newer version of converter command
		# generates "single0.tif".
		convert $ATTACHED_TIFF $UNTMPDIR/single%d.tif
		if [ -e $UNTMPDIR/single%d.tif ]; then
			mv $UNTMPDIR/single%d.tif $UNTMPDIR/single.tif
		fi
	fi

	# XXX
	# pwd >> /tmp/taka-log
	# echo $ATTACHED_TIFF >> /tmp/taka-log
	# cp $ATTACHED_TIFF /tmp/taka-tiff-orig.tif
	# cp $UNTMPDIR/single* /tmp

	for TIFFILE in `ls $UNTMPDIR/single*`
	do
		#
		# Sheetreader processing
		#
		#echo BACKUP TIF: $MBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME.TIF
		#echo BACKUP TIF: $MBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME.TIF >> $LOG
		SHEET_COUNT=`expr $SHEET_COUNT + 1`
		BACKTIFF=$FBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME"_"$SHEET_COUNT.TIF
		echo BACKUP TIF: $BACKTIFF
		echo BACKUP TIF: $BACKTIFF >> $LOG

		convert -resample 200 $TIFFILE $BACKTIFF
		sheetreader -m rails -c $SHEETREADERCONF $OCR_DIR -r $FTO -s $FFROM -p $ANALYZEDIR \
		    $BACKTIFF 2>> $LOG 1> $FBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME"_"$SHEET_COUNT".rb"
		SRRESULT=$?
		if [ $SRRESULT -ne 0 ];then
			echo SHEETREADER: ERROR: sheetreader returns non-zero value: $SRRESULT >&2
			echo SHEETREADER: ERROR: sheetreader returns non-zero value: $SRRESULT
			echo SHEETREADER: ERROR: sheetreader returns non-zero value: $SRRESULT >> $LOG
		else
			echo SHEETREADER: $SRRESULT
			echo SHEETREADER: $SRRESULT >> $LOG
		fi


		SRDATE=`grep answer_sheet.date $FBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME"_"$SHEET_COUNT".rb" | cut -d\" -f2`
		if [ x"${SRDATE}" != x"" ]; then
			echo SHEETREADER: date used in sheetreader: ERROR: result is empty
			echo SHEETREADER: date used in sheetreader: ERROR: result is empty >&2
			echo SHEETREADER: date used in sheetreader: ERROR: result is empty >> $LOG
		else
			echo SHEETREADER: date used in sheetreader: $SRDATE
			echo SHEETREADER: date used in sheetreader: $SRDATE >> $LOG
		fi
		IMAGEDIR=${ANALYZEDIR}R${FFROM}/S${FTO}/${SRDATE}
		convert -geometry 500 ${IMAGEDIR}/image.png ${IMAGEDIR}/image_thumb.png

		#
		# Error file processing
		#
		if [ "$FFROM" != "UNNUMBER" -a "$SRRESULT" != "0" ]; then
		    echo SEND ERROR MAIL
		    sendfax $FFROM errorreport $ERRORPDF
		fi

		#
		# Echo file processing
		#
		ruby $FBACKDIR"/"$FFROM"_"$FTO"_"$DATE"_"$TIME"_"$SHEET_COUNT".rb" $RAILSPATH $ANALYZEDIR \
		    $ECHOFILE
		RUBYRESULT=$?
		if [ "$RUBYRESULT" = "1" ]; then
		    echo SEND ECHO MAIL
		    sendfax $FFROM echoreport $ECHOFILE.pdf
		    rm $ECHOFILE.pdf
		    rm $ECHOFILE.html
		fi
	done
	rm $UNTMPDIR/* 2>> $LOG
done
rmdir $UNTMPDIR 2>> $LOG
