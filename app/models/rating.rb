class Rating < ActiveRecord::Base
  belongs_to :movie
  
  def self.rating_min
    return 10
  end

  def self.rating_max
    return 100
  end
end
