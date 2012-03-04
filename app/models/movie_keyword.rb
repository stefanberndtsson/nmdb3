class MovieKeyword < ActiveRecord::Base
  belongs_to :movie
  belongs_to :keyword
end
