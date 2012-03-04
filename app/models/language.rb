class Language < ActiveRecord::Base
  has_many :movie_languages
  has_many :movies, :through => :movie_languages
  
  def self.lang_id(lang_name)
    @@lang_id ||= { }
    @@lang_id[lang_name] ||= Language.find_by_language(lang_name)
  end
end
