class User < ActiveRecord::Base
  validates_uniqueness_of :username
  validates_presence_of :username
  validates_presence_of :name
  validate :check_pass
  has_many :user_movie_data
  has_many :user_settings
  attr_reader :seen
  attr_reader :owns
  attr_accessor :verify_password
  
  def self.encrypt_password(password, salt = nil)
    if salt.nil?
      salt = Digest::MD5.hexdigest(Time.now.to_f.to_s)[0..7]
    end
    "$1$#{salt}$#{Digest::MD5.hexdigest(Digest::MD5.hexdigest(password)+salt)}"
  end
  
  def self.verify_password(input_username, input_password)
    user = User.find_by_username(input_username)
    return nil if user.nil?
    return user if encrypt_password(input_password, user.salt) == user.password
    return nil
  end
  
  def salt
    return nil if !password
    password.split("$")[2]
  end
  
  def generate_api_key
    
  end
  
  def has_session?(session)
    return false if session.nil? || session.empty?
    RCache.exists?("user_session:#{self.id}:#{session}") ? true : false
  end
  
  def generate_session
    session = Digest::MD5.hexdigest((rand(Time.now.to_f)+Time.now.to_f).to_s)
    RCache.set("user_session:#{self.id}:#{session}", true, 2.days)
    session
  end
  
  def clear_session(session)
    RCache.del("user_session:#{self.id}:#{session}")
  end
  
  def refresh_session(session)
    RCache.expire("user_session:#{self.id}:#{session}", 2.days)
  end
  
  def load_movie_statuses
#    @seen = Movie.where("id IN (#{user_movie_data.where(:key => "seen").select(:movie_id).to_sql})")
#    @owns = Movie.where("id IN (#{user_movie_data.where(:key => "owns").select(:movie_id).to_sql})")
    true
  end

  def get_data_count(key)
    UserMovieDatum.get(self, nil, key, true).count
  end
  
  def set_movie_data(movie, key, value, match_case = false)
    UserMovieDatum.set(self, movie, key, value, match_case)
  end
  
  def get_movie_data(movie, key)
    UserMovieDatum.get(self, movie, key)
  end
  
  def get_movie_toggle_data(movie, key)
    UserMovieDatum.get(self, movie, key, true)
  end
  
  def del_movie_data(movie, key)
    UserMovieDatum.del(self, movie, key)
  end

  def toggle_movie_data(movie, key)
    umd = get_movie_data(movie, key).first
    status = nil
    if !umd
      status = true
      set_movie_data(movie, key, status)
    else
      status = (umd.value == "t")
      status = !status
      umd.value = status
      umd.save
    end
    load_movie_statuses
    status
  end
  
  def set_tag(movie, tag_name)
    UserMovieDatum.set(self, movie, "tag", tag_name)
  end
  
  def set_seen(movie)
    UserMovieDatum.set(self, movie, "seen")
    load_movie_statuses
  end

  def set_owns(movie)
    UserMovieDatum.set(self, movie, "owns")
    load_movie_statuses
  end
  
  def del_tag(movie, tag_name)
    UserMovieDatum.del(self, movie, "tag", tag_name)
  end
  
  def del_seen(movie)
    UserMovieDatum.del(self, movie, "seen")
    load_movie_statuses
  end

  def del_owns(movie)
    UserMovieDatum.del(self, movie, "owns")
    load_movie_statuses
  end
  
  def get_tags(movie = nil)
    UserMovieDatum.get(self, movie, "tag")
  end
  
  def get_tag(movie, tag_name)
    UserMovieDatum.get(self, movie, "tag", tag_name)
  end
  
  def get_seen(movie)
    UserMovieDatum.get(self, movie, "seen")
  end
  
  def get_owns(movie)
    UserMovieDatum.get(self, movie, "owns")
  end
  
  def get_movie_toggle_status(movie, key)
    umd = get_movie_toggle_data(movie, key)
    return "false" if !umd || !umd.first
    return "true" if umd.first.value == "t"
    return "false"
  end
  
  def has_toggle?(type)
    !get_movie_toggle_data(nil, type).first.nil?
  end

  def has_unseen_owns?
    seen = get_movie_toggle_data(nil, "seen").select(:movie_id)
    movielist = get_movie_toggle_data(nil, "owns").
      where("movie_id NOT IN (#{seen.to_sql})")
    !movielist.first.nil?
  end

  def show_scores?
    show_scores
  end
  
  def show_autocomplete?
    show_autocomplete
  end
  
  def show_setting(key)
    user_settings.where(:key => key).where(:value => "t").count != 0
  end
  
  def show_seen
    show_setting("show_seen")
  end

  def show_owns
    show_setting("show_owns")
  end

  def show_wish
    show_setting("show_wish")
  end

  def show_unwish
    show_setting("show_unwish")
  end

  def show_error
    show_setting("show_error")
  end

  def show_scores
    show_setting("show_scores")
  end
  
  def show_autocomplete
    show_setting("show_autocomplete")
  end
  
  def button_count
    count = 0
    ["seen", "owns", "wish", "error", "unwish"].each { |x| count += 1 if show_setting("show_"+x) }
    count
  end
  
  private
  def check_pass
    if new_record? && password.blank?
      errors.add(:password, "Error in password")
      errors.add(:verify_password, "Error in password")
    end
  end
end
