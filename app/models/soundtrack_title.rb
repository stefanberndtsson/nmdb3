class SoundtrackTitle < ActiveRecord::Base
  belongs_to :movie
  has_many :soundtrack_title_data
end
