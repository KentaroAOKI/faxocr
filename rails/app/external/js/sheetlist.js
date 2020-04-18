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


var cellAndFieldIdMap;	// global: file local
var cellBgColorManager;	// global: also referenced from jqcontextmenu
var cell_type;
var enum_cell_type = {
	'number': 1,
	'rating': 2,
	'image': 3,
	'alphabet_lowercase': 4,
	'alphabet_uppercase': 5,
	'alphabet_number': 6,
	'reset': -1,
};
var targetid;
var dirty = false;
var $ = jQuery;


// existence check
function isset(data) {
	return ( typeof( data ) != 'undefined' );
}

// to escape html tag
(function($) {
	$.escapeHTML = function(val) {
		return $('<div />').text(val).html();
	};
})(jQuery);


// initialization
jQuery(document).ready(function($) {

	if ($('#jsiSetup').length > 0) {
		SHEET.setFlexiInSetup();
	}

	$('.sheet_field').selectable({
		filter: 'td',
		selecting: function (event, ui) {
			// Disabling multiple selection when clicking with ctrl or meta key
			var current_element = this;
			if (event.metaKey) {
				$(".ui-selected", this).each(function() {
					if (this != current_element) {
						$(this).removeClass('ui-selected');
					}
				});
			}
		},
		start: function () {
			// destory is neccessary to assign a targetid of field name whenever it is called
			$.contextMenu('destroy', '.ui-selected:first');
		},
		stop: function (event, ui) {
			// setup a context menu for currently selected cells
			var targetId = $('.ui-selected:first').attr('id');
			$.contextMenu({
				selector: '.ui-selected:first',
				trigger: 'left',
				callback: function (key, options) {
					var fieldNameValueFromUser = $.contextMenu.getInputValues(options)['fieldname'];
					SheetFieldProcessor.setMulti(
						enum_cell_type[key],
						fieldNameValueFromUser,
						JqSeletableUIHelper.getSelectedCellIds()
					);
				},
				items: {
					'fieldname': {
						name:'フィールド名',
						type:'text',
						value:targetId,
						events: {
							keyup: function(e) {
								// unfocus if return key is pressed
								if (e.keyCode == 13) {
									this.blur();
								}
							},
						},
					},
					'number': {
						name:'数字',
					},
					'rating': {
						name:'○☓△✓',
					},
					'image': {
						name:'画像',
					},
					'alphabet_lowercase': {
						name:'英字（小文字）',
					},
					'alphabet_uppercase': {
						name:'英字（大文字）',
					},
					'alphabet_number': {
						name:'英数字',
					},
					'sep1': "---------",
					'reset': {
						name:'リセット',
						callback: function (key, options) {
							SheetFieldProcessor.resetMulti();
						},
					},
				},
				events: {
					show: function (opt) {
						var $this = this;
						var targetId = $this.attr('id');
						// set default field value whenever contextMenu is showen
						$.contextMenu.setInputValues(opt, {'fieldname': targetId});
					},
				},
			});
			// show a contextMenu as soon as after cells were selected
			$('.ui-selected:first').contextMenu();
		},
	});
	cell_type = {};

	cellBgColorManager = new SheetCellBackgroundColor();
	cellAndFieldIdMap = new CellAndFieldMapper();

	document.onkeydown = on_keydown;

	targetid = FieldList.init();
	// set callback function when clicking the marker button
	StatusMenu.MarkerButton.setCallbackHandler('click', function (e) {
		this.disabled=true;
		new FieldForm().submit();
	});

	// setup previously selected field data in the sht_field when going back from sht_config page
	for (var fieldId in loadedSelectedData) {
		var type_id = loadedSelectedData[fieldId]['type'];
		var field_data = loadedSelectedData[fieldId]['data'];
		loadedSelectedData[fieldId]['cellIDs'].forEach(function(cellId, index, cellIDs) {
			$("#" + cellId).addClass('ui-selected');
		});
		SheetFieldProcessor.setMulti(
			type_id, field_data, JqSeletableUIHelper.getSelectedCellIds()
		);
		loadedSelectedData[fieldId]['cellIDs'].forEach(function(cellId, index, cellIDs) {
			$("#" + cellId).removeClass('ui-selected');
		});
	}
});


// key押下時
function on_keydown(e) {
	var keycode,
	    ctrl,
	    shift,
	    keychar,
	    frm,
	    target_next;
	var isIe = false;

	if (e != null) {
		// Mozilla(Firefox, NN) and Opera
		keycode = e.which;
		ctrl = (typeof e.modifiers == 'undefined') ?
		    e.ctrlKey : e.modifiers & Event.CONTROL_MASK;
		shift = (typeof e.modifiers == 'undefined') ?
		    e.shiftKey : e.modifiers & Event.SHIFT_MASK;
	} else {
		// Internet Explorer
		isIe = true;
		keycode = event.keyCode;
		ctrl = event.ctrlKey;
		shift = event.shiftKey;
	}

	if (ctrl) {
		dirty = !StatusMenu.MarkerButton.isUnClickable();

		keychar = String.fromCharCode(keycode).toUpperCase();

		if (keychar == 'S') {
			if (e) {
				e.preventDefault();
				e.stopPropagation();
			} else {
				event.returnValue = false;
				event.cancelBubble = true;
			}
			if (!dirty) {
				return false;
			}
			new FieldForm().submit();
		}
	}
	if (isIe == true && keycode == 9) {
		if (shift) {
			return FieldList.moveFocusPrev();
		} else {
			return FieldList.moveFocusNext();
		}
	}
}


/**
 * Cell Id Manipulator
 * @class CellIdManipulator
 */
var CellIdManipulator = {
	/**
	 * Get page number from ID.
	 * @param {string} ID
	 * @return {string} page number of ID or null
	 * @public
	 */
	getPageNum: function (id) {
		return CellIdManipulator._getField(id, "page");
	},
	/**
	 * Get row number from ID.
	 * @param {string} ID
	 * @return {string} row number of ID or null
	 * @public
	 */
	getRowNum: function (id) {
		return CellIdManipulator._getField(id, "row");
	},
	/**
	 * Get column number from ID.
	 * @param {string} ID
	 * @return {string} column number of ID or null
	 * @public
	 */
	getColNum: function (id) {
		return CellIdManipulator._getField(id, "col");
	},
	/**
	 * Get colspan from ID.
	 * @param {string} ID
	 * @return {string} colspan of ID or null
	 * @public
	 */
	getColSpan: function (id) {
		return CellIdManipulator._getField(id, "colSpan");
	},
	/**
	 * Get rowspan from ID.
	 * @param {string} ID
	 * @return {string} rowspan of ID or null
	 * @public
	 */
	getRowSpan: function (id) {
		return CellIdManipulator._getField(id, "rowSpan");
	},
	/**
	 * Get general ID from ID. ex. "0-1-2" from "0-1-2-3"
	 * @param {string} ID
	 * @return {string} general ID or null
	 * @public
	 */
	getGeneralId: function (id) {
		var result = id.match(/(\d+-\d+-\d+)(-\d+)*/);
		return (result == null ? result : result[1]);
	},
	/**
	 * Get general ID from ID. ex. "0-1-2" from "0-1-2-3"
	 * @param {string} id - input value of ID
	 * @param {string} fieldName - a name of part in the ID.
	 * @return {string} general ID or null
	 * @private
	 */
	_getField: function (id, fieldName) {
		var fieldNameTable = {
			page: 1,
			row: 2,
			col: 3,
			colSpan: 5,
			rowSpan: 6,
		};
		var result = id.match(/(\d+)-(\d+)-(\d+)(-(\d+))*/);
		return (result == null ? result : result[fieldNameTable[fieldName]]);
	},
};


/**
 * Collections of functions to cells selected by jQuery selectable
 * @class MultiCells
 *
 */
var MultiCells = {
	/**
	 * Get colspan from selected cells
	 * @return {number} colspan
	 * @public
	 */
	getColSpan: function () {
		var ids = JqSeletableUIHelper.getSelectedCellIds();
		var firstRowNum = MultiCells._getFirstRowNumber(ids);
		return MultiCells._getHorizontalCellCount(ids, firstRowNum);
	},
	/**
	 * Get rowspan from selected cells
	 * @return {number} rowspan
	 * @public
	 */
	getRowSpan: function () {
		var ids = JqSeletableUIHelper.getSelectedCellIds();
		var firstColNum = MultiCells._getFirstColNumber(ids);
		return MultiCells._getVerticalCellCount(ids, firstColNum);
	},
	/**
	 * Get first row number from selected cells.
	 * @return {number} row number
	 * @private
	 */
	_getFirstRowNumber: function (ids) {
		var min = Number.MAX_VALUE;
		for (var i in ids) {
			min = Math.min(min, CellIdManipulator.getRowNum(ids[i]));
		}
		return min;
	},
	/**
	 * Get first column number from selected cells.
	 * @return {number} column number
	 * @private
	 */
	_getFirstColNumber: function (ids) {
		var min = Number.MAX_VALUE;
		for (var i in ids) {
			min = Math.min(min, CellIdManipulator.getColNum(ids[i]));
		}
		return min;
	},

	/**
	 * considered HTML row/cols span
	 */
	/**
	 * Get a number of rows from IDs.
	 * @return {number} row count
	 * @private
	 */
	_getHorizontalCellCount: function (ids, firstRowNum) {
		var cellCount = 0;
		for (var i in ids) {
			if (CellIdManipulator.getRowNum(ids[i]) == firstRowNum) {
				cellCount++;
			};
		}
		return cellCount;
	},
	/**
	 * Get a number of columns from IDs.
	 * @return {number} column count
	 * @private
	 */
	_getVerticalCellCount: function (ids, firstColNum) {
		var cellCount = 0;
		for (var i in ids) {
			if (CellIdManipulator.getColNum(ids[i]) == firstColNum) {
				cellCount++;
			};
		}
		return cellCount;
	},
};


/**
 * Handling for cells selected by jQuery Selectable
 * @class
 */
var JqSeletableUIHelper = {
	/**
	 * Get a list of selected cell's IDs.
	 * @return {String[]} array of IDs
	 * @public
	 */
	getSelectedCellIds: function () {
		var ids = new Array();
		$(".ui-selected").each(function() {
			ids.push(this.id);
		});
		return ids;
	},
	/**
	 * Get a list of selected cell's IDs.
	 * @return {Object[]} jQuery objects selected by jQuery selectable
	 * @public
	 */
	getSelectedCellJqObjects: function () {
		return $(".ui-selected");
	},
};


/**
 * Main sheet field processor
 * @class SheetFieldProcessor
 */
var SheetFieldProcessor = {
	/**
	 * Actions when the sheet cell is clicked
	 * @param {number} type_id - a type of field
	 * @param {String} field_data - a text of selected cells
	 * @param {String[]} selectedCellIds - IDs of selected cells
	 * @public
	 */
	setMulti: function (type_id, field_data, selectedCellIds) {
		field_data = field_data.replace(/<[^>]*>?/g, '');
		var firstCellId = $(".ui-selected:first").attr('id');
		selectedCellIds.forEach(function (id, index, ids) {
			cell_type[id] = type_id;
			SheetCell.setHtmlText(id, '<b>' + field_data + '</b>');
			SheetCell.enterSelected(id, cellBgColorManager);
		});
		var idNameForFieldList = firstCellId + "-" + MultiCells.getColSpan(selectedCellIds); // + "-" + MultiCells.getRowSpan(selectedCellIds);
		var retVal = FieldList.addOrSetContents(idNameForFieldList, field_data);
		if (retVal == true) {
			return false;
		}
		SheetFieldProcessor._add_column(
				field_data,
				idNameForFieldList,
				80,
				JqSeletableUIHelper.getSelectedCellJqObjects()
		);
	},
	/**
	 * Actions when the sheet cell is clicked
	 * @param {} target jQuery object of clicked cell
	 * // XXX: if setMulti is used this function will not be used
	 * @public
	 */
	set: function (target, field) {
		field = field.replace(/<[^>]*>?/g, '');
		var targetId = target.attr('id');
		$('#' + targetId).html('<b>' + field + '</b>');

		var retVal = FieldList.addOrSetContents(targetId, field);
		if (retVal == true) {
			return false;
		}
		SheetFieldProcessor._add_column(field, targetId, 80);
	},
	/**
	 * Actions when reset is clicked for the sheet cell
	 * @public
	 */
	resetMulti: function () {
		var fieldIDsToBeReset = {}
		var ids = JqSeletableUIHelper.getSelectedCellIds();
		ids.forEach(function (id, index, ids) {
			var selectedFieldId = id;
			cellAndFieldIdMap.getFieldId(selectedFieldId).forEach(function (fieldId, index, fieldIDs) {
				fieldIDsToBeReset[fieldId] = true;	// set dummy value
			});
		});
		for (var fieldId in fieldIDsToBeReset) {
			SheetFieldProcessor.reset(fieldId);
		};
	},
	/**
	 * Actions when reset is clicked in the field list
	 * @param {String} targetId
	 * @public
	 */
	reset: function (targetId) {
		var targettd = $('td[name="' + targetId + '"]');

		if (isset(targettd)) {
			var index = targettd.index() + 1;
			target = $('.hDivBox th:nth-child(' + index + ')');
			if (target.length) {
				SheetFieldProcessor._del_column(targettd, index);
			}
		}
		// clear click-selected
		SheetFieldProcessor._clearCells(targetId);
		var fieldIdReferredFromOtherCell = SheetFieldProcessor._getFieldIDsRefferdFromOtherCell(targetId);
		cellAndFieldIdMap.del(targetId);
		SheetFieldProcessor._redrawCellsByFieldIds(fieldIdReferredFromOtherCell);

		targetid = FieldList.applyFieldListStatusToMarkerButton();
	},
	/**
	 * @private
	 */
	_add_column: function (html, targetId, width, selectedCellObjects) {
		var tagStrippedHtml = html.replace(/<[^>]*>?/g, '');

		var fieldNumberInFieldList = FieldList.addColumn(tagStrippedHtml, targetId, width, function (newHDivThElement, newNDivTdElement) {
			newHDivThElement.hover(
				function (e) {
					cellAndFieldIdMap.get($(this).attr('name')).each(function () {
						SheetCell.clickSelected(this.id, cellBgColorManager);
						SheetCell.setHtmlText(this.id, newNDivTdElement.text());
					});
				},
				function (e) {
					cellAndFieldIdMap.get($(this).attr('name')).each(function () {
						// preserve only .enter-selected class
						SheetCell.enterSelected(this.id, cellBgColorManager);
					});
				}
			);
			// set hover event handler to emit event from cell -> field list
			selectedCellObjects.each(function() {
				$(this).hover(
					function (e) {
						newHDivThElement.mouseenter();
					},
					function (e) {
						newHDivThElement.mouseleave();
					}
				);
			});
		});
		cellAndFieldIdMap.add(targetId, selectedCellObjects);
		$('#field_list').flexReload();
		dirty = true;

		StatusMenu.MarkerButton.makeItClickable();
	},
	/**
	 * @private
	 */
	_del_column: function (target, index) {
		if (!target) {
			return false;
		}

		targetid = FieldList.del_Column(index);

		SheetCell.clearHtmlText(targetid, cellBgColorManager);
		SheetCell.notSelected(targetid, cellBgColorManager);

		FieldList.renumberHeader();

		new FieldForm().cellClear(targetid);
		dirty = true;
		$('#field_list').flexReload();

		StatusMenu.MarkerButton.makeItClickable();
	},
	/**
	 * @private
	 */
	_delColumn: function (target, idx) {
		// global
		targetid = FieldList.delColumn(idx);

		SheetCell.clearHtmlText(targetid, cellBgColorManager);
		SheetCell.notSelected(targetid, cellBgColorManager);

		FieldList.renumberHeader();

		new FieldForm().cellClear(targetid);
		$('#field_list').flexReload();
		dirty = true;

		StatusMenu.MarkerButton.makeItClickable();
	},
	/**
	 * Clear cells specified by Field ID.
	 * @param {String} fieldId - Field ID
	 * @private
	 */
	_clearCells: function (fieldId) {
		cellAndFieldIdMap.get(fieldId).each(function() {
			var targetId = $(this).attr('id');
			SheetCell.setHtmlText(targetId, '');
			SheetCell.notSelected(targetId, cellBgColorManager);
		});
	},
	/**
	 * Set text and background color for cells specified by field ID
	 * @param {String} fieldId - Field ID
	 * @private
	 */
	_redrawCells: function (fieldId) {
		var txt = FieldList.getText(fieldId);
		cellAndFieldIdMap.get(fieldId).each(function() {
			var targetId = $(this).attr('id');
			SheetCell.setHtmlText(targetId, txt);
			SheetCell.enterSelected(targetId, cellBgColorManager);
		});
	},
	/**
	 * Redray cells specified by field IDs.
	 * @param {String[]} fieldIDs - An array of Field IDs
	 * @private
	 */
	_redrawCellsByFieldIds: function (fieldIDs) {
		for (var fieldId in fieldIDs) {
			SheetFieldProcessor._redrawCells(fieldId);
		};
	},
	/**
	 * Get Field IDs refferd from other cells.
	 * @param {String} targetId - TargetID of FieldList
	 * @return {String[]} Field IDs
	 * @private
	 */
	_getFieldIDsRefferdFromOtherCell: function (targetId) {
		var fieldIdReferredFromOtherCell = {};
		cellAndFieldIdMap.get(targetId).each(function() {
			var cellId = $(this).attr('id');
			cellAndFieldIdMap.getFieldId(cellId).forEach(function (fieldId, index, origArray) {
				fieldIdReferredFromOtherCell[fieldId] = true;	// set dummy value
			});
		});
		delete fieldIdReferredFromOtherCell[targetId];
		return fieldIdReferredFromOtherCell;
	},

};

/**
 * Field's Id and Cell's Id Mapper
 * @class CellAndFieldMapper
 */
var CellAndFieldMapper = function () {
	/**
	 * selected jQuery Objects by fieldId
	 * @property {Hash} id_map
	 */
	this.id_map = {};
	/**
	 * field Id by cell Id
	 * @property {Hash} cellId2fieldId
	 */
	this.cellId2fieldId = {};
};

CellAndFieldMapper.prototype = {
	/**
	 * Store the selected jQuery object and create reverse map for query by cell Id.
	 * @param {string} field Cell's id. ex. "0-1-2-0"
	 * @param {object} jQuery objects by jQuery-select
	 * @public
	 */
	add: function(fieldId, selectedJqObjects) {
		var self = this;
		this.id_map[fieldId] = selectedJqObjects;
		JqSeletableUIHelper.getSelectedCellIds().forEach(function(id, index, ids) {
			if (typeof self.cellId2fieldId[id] == "undefined") {
				self.cellId2fieldId[id] = {};
			}
			self.cellId2fieldId[id][fieldId] = true;	// set dummy value
		});
	},
	/**
	 * Delete the entry by field Id.
	 * @param {string} field Cell's id. ex. "0-1-2-0"
	 * @public
	 */
	del: function(fieldId) {
		delete this.id_map[fieldId];
		for (var cellId in this.cellId2fieldId) {
			if (typeof this.cellId2fieldId[cellId][fieldId] != "undefined") {
				delete this.cellId2fieldId[cellId][fieldId];
			}
		}
	},
	/**
	 * Get the selected jQuery objects by field Id.
	 * @param {string} fieldId Field's id. ex. "0-1-2-0"
	 * @return {object} jQuery object
	 * @public
	 */
	get: function(fieldId) {
		var result = this.id_map[fieldId];
		if (typeof result == 'undefined') {
			// return empty object that has each" function which do nothing
			return { each: function(callback){} };
		} else {
			return result;
		}
	},
	/**
	 * Get the field Id by cell Id.
	 * @param {string} cellId Cell's id. ex. "0-1-2"
	 * @return {String[]} array of field IDs
	 * @public
	 */
	getFieldId: function(cellId) {
		if (typeof this.cellId2fieldId[cellId] != "undefined") {
			return Object.keys(this.cellId2fieldId[cellId]);
		} else {
			return new Array();
		}
	},
};


/**
 * Cell background color management
 * @class SheetCellBackgroundColor
 */
var SheetCellBackgroundColor = function () {
	/**
	 * @property {Array} cell_sw
	 */
	this.cell_sw = new Array();

	this.setBgColorFlagForAllCells();
};

SheetCellBackgroundColor.prototype = {
	/**
	 * Store flags to cell_sw where the cell's bg color is set or not
	 * @public
	 */
	setBgColorFlagForAllCells: function () {
		// 各セルの背景色を取得し格納
		var elements = document.getElementsByTagName('*');
		for (var elm_cnt = 0; elm_cnt < elements.length; elm_cnt++) {
			if (elements[elm_cnt].className == 'sheet_field') {
				var table = elements[elm_cnt];
				var tds = table.getElementsByTagName('td');
				for (var tb_cnt = 0; tb_cnt < tds.length; tb_cnt++) {
					var tbg = $(tds[tb_cnt]).css('background-color');
					var h = this.cutHex(tbg);
					if (h == tbg) {
						var rgb = (tbg == 'rgb(255, 255, 255)') ? 255 * 3 :
						(tbg == 'rgba(0, 0, 0, 0)') ? 255 * 3 :
						(tbg == 'transparent') ? 255 * 3 : 1;
					} else {
						var r = this.HexToR(tbg);
						var g = this.HexToG(tbg);
						var b = this.HexToB(tbg);
						var rgb = r + g + b;
						rgb = rgb ? rgb : 255 * 3;
					}
					this.cell_sw[tds[tb_cnt].getAttribute('id')] = (rgb == 255 * 3) ? 0 : 1;
				}
			}
		}
	},
	/**
	 * Set the information that the cell's bg color is set.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @public
	 */
	set: function (targetid) {
		this.cell_sw[targetid] = 1;
	},
	/**
	 * Clear the information that the cell's bg color is set.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @public
	 */
	clear: function (targetid) {
		this.cell_sw[targetid] = 0;
	},
	/**
	 * Get the information whether the cell's bg color is set or not.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @return {boolean}
	 * @public
	 */
	isSet: function (targetid) {
		return this.cell_sw[targetid] == 1 ? true : false;
	},
	/**
	 * @private
	 */
	HexToR: function (h) {
		return parseInt((cutHex(h)).substring(0, 2), 16);
	},
	/**
	 * @private
	 */
	HexToG: function (h) {
		return parseInt((cutHex(h)).substring(2, 4), 16);
	},
	/**
	 * @private
	 */
	HexToB: function (h) {
		return parseInt((cutHex(h)).substring(4, 6), 16);
	},
	/**
	 * @private
	 */
	cutHex: function (h) {
		return (h.charAt(0) == '#') ? h.substring(1, 7) : h;
	},
};

/**
 * Sheet Cell Operation Class
 * @class SheetCell
 */
// used also in jqcontextmenu
var SheetCell = {
	/**
	 * Make the cell's state enter-selected.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @param {} cellBgColorManager Object to SheetCellBackgroundColorManager class
	 * @return {} jQuery object
	 */
	enterSelected: function (targetid, cellBgColorManager) {
		cellBgColorManager.set(targetid);
		$('#' + targetid).removeClass('not-selected');
		$('#' + targetid).removeClass('click-selected');
		return $('#' + targetid).addClass('enter-selected');
	},
	/**
	 * Make the cell's state click-selected.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @param {} cellBgColorManager Object to SheetCellBackgroundColorManager class
	 */
	clickSelected: function (targetid, cellBgColorManager) {
		if (cellBgColorManager.isSet(targetid)) {
			//$("#" + targetid).removeClass('not-selected');
			$("#" + targetid).removeClass('enter-selected');
			$("#" + targetid).addClass('click-selected');
		}
		//cellBgColorManager.set();
	},
	/**
	 * Make the cell's state not-selected.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @param {} cellBgColorManager Object to SheetCellBackgroundColorManager class
	 */
	notSelected: function (targetid, cellBgColorManager) {
		$('#' + targetid).removeClass('enter-selected');
		$('#' + targetid).removeClass('click-selected');
		$('#' + targetid).addClass('not-selected');
		cellBgColorManager.clear(targetid);
	},
	/**
	 * Set the cell's contents.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @param {string} text Html text
	 * @return {} jQuery object
	 */
	setHtmlText: function (targetid, html) {
		return $('#' + targetid).html(html);
	},
	/**
	 * Clear the cell's contents.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @return {} jQuery object
	 */
	clearHtmlText: function (targetid) {
		return $('#' + targetid).html('');
	},
};

/**
 * Status menu class
 * @class StatusMenu
 */
var StatusMenu = {
	/**
	 * Marker button class
	 * @class MarkerButton
	 */
	MarkerButton: {
		/**
		 * Make the button clickable
		 */
		makeItClickable: function() {
			$('.statusMenu .marker button').attr('disabled', false);
			$('.statusMenu .marker').removeClass('disable');
		},
		/**
		 * Make the button un-clickable
		 */
		makeItUnClickable: function() {
			$('.statusMenu .marker button').attr('disabled', true);
			$('.statusMenu .marker').addClass('disable');
		},
		/**
		 * Get whether the marker button is UNclickable or not.
		 * @return {boolean}
		 */
		isUnClickable: function() {
			return $('.statusMenu .marker button').attr('disabled');
		},
		setCallbackHandler: function (type, callback) {
			return $('.statusMenu .marker button').bind(type, callback);
		}
	},
	ReloadButton: {
		/**
		 * Go to the page of reselecting an excel file
		 */
		reloadSheetExcelFile: function() {
			var gid = $("#form-status input[name=gid]").val();
			var sid = $("#form-status input[name=sid]").val();
			location.href = "/external/sheet/" + gid + "/" + sid + "/";
		},

	},
};

/**
 * Field form handler for field list
 * @class FieldForm
 */
var FieldForm = function () {
	this.form = $('form#form-save');
};

FieldForm.prototype = {
	cellClear: function (targetid) {
		var cmd_c = '<input type="hidden" name="cell-' + targetid + '-clear" value="" />';
		return this.form.append(cmd_c);
	},
	cellMark: function (targetid, txt) {
		var cmd_m = '<input type="hidden" name="cell-' + targetid + '-mark" value="' + txt + '" />';
		return this.form.append(cmd_m);
	},
	cellType: function (targetid, txt, type) {
		var cmd_f = '<input type="hidden" name="field-' + targetid + '-' + type + '" value="' + txt + '" />';
		return this.form.append(cmd_f);
	},
	setSelectedDataInJson: function (json) {
		var cmd_f = '<input type="hidden" name="selectedFieldData" value=\'' + json + '\' />';
		return this.form.append(cmd_f);
	},
	/**
	 * Submit the form
	 * @public
	 */
	submit: function () {
		this.packAllFieldInfoToInputTags();
		return this.form.submit();
	},
	/**
	 * @private
	 */
	packAllFieldInfoToInputTags: function () {
		var self = this;
		var saveJson = {};
		FieldList.traverseItems(function (fieldname, txt) {
			var type;
			var firstCellId = CellIdManipulator.getGeneralId(fieldname);
			if (fieldname == "0")
				return;
			if (typeof(cell_type[firstCellId]) == 'undefined') {
				type = 1;
			} else if (cell_type[firstCellId] != -1) {
				type = cell_type[firstCellId];
			} else {
				return;
			}

			txt = txt.replace(/<\s*script[^>]*>[\s\S]*?<\s*\/script>/ig, '');
			txt = $.escapeHTML(txt);

			cellAndFieldIdMap.get(fieldname).each(function () {
				self.cellMark(this.id, txt);
				self.cellType(this.id, txt, type);
			});
			saveJson[fieldname] = {};
			saveJson[fieldname]['type'] = type;
			saveJson[fieldname]['data'] = txt;
			saveJson[fieldname]['cellIDs'] = new Array();
			cellAndFieldIdMap.get(fieldname).each(function () {
				saveJson[fieldname]['cellIDs'].push(this.id);
			});
		});
		self.setSelectedDataInJson(JSON.stringify(saveJson));
	},
};

/**
 * Provide operations for field list
 * @class FieldList
 */
var FieldList = {
	/**
	 * Initialize
	 */
	init: function () {
		$('#field_list td').keydown(FieldList._key_events_in_field_list);
		return FieldList.applyFieldListStatusToMarkerButton();
	},
	/**
	 * Change the status of marker button according to the number of columns of field list.
	 */
	applyFieldListStatusToMarkerButton: function () {
		var targetTDs = $('#field_list td');
		var targetid = targetTDs.attr('name');
		if (targetTDs.length == 1 && targetid == 0) {
			// if field list contains only 1 column.
			StatusMenu.MarkerButton.makeItUnClickable();
		} else {
			StatusMenu.MarkerButton.makeItClickable();
		}
		return targetid;
	},
	/**
	 * Add a new column to field list.
	 * @param {string} html html text to be set as a content
	 * @param {string} targetid
	 * @param {number} width width of the contents
	 * @param {object} callback a callback function to handle for newly created hdiv element
	 * @return {number} field number of field list
	 * @public
	 */
	addColumn: function (html, targetid, width, callback) {
		var num;

		var dupColumn = function (origElement, callback) {
			var cloned = origElement.clone(true);
			callback(origElement, cloned);
			origElement.after(cloned);
			return cloned;
		};

		dupColumn($('.nDiv tr:last'), function () {});
		dupColumn($('.cDrag div:last'), function () {});

		num = $('.hDiv th').length + 1;
		var newHDivThElement = dupColumn($('.hDiv th:last'), function (origElement, newElement) {
			newElement.attr('name', targetid);
			newElement.wrapInner(document.createElement('div'));
			newElement.find('div').css('width', width + 'px').text(num);
		});

		var newBDivTdElement = dupColumn($('.bDiv td:last'), function (origElement, newElement) {
			newElement.attr('name', targetid);
			newElement.wrapInner(document.createElement('div'));
			newElement.find('div').css('width', width + 'px').html(html); // ここが効く
		});
		callback(newHDivThElement, newBDivTdElement);
		return num;
	},
	/**
	 * Delete a column in the field list.
	 * @param {number} idx index of the field list set in TD tag.
	 * @return {string} the ID name of removed field
	 * @public
	 */
	delColumn: function (idx) {
		var targettd = $('#field_list td').eq(idx);
		var fieldName = targettd.attr('name');

		// idx starts from 0
		$('.nDiv tr').eq(idx).remove();
		$('.cDrag div').eq(idx).remove();
		$('.hDiv th').eq(idx).remove();
		targettd.remove();

		return fieldName;
	},
	/**
	 * Delete a column in the field list.
	 * @param {number} index index of the field list set in TD tag.
	 * @return {string} the ID name of removed field
	 * @public
	 */
	del_Column: function (index) {
		// index starts from 1
		$('.nDiv tr:nth-child(' + index + ')').remove();
		$('.cDrag div:nth-child(' + index + ')').remove();
		$('.hDiv th:nth-child(' + index + ')').remove();
		var targettd = $('#field_list td:nth-child(' + index + ')');
		var targetid = targettd.attr('name');
		targettd.remove();
		return targetid;
	},
	/**
	 * Set a content to the specified field.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @param {string} contents A text string of contents
	 * @return {boolean} true: if success, false: if failed
	 * @public
	 */
	addOrSetContents: function (targetid, contents) {
		var targettd = $('td[name="' + targetid + '"]');
		if (targettd.length) {	// set contents if exists
			targettd.find('div').text(contents);
			return true;
		}
		return false;
	},
	/**
	 * Get a content of the specified field.
	 * @param {string} targetid Cell's id. ex. "0-1-2"
	 * @return {string} a text
	 * @public
	 */
	getText: function (targetid) {
		return $('td[name="' + targetid + '"]').text();
	},
	/**
	 * Renumber the header of field list
	 * @public
	 */
	renumberHeader: function () {
		var ths = $('.hDiv th'); // All columns of field list's header
		ths.each(function(index) {	// index starts from 0
			// To display the number from 1, increment the number
			$(this).find('div:first').text(++index);
		});
	},
	/**
	 * Do some actions for all field
	 * @param {} callback function to apply to each field list's element
	 * @public
	 */
	traverseItems: function (callback) {
		$('#field_list td').each(function() {
			var fieldname = $(this).attr('name');
			var txt = $(this).text();
			return callback(fieldname, txt);
		});
	},
	/**
	 * Show text input field to edit
	 */
	editContents: function () {
		if ($(this).hasClass('on')) {
			return;
		}

		$(this).addClass('on');
		// get current contents and attributes
		var txt = $(this).text(),
		    html =  $(this).html(),
		    width = $(this).width(),
		    height = $(this).height(),
		    fsize = $(this).css('font-size'),
		    nlines = height / 16 | 0; // int conversion
		// remove html tags
		txt = txt.replace(/<[^>]*>?/g, '');
		// show text input small window
		$(this).html('<input type="text" id="active" value="'
			+ txt
			+ '" size="'
			+ txt.length * 2
			+ '" style="width:'
			+ width
			+ 'px; font-size:'
			+ fsize
			+ '; " />'
		);

		// prepare for closing the small window when being unfocused
		var target = $('#active');
		target.focus();
		target.blur(function() {
			// set the user input with <div> tag.
			var inputVal = $(this).val();
			targetid = $(this).parent().attr('name');
			width = width - 10;
			inputVal = inputVal.replace(/<[^>]*>?/g, '');
			var htmlval = inputVal.replace(/(\\n)/g, '<br />');
			$(this).parent().removeClass('on')
			    .html('<div style="width: ' + width + 'px" >' +
				  htmlval + '</div>');

			// update the corresponding sheet cell
			cellAndFieldIdMap.get(targetid).each(function() {
				SheetCell.setHtmlText(this.id, '<b>' + inputVal + '</b>');
			});
			// update marker button.
			StatusMenu.MarkerButton.makeItClickable();
		});
		target.keydown(function(e) {
			if (e.keyCode == 13) {
				target.blur();
			}
		});
	},
	getFocusedFieldObject: function () {
		return $('#active');
	},
	/**
	 * Move the focus next
	 * @public
	 */
	moveFocusNext: function () {
		var currentFocused = FieldList.getFocusedFieldObject();
		var nextField = currentFocused.parent().next('td:first');
		return FieldList.moveFocus(currentFocused, nextField);
	},
	/**
	 * Move the focus previous
	 * @public
	 */
	moveFocusPrev: function () {
		var currentFocused = FieldList.getFocusedFieldObject();
		var nextField = currentFocused.parent().prev();
		return FieldList.moveFocus(currentFocused, nextField);
	},
	/**
	 * Move the focus next
	 * @private
	 */
	moveFocus: function (currentFocusedField, nextField) {
		if (nextField.length) { // if found
			currentFocusedField.blur();
			nextField.click();
			return false;
		}
	},
	/**
	 * Key event handler
	 * @private
	 */
	_key_events_in_field_list: function (e) {
		var keycode = e.which;
		var shift = (typeof e.modifiers == 'undefined') ?
		    e.shiftKey : e.modifiers & Event.SHIFT_MASK;
		if (keycode == '9') {	// Tab key
			if (shift) {
				return FieldList.moveFocusPrev();
			} else {
				return FieldList.moveFocusNext();
			}
		}
	},
};

var SHEET = SHEET || {};// namespace

SHEET = {
	setFlexiInSetup: function() {// set flexigrid in form-setup.php
		$('#field_list').flexigrid({
			showToggleBtn:false,
			resizable:false,
			height:'auto',
			onDragCol: function() {
				var ths = $('.hDiv th');
				ths.each(function(num) {
					var th = $(this);
					th.find('div:first').text(++num);
				});
			}
		});

		$.contextMenu({
			selector: '.hDivBox th',
			trigger: 'left',
			items: {
				'reset': {
					name:'リセット',
					icon:'delete',
					callback: function (key, options) {
						// get the name of target id
						var targetId = $('#field_list td').eq(options.$trigger.index()).attr('name');
						SheetFieldProcessor.reset(targetId); // XXX: may be jquery object instead of targetId?
					},
				},
			},

		});
		$('#field_list td').click(FieldList.editContents);

		$('#bt-password').click(function() {
			$.jqDialog.password('パスワードを入力して下さい', function(data) {
				$('#passwd').val(data);
				new FieldForm().submit();
				$('#form-status').attr('action', 'form-commit.php?start');
				$('#form-status').submit();
			});
		});
	}
};

// vim: set noet fenc=utf-8 ff=unix sts=0 sw=8 ts=8 :
