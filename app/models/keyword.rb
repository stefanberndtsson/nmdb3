class Keyword < ActiveRecord::Base
  has_many :movie_keywords
  has_many :movies, :through => :movie_keywords
  attr_accessor :strong
  
  def display
    kw = keyword
    keepdash.each do |kd|
      if kw.index(kd)
        kdrepl = kd.gsub(/-/, "\t")
        kw.gsub!(kd, kdrepl)
      end
    end
    forcenext = true
    lastword = ""
    text = kw.split("-").map do |word|
      matchword = word.downcase.gsub(/[^a-z0-9]/, "")
      tmp = word
      if allup.include?(matchword) || allup.include?(word)
        tmp = word.upcase
      elsif forcenext || !stopwords.include?(matchword)
        if ["a", "de"].include?(lastword) == false || ["la"].include?(word) == false
          tmp = word.capitalize
        end
      end
      if word[-1..-1] == ","
        forcenext = false
      else
        forcenext = false
      end
      lastword = word
      tmp.gsub(/\t/, "-")
    end.join(" ")
    
    text
  end
  
  def stopwords
    ["a","an","and","are","as","at",
     "be","but","by","for","if","in",
     "into","is","it","no","not","of",
     "on","or","s","such","t","that",
     "the","their","then","there",
     "these","they","this","to","was",
     "will","with","de"]
  end
  
  def keepdash
    # Order is relevant
    ["mini-series", "non-fiction", "in-laws", "-in-law", "in-law", "x-ray"]
  end
  
  def allup
    ["tv", "vcr", "u.s.", "uk", "usa", "ussr", "d.c.", "nyc", "l.a.", "cia", "fbi", "nsa", "ak"]
  end
end
