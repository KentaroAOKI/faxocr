<?php
/*
 * Shinsai FaxOCR
 *
 * Copyright (C) 2009-2013 National Institute of Public Health, Japan.
 * All rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

require_once 'config.php';
require_once 'init.php';
require_once 'lib/common.php';
require_once 'lib/file_conf.php';
require_once 'lib/sheet_field.php';
require_once 'contrib/reviser.php';

// XXX
// file_put_contents("/tmp/faxocr.log", "test");

if (isset($_REQUEST["file_id"])) {
	$file_id = $_REQUEST["file_id"];
}

$list_colspan = array();

//
// ファイルハンドリング
//
if (isset($file_id) && $file_id) {
	$tgt_file = DST_DIR . $file_id . ".xls";
} else {
	print "不正なアクセスです\n";
	// put_err_page("不正なアクセスです");
	die;
}

if (isset($_REQUEST["target"])) {
	$target = $_REQUEST["target"];
} else {
	$target = "registered";
}

//
// Read Excelファイル処理
//
if ($tgt_file) {
	$xls = NEW Excel_Reviser;
	$xls->setErrorHandling(1);
	$xls->setInternalCharset($charset);
	$result = $xls->parseFile($tgt_file, 1);

	if ($xls->isError($result)) {
		$errmsg = $result->getMessage();
		$xls = null;
	}

	foreach ($xls->cellblock as $keysheet => $sheet) {
		$maxcol = 0;
		foreach ($sheet as $keyrow => $rows) {
			foreach($rows as $keycol => $cell) {
				if ($maxcol < $keycol) $maxcol = $keycol;
			}
		}
		$xls->maxcell[$keysheet] = $maxcol;
		$xls->maxrow[$keysheet] = $keyrow;
	}
	$xls->sheetnum = count($xls->boundsheets);
}

$msg = "tgt: " . $tgt_file . "\n";

//
// reviserのClassオブジェクトを新規作成
//
$reviser = NEW Excel_Reviser;
$reviser->setInternalCharset($charset);
$reviser->setErrorHandling(1); // エラーハンドリング依頼
$res = $reviser->parseFile($tgt_file);

for ($sn = 0; $sn < $xls->sheetnum; $sn++) {
	for ($r = 0; $r <= $xls->maxrow[$sn]; $r++) {
		for ($i = 0; $i <= $xls->maxcell[$sn]; $i++) {
			if (isset($_REQUEST["cell-${sn}-${r}-${i}-mark"])) {
				$val = $_REQUEST["cell-${sn}-${r}-${i}-mark"];
				if (is_numeric($val)) {
					$reviser->addNumber($sn, $r, $i, $val, 0, 0, 0);
				} else {
					$reviser->addString($sn, $r, $i, $val, 0, 0, 0);
				}
			} else if (isset($_REQUEST["cell-${sn}-${r}-${i}-clear"])) {
				$val = $_REQUEST["cell-${sn}-${r}-${i}-clear"];
				if (is_numeric($val)) {
					$reviser->addNumber($sn, $r, $i, $val, 0, 0, 0);
				} else {
					$reviser->addString($sn, $r, $i, $val, 0, 0, 0);
				}
			}
		}
	}
}

//
// コミット
//
$lockfp = fopen(LOCK_FILE . $file_id, 'w');
flock($lockfp, LOCK_EX);
$template_xls = TMP_XLS;
$tmp_file = uniqid();

/* $msg .= "tmp file: " . $tmp_file . "\n"; */
/* $msg .= "tmp xls: " . $template_xls . "\n"; */

if (filesize($tgt_file)) {
	$result = $reviser->buildFile($tmp_file, TMP_DIR);
    echo "rviser:" . $result;
}

if (!file_exists(DST_DIR . $file_id . ORIG_EXT)) {
	copy($tgt_file, DST_DIR . $file_id . ORIG_EXT);
}

if (file_exists(TMP_DIR . $tmp_file)) {
	rename(TMP_DIR . $tmp_file, $tgt_file);
}
flock($lockfp, LOCK_UN);
fclose($lockfp);
unlink(LOCK_FILE . $file_id);

put_config($file_id, $_REQUEST, $target, $sheet_name, $list_colspan);

// XXX: debugging purpose
/*
file_put_contents("/tmp/faxocr.log",
  "----------------------------------------\n" .
  date("Y/m/d H:i:s") . "\n(" .
  count($_REQUEST) . ")\n" .
  $msg . "\n\n",
  FILE_APPEND | LOCK_EX
);
*/

die;

function is_next($prev, $next)
{
	if (!isset($prev) || !isset($next)) {
		return false;
	}

	# sheet_num
	if ($prev[1] != $next[1]) {
		return false;
	}

	# row
	if ($prev[2] != $next[2]) {
		return false;
	}

	# col
	if ($next[3] - $prev[3] == 1) {
		return true;
	}

	return false;
}

//
// config出力
//
function put_config($file_id, $REQUEST, $target, $sheet_name, &$list_colspan)
{
	$str_type = array(0 => "number",
			  1 => "number",
			  2 => "rating",
			  3 => "image",
			  4 => "alphabet_lowercase",
			  5 => "alphabet_uppercase",
			  6 => "alphabet_number");

	$conf = new FileConf($file_id);

	$list_requests = array();
	foreach ($REQUEST as $item => $val) {
		preg_match("/field-(\d+)-(\d+)-(\d+)-(\d+)/", $item, $loc);
		if ($loc && $loc[0]) {
			$location = "${loc[1]}-${loc[2]}-${loc[3]}";
			$list_requests[$location] = $val;
		}
	}

	uksort($list_requests, 'strnatcmp');

	foreach ($list_requests as $item => $val) {
		if (!isset($list_colspan[$item]))
			$list_colspan[$item] = 0;
	}

	$array_counts = array_count_values($list_requests);
	foreach ($array_counts as $key => $val) {
		$l = array_search ($key, $list_requests, FALSE);
		if ($list_colspan[$l] == 0)
			$list_colspan[$l] = $val;
	}

	// XLSフィールド情報REQUEST取得
	$conf->array_destroy("field");
	$span_info = get_span_info_from_field_ids($REQUEST);
	foreach ($REQUEST as $item => $val) {
		preg_match("/field-(\d+)-(\d+)-(\d+)-(\d+)/", $item, $loc);

		if ($loc && $loc[0]) {
			$xls_fields = array();
			$xls_fields["sheet_num"] = $loc[1];
			$xls_fields["row"]       = $loc[2];
			$xls_fields["col"]       = $loc[3];
			$xls_fields["item_name"] = $val;
			# number, rating, image, alphabet_lowercase, alphabet_uppercase, alphabet_number
			$xls_fields["type"]       = $str_type[$loc[4]];

			$location = "${loc[1]}-${loc[2]}-${loc[3]}";

			if (isset($list_colspan[$location])) {

				if ($list_colspan[$location] == 0)
					continue;

				$xls_fields["colspan"] = $list_colspan[$location];
			}
			if (isset($span_info["colspan"][$xls_fields["row"]][$xls_fields["col"]])) {
				$xls_fields["colspan"] = $span_info["colspan"][$xls_fields["row"]][$xls_fields["col"]];
			}

			// XLSフィールド情報保存
			$conf->array_set("field", $xls_fields);
		}
	}
	$conf->array_commit();

	if (isset($target) && strlen($target) > 0) {
		$conf->set("target", $target);
	}

	if (isset($sheet_name) && strlen($sheet_name) > 0) {
		$conf->set("name", $sheet_name);
	}
	$conf->set("selectedFieldDataJson", $_REQUEST["selectedFieldData"]);
	$conf->commit();
}

?>
