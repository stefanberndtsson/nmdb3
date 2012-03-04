class Quote < ActiveRecord::Base
  belongs_to :movie
  has_many :quote_data
end
