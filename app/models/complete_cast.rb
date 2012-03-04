class CompleteCast < ActiveRecord::Base
  belongs_to :movie
  belongs_to :complete_cast_status
end
