class MovieYear < ActiveRecord::Base
  belongs_to :movie
  
  def self.year_min
    return 1888
    @@year_min ||= MovieYear.select("min(convert_to_integer(year))").where("convert_to_integer(year) > 0").first.min.to_i
  end

  def self.year_max
    return 2016
    @@year_max ||= MovieYear.select("max(convert_to_integer(year))").where("convert_to_integer(year) > 0").first.max.to_i
  end
end
