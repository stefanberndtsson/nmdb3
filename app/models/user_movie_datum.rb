class UserMovieDatum < ActiveRecord::Base
  belongs_to :user
  belongs_to :movie
  
  def self.set(user, movie, key, value = nil, match_case = false)
    check_entry = get(user, movie, key, value, match_case)
    return check_entry if !check_entry.blank?
    movie_id = movie.id if movie.class == Movie
    movie_id = movie if movie.class == Fixnum
    user.user_movie_data.create(:movie_id => movie_id, :key => key, :value => (value.nil? ? true : value))
  end

  def self.del(user, movie, key, value = nil, match_case = false)
    check_entry = get(user, movie, key, value, match_case)
    return nil if check_entry.blank?
    check_entry.each do |entry|
      entry.destroy
    end
  end
  
  def self.get(user, movie, key, match_value = nil, match_case = false)
    check_entry = user.user_movie_data.where(:key => key).includes(:movie).joins(:movie)
    if movie
      check_entry = check_entry.where(:movie_id => movie)
    end
    
    if match_value
      if match_case || match_value.class != String
        check_entry = check_entry.where(:value => match_value)
      else
        check_entry = check_entry.where(["lower(value) = ?", match_value.downcase])
      end
    end
    return check_entry
  end
end
