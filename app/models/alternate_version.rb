class AlternateVersion < ActiveRecord::Base
  belongs_to :movie
  belongs_to :main, :class_name => "AlternateVersion", :foreign_key => :parent_id
  has_many :versions, :foreign_key => :parent_id, :class_name => "AlternateVersion"
end
