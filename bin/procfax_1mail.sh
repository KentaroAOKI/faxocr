#!/bin/sh

set -u

CONF_FILE=/home/faxocr/etc/faxocr.conf
UTIL_FILE=/home/faxocr/bin/procfax_utils.sh

if [ -z "$SERVER_TYPE" -o $SERVER_TYPE = "default" ]; then
  . $CONF_FILE
fi
. $UTIL_FILE

if [ x"$DEBUG_MODE" = x'true' ]; then
	show_info_message "===== DEBUG MODE ====="
fi

#
# private functions
#
write_result_to_files()
{
	echo "$fax_count"         > "$PROCFAX_TMP_DIR"/"$MAIL_FILE_NAME".fax_count
	echo "$fax_error_count"   > "$PROCFAX_TMP_DIR"/"$MAIL_FILE_NAME".fax_error_count
	echo "$sheet_count"       > "$PROCFAX_TMP_DIR"/"$MAIL_FILE_NAME".sheet_count
	echo "$sheet_error_count" > "$PROCFAX_TMP_DIR"/"$MAIL_FILE_NAME".sheet_error_count
}


#
# initialize local variables
#
fax_error_happens_flag=0

fax_count=1
fax_error_count=0
sheet_count=0
sheet_error_count=0

mail_file="$MAIL_QUEUE_DIR"/"$MAIL_FILE_NAME"
pid=$$


show_info_message Target Mail File: "$mail_file"
show_info_message BACKUP MAIL: "$MAIL_BACKUP_DIR"/"$MAIL_FILE_NAME"

#
# backup mail
#
cp -p "$mail_file" "$MAIL_BACKUP_DIR"
show_cmd_result $? backup the "mail($MAIL_FILE_NAME)"

#
# ignore messages from root
#
is_from_root=`grep "From: " "$mail_file" | grep root | head -1`
if [ "$is_from_root" != "" ]; then
	show_info_message Target Mail is from root: ignored
	rm "$mail_file"
	show_cmd_result $? remove the original "mail($mail_file)"
	write_result_to_files
	exit 0
fi

#
# recognize from/to fax number (based on fax service type) by using srhelper
#
is_faximo=`grep "faximo.jp" "$mail_file" | head -1`
is_messageplus=`grep "everynet.jp" "$mail_file" | head -1`
is_bizfax=`grep "050fax.jp" "$mail_file" | head -1`
srhelper_fax_mode="faximo"
if [ "$is_faximo" != "" ]; then
	srhelper_fax_mode="faximo"
fi
if [ "$is_messageplus" != "" ]; then
	srhelper_fax_mode="messageplus"
fi
if [ "$is_bizfax" != "" ]; then
	srhelper_fax_mode="bizfax"
fi
if [ x"$DEBUG_MODE" != x'true' -a x"$is_faximo" = x"" -a x"$is_messageplus" = x"" -a x"$is_bizfax" = x"" ]; then
	show_error_message FAX: ERROR: cannot recognize a fax service from Mail
	fax_error_happens_flag=1
fi
src_fax_number=`srhelper -m from -s "$srhelper_fax_mode" "$mail_file"`
if [ "$src_fax_number" = "" ]; then
	src_fax_number="UNNUMBER"
fi
dest_fax_number=`srhelper -m to -s "$srhelper_fax_mode" "$mail_file"`
if [ "$dest_fax_number" = "" ]; then
	dest_fax_number="UNNUMBER"
fi
if [ x"$DEBUG_MODE" = x'true' ]; then
	src_fax_number="TEST"
	dest_fax_number="TEST"
fi
show_info_message got fax info from e-mail: from:"$src_fax_number" to:"$dest_fax_number"


#
# unpack the fax image file
#
# this tmp directory must be per process
munpack_tmp_dir="$MUNPACK_TMP_DIR_PREFIX"."$pid"
mkdir -p "$munpack_tmp_dir"
show_cmd_result $? creating a tmp "dir($munpack_tmp_dir)" for munpack
munpack -C "$munpack_tmp_dir" < "$mail_file"
show_cmd_result $? unpack the fax image file by munpack
rm "$mail_file"
show_cmd_result $? remove the original "mail($mail_file)"


#
# extract tiff files
#
number_of_unpacked_fax_files=`ls "$munpack_tmp_dir"/* | wc -l`
if [ "$number_of_unpacked_fax_files" -gt "0" ]; then
	attached_tiff_files=`ls "$munpack_tmp_dir"/* | grep -ie TIF$ | head -1`
fi
if [ "$attached_tiff_files" != "" ]; then
	# When a tiff file has only one page, old version of converter
	# command generates "single%d.tif" instead of "single0.tif".
	# On the other hand a newer version of converter command
	# generates "single0.tif".
	convert "$attached_tiff_files" "$munpack_tmp_dir"/single%d.tif
	show_cmd_result $? extracting tiff files by convert command
	if [ -e "$munpack_tmp_dir"/single%d.tif ]; then
		mv "$munpack_tmp_dir"/single%d.tif "$munpack_tmp_dir"/single.tif
	fi
fi


#
# process each tiff file
#
for a_tiff_file in `ls "$munpack_tmp_dir"/single*`
do
	# initialize local variable
	sheet_error_happens_flag=0

	sheet_count=`expr "$sheet_count" + 1`

	#
	# change the image size
	#
	resized_tiff_file="$FAX_BACKUP_DIR"/"$src_fax_number"_"$dest_fax_number"_"$DATE"_"$TIME"_"$pid"_"$sheet_count".TIF

	convert -type GrayScale -resample 200 "$a_tiff_file" "$resized_tiff_file"
	show_cmd_result $? resizing tiff "file($resized_tiff_file)"

	#
	# Sheetreader processing
	#
	ruby_code_generated_from_sheetreader="$FAX_BACKUP_DIR"/"$src_fax_number"_"$dest_fax_number"_"$DATE"_"$TIME"_"$pid"_"$sheet_count".rb

	sheetreader -m rails -c "$SHEETREADER_CONF_DIR" $OCR_DIR -r "$dest_fax_number" -s "$src_fax_number" -p "$SHEETREADER_ANALYZE_DIR" \
		-l "/home/faxocr/src/kocr/databases" "$resized_tiff_file" > "$ruby_code_generated_from_sheetreader"
	sheetreader_exit_status=$?
	if [ "$sheetreader_exit_status" -ne 0 ]; then
		show_error_message SHEETREADER: ERROR: sheetreader returns non-zero value: "$sheetreader_exit_status"
		sheet_error_happens_flag=1
	else
		show_info_message sheetreader exit status: "$sheetreader_exit_status"
	fi

	#
	# generate thumbnail image
	#
	image_path=`grep image.png "$ruby_code_generated_from_sheetreader" | head -1 | cut -s -d\' -f2`
	if [ `echo "$image_path" | wc -l` -eq  0 ]; then
		show_error_message not found path info of image file from sheetreader
		show_error_message so cannot create thumbnail image
		sheet_error_happens_flag=1
	else
		show_info_message found path info of image file from sheetreader: "$image_path"

		image_prefix=`dirname "$image_path"`
		thumbnail_image_dir="$SHEETREADER_ANALYZE_DIR$image_prefix"
		convert -geometry 500 "$thumbnail_image_dir"/image.png "$thumbnail_image_dir"/image_thumb.png
		show_cmd_result $? generating a thumbnail image file "$thumbnail_image_dir"/image_thumb.png
	fi

	#
	# Echo file processing
	#
	echo_file="echofile$pid"
	ruby "$ruby_code_generated_from_sheetreader" "$RAILS_ROOT_DIR" "$SHEETREADER_ANALYZE_DIR" \
		"$echo_file"
	ruby_exit_status=$?
	if [ "$ruby_exit_status" = "8" ]; then
		show_info_message send echo mail
		sendfax "$src_fax_number" echoreport "$echo_file".pdf
		rm "$echo_file".pdf "$echo_file".html
		show_cmd_result $? cleaning up pdf and html files generated for echo processing
	fi
	if [ "$sheet_error_happens_flag" -eq 1 ]; then
		sheet_error_count=`expr "$sheet_error_count" + 1`
		fax_error_happens_flag=1
	fi
done
if [ "$fax_error_happens_flag" -eq 1 ]; then
	fax_error_count=`expr "$fax_error_count" + 1`
fi


#
# send an error fax report if sheetreader fails
#
if [ "$src_fax_number" != "UNNUMBER" -a "$sheet_error_happens_flag" -gt 0 ]; then
	show_info_message send an error report fax to "$src_fax_number" via "$FAX_SEND_TYPE"
	sendfax "$src_fax_number" errorreport "$ERROR_PDF_FILE_FOR_FAX_SENDER"
fi


#
# clean up files and directories
#
rm "$munpack_tmp_dir"/*
show_cmd_result $? cleaning up files in "$munpack_tmp_dir"
rmdir "$munpack_tmp_dir"
show_cmd_result $? removing the tmp "dir($munpack_tmp_dir)" for munpack


#
# save processing result
#
write_result_to_files

exit 0
