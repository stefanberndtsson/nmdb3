class Technical < ActiveRecord::Base
  belongs_to :movie
  
  def self.sort_value(key)
    key_list = ["CAM", "LAB", "MET", "OFM", "PCS", "PFM", "RAT"]
    return 9999 if !key_list.include?(key)
    return key_list.index(key)
  end
end
