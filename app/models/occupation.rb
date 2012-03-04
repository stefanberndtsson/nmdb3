class Occupation < ActiveRecord::Base
  belongs_to :movie
  belongs_to :person
  belongs_to :role
  
  def display
    ([character, extras]-[nil]).join(" ")
  end
end
