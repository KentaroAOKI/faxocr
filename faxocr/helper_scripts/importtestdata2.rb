#!/usr/bin/ruby

require File.expand_path('../../config/boot',  __FILE__)
require "rubygems"
require "active_record"
require "yaml"

config_db = RAILS_ROOT + "/config/database.yml"
db_env = "development"

GROUP_NAME1 = '沖縄県新型インフルエンザ小児医療情報ネットワーク'
SHEET_CODE1 = "00000"

ActiveRecord::Base.configurations = YAML.load_file(config_db)
ActiveRecord::Base.establish_connection(db_env)

Dir.glob(RAILS_ROOT + '/app/models/*.rb').each do |model|
  load model
end

survey = Survey.find_by_id(3)

SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'accept_child', :ocr_name_full => '小児重症患者受入可否', :view_order => 60, :data_type => 'rating').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'flu_adult', :ocr_name_full => '成人の新型インフルエンザ', :view_order => 40, :data_type => 'number').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'no_ventilator_child', :ocr_name_full => '小児の新型インフルエンザ以外・人工呼吸器未使用', :view_order => 30, :data_type => 'number').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'remarks', :ocr_name_full => '備考', :view_order => 80, :data_type => 'ascii+:jpn').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'controled_child', :ocr_name_full => '小児科病棟で管理中の長期人工呼吸器ケア症例数', :view_order => 70, :data_type => 'number').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'flu_child', :ocr_name_full => '小児の新型インフルエンザ', :view_order => 10, :data_type => 'number').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'other_adult', :ocr_name_full => '成人の新型インフルエンザ以外', :view_order => 50, :data_type => 'number').save
SurveyProperty.new(:survey_id => survey.id, :ocr_name => 'ventilator_child', :ocr_name_full => '小児の新型インフルエンザ以外・人工呼吸器使用', :view_order => 20, :data_type => 'number').save

sheet = Sheet.new
sheet.sheet_code = SHEET_CODE1
sheet.sheet_name = "Version1"
sheet.survey_id = survey.id
sheet.block_width = 20
sheet.block_height = 12
sheet.status = 1
sheet.save

SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('accept_child').id, :position_x => '12', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('flu_adult').id, :position_x => '8', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('no_ventilator_child').id, :position_x => '6', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('remarks').id, :position_x => '16', :position_y => '9', :colspan => 4, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('controled_child').id, :position_x => '14', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('flu_child').id, :position_x => '2', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('other_adult').id, :position_x => '10', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save
SheetProperty.new(:survey_property_id => SurveyProperty.find_by_ocr_name('ventilator_child').id, :position_x => '4', :position_y => '9', :colspan => 2, :sheet_id => sheet.id).save

cands = []
cands << ['00002','県立北部病院','098-052-2719','098-052-2719']
cands << ['00004','中頭病院','939-1300','939-1300']
cands << ['00005','県立中部病院','973-4111','973-4111']
cands << ['00020','琉球大学付属病院','895-3331','895-3331']
cands << ['00022','那覇市立病院','884-5111','884-5111']
cands << ['00024','沖縄協同病院','853-1200','853-1200']
cands << ['00025','沖縄赤十字病院','853-3134','853-3134']
cands << ['00040','県立南部医療センター ・こども医療センター','888-0123','888-0123']
cands.each do |cand|
  candidate = Candidate.new
  candidate.candidate_code = cand[0]
  candidate.candidate_name = cand[1]
  candidate.group_id = group.id
  candidate.tel_number = cand[2]
  candidate.fax_number = cand[3]
  candidate.save
  survey_candidate = SurveyCandidate.new
  survey_candidate.survey_id = survey.id
  survey_candidate.candidate_id = candidate.id
  survey_candidate.save
end

Process.exit

answer_sheet = AnswerSheet.new
answer_sheet.date = "20100209135005"
answer_sheet.sheet_id = sheet.id
answer_sheet.candidate_id = candidate.id
answer_sheet.sender_number = "0987777777"
answer_sheet.receiver_number = "0399999999"
answer_sheet.sheet_image = "path/to/image1"
answer_sheet.need_check = TRUE
props = []
props << ['no_ventilator_child','17','R0471518987/S0368931064/20100208135005/blockImg-no_ventilator_child.png']
props << ['flu_adult','11','R0471518987/S0368931064/20100208135005/blockImg-flu_adult.png']
props << ['accept_child','1','R0471518987/S0368931064/20100208135005/blockImg-accept_child.png']
props << ['controled_child','7','R0471518987/S0368931064/20100208135005/blockImg-controled_child.png']
props << ['flu_child','4','R0471518987/S0368931064/20100208135005/blockImg-flu_child.png']
props << ['remarks','','R0471518987/S0368931064/20100208135005/blockImg-remarks.png']
props << ['other_adult','8','R0471518987/S0368931064/20100208135005/blockImg-other_adult.png']
props << ['ventilator_child','9','R0471518987/S0368931064/20100208135005/blockImg-ventilator_child.png']
props.each do |prop|
  answer_sheet_property = AnswerSheetProperty.new
  answer_sheet_property.ocr_name = prop[0]
  answer_sheet_property.ocr_value = prop[1]
  answer_sheet_property.ocr_image = prop[2]
  answer_sheet.answer_sheet_properties << answer_sheet_property
end
answer_sheet.save

answer_sheet = AnswerSheet.new
answer_sheet.date = "20100209153000"
answer_sheet.sheet_id = sheet.id
answer_sheet.candidate_id = candidate.id
answer_sheet.sender_number = "0987777777"
answer_sheet.receiver_number = "0399999999"
answer_sheet.sheet_image = "path/to/image2"
props = []
props << ['no_ventilator_child','17','R0471518987/S0368931064/20100208135005/blockImg-no_ventilator_child.png']
props << ['flu_adult','11','R0471518987/S0368931064/20100208135005/blockImg-flu_adult.png']
props << ['accept_child','1','R0471518987/S0368931064/20100208135005/blockImg-accept_child.png']
props << ['controled_child','7','R0471518987/S0368931064/20100208135005/blockImg-controled_child.png']
props << ['flu_child','4','R0471518987/S0368931064/20100208135005/blockImg-flu_child.png']
props << ['remarks','','R0471518987/S0368931064/20100208135005/blockImg-remarks.png']
props << ['other_adult','8','R0471518987/S0368931064/20100208135005/blockImg-other_adult.png']
props << ['ventilator_child','9','R0471518987/S0368931064/20100208135005/blockImg-ventilator_child.png']
props.each do |prop|
  answer_sheet_property = AnswerSheetProperty.new
  answer_sheet_property.ocr_name = prop[0]
  answer_sheet_property.ocr_value = prop[1]
  answer_sheet_property.ocr_image = prop[2]
  answer_sheet.answer_sheet_properties << answer_sheet_property
end
answer_sheet.save

