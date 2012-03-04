class Role < ActiveRecord::Base
  GROUP_CAST=1
  GENDER_MALE=1
  GENDER_FEMALE=2
  
  has_many :occupations
end
