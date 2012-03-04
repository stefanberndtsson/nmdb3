class PersonMetadatum < ActiveRecord::Base
  belongs_to :person

  def self.pages
    {
      "biography" => { 
        :keys => ["DB", "DD", "RN", "NK", "HT", "BG", "SP", "TM", "WN", "SA"]
      },
      "trivia" => { 
        :keys => ["TR"]
      },
      "quotes" => { 
        :keys => ["QU"]
      },
      "other_works" => { 
        :keys => ["OW"]
      },
      "publicity" => { 
        :keys => ["BT", "PI", "BO", "IT", "AT", "PT", "CV"]
      }
    }
  end
end
