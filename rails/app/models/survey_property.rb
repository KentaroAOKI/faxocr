# -*- coding: utf-8 -*-

class SurveyProperty < ActiveRecord::Base
  belongs_to :survey
  DATA_TYPE = [["数字", "number"], ["○△×", "rating"], ["画像", "image"], ["英字（小文字）", "alphabet_lowercase"], ["英字（大文字）", "alphabet_uppercase"], ["英数字", "alphabet_number"]]

  validates_uniqueness_of :ocr_name, :scope => "survey_id"

  def printable_data_type
    data_type = self.data_type
    string = ""
    if /number/ =~ data_type
      string += "数字"
    end
    if /rating/ =~ data_type
      string += "○△×"
    end
    if /image/ =~ data_type
      string += "画像"
    end
    if /alphabet_lowercase/ =~ data_type
      string += "英字（小文字）"
    end
    if /alphabet_uppercase/ =~ data_type
      string += "英字（大文字）"
    end
    if /alphabet_number/ =~ data_type
      string += "英数字"
    end
    return string
  end
end
