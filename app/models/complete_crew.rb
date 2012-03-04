class CompleteCrew < ActiveRecord::Base
  belongs_to :movie
  belongs_to :complete_crew_status
end
