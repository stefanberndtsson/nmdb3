class ReleaseDate < ActiveRecord::Base
  belongs_to :movie
  
  def display
    ([release_date, "(#{country})", info]-["()"]-[nil]).join(" ")
  end
  
  def to_i
    release_stamp.to_i
  end
end
