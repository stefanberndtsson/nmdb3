class UserController < ApplicationController
  layout "nmdb"
  before_filter :setup, :except => [:login, :verify_login, :just_bounce, :register, :create]
  
  def login
    @timer = { :start => Time.now }
    @bounceback = params[:bounceback] || search_path
    @forced_redirect_from = params[:fr]
  end

  def logout
    user_id = cookies['user_id']
    bounceback = params[:bounceback] || search_path
    user = User.find_by_id(user_id)
    if user.nil?
      redirect_to :action => 'login', :bounceback => bounceback
    else
      user.clear_session(cookies['session_id'])
      redirect_to bounceback
    end
  end
  
  def verify_login
    username = params[:user][:username]
    password = params[:user][:password]
    bounceback = params[:bounceback]
    forced_redirect_from = params[:fr]
    user = User.verify_password(username, password)
    if user.nil?
      redirect_to :action => 'login', :bounceback => bounceback, :fr => forced_redirect_from
    else
      if !(user.has_session?(cookies['session_id']) && cookies['user_id'] == user.id)
        cookies['session_id'] = { :value => user.generate_session, :expires => 20.years.from_now.utc }
        cookies['user_id'] = { :value => user.id, :expires => 20.years.from_now.utc }
      end
      if forced_redirect_from.blank?
        redirect_to bounceback
      else
        redirect_to forced_redirect_from
      end
    end
  end

  def save
    @user.name = params[:user][:name]
    @user.username = params[:user][:username]
    if !params[:user][:password].blank?
      if params[:user][:password] == params[:user][:verify_password]
        @user.password = User.encrypt_password(params[:user][:password])
      end
    end
    ["show_seen", "show_owns", "show_wish", "show_error", "show_scores", "show_unwish", "show_autocomplete"].each do |key|
      setting = @user.user_settings.find_by_key(key) || @user.user_settings.new(:key => key)
      setting.value = (params[:user][key] == "1") ? "t" : "f"
      setting.save
    end
    redirect_to :action => :profile
  end

  def register
    @timer = { :start => Time.now }
  end
  
  def create
    bounceback = params[:bounceback]
    @user = User.new
    @user.name = params[:user][:name]
    @user.username = params[:user][:username]
    if !params[:user][:password].blank?
      if params[:user][:password] == params[:user][:verify_password]
        @user.password = User.encrypt_password(params[:user][:password])
      end
    end
    if !@user.save
      render :action => 'register', :bounceback => bounceback
      return
    end
    redirect_to bounceback
  end
  
  def just_bounce
    @bounceback = params[:bounceback] || search_path
    redirect_to @bounceback
  end
  
  def toggle_movie_data
    @movie = Movie.find_by_id(params[:movie_id])
    @key = params[:key]
    if @key
      @user.toggle_movie_data(@movie, @key)
    end
    render :partial => 'user/ajax_toggle_data', :locals => { :user => @user, :movie => @movie, :key => @key }
  end
  
  def set_movie_data
    @movie = Movie.find_by_id(params[:movie_id])
    key = params[:key]
    value = params[:value]
    @umd = @user.set_movie_data(@movie, key, value)
  end
  
  def get_movie_data
    
  end
  
  def wishlist
    movielist = @user.get_movie_toggle_data(nil, "wish")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end

  def unwishlist
    movielist = @user.get_movie_toggle_data(nil, "unwish")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end

  def seen
    movielist = @user.get_movie_toggle_data(nil, "seen")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end
  
  def owns
    movielist = @user.get_movie_toggle_data(nil, "owns")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end
  
  def error
    movielist = @user.get_movie_toggle_data(nil, "error")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end
  
  def unseen_owns
    seen = @user.get_movie_toggle_data(nil, "seen").select(:movie_id)
    movielist = @user.get_movie_toggle_data(nil, "owns").
      where("user_movie_data.movie_id NOT IN (#{seen.to_sql})")
    @movielist = extract_unparented_episodes(movielist).paginate(:per_page => 30, :page => params[:page])
  end
  
  private
  def extract_unparented_episodes(movielist)
    episodes = movielist.where(:movies => { :is_episode => true })
    non_episodes = movielist.where(:movies => { :is_episode => false }).select(:movie_id)
    to_be_removed_episodes = episodes.where("movies.parent_id IN (#{non_episodes.to_sql})").select(:movie_id)
    movielist.where("user_movie_data.movie_id NOT IN (#{to_be_removed_episodes.to_sql})").
      order(sort_value).
      includes(:movie).joins(:movie).
      includes(:movie => :movie_akas)
  end

  def sort_value
    return "user_movie_data.updated_at DESC" if !params[:sort] || !params[:direction]
    (params[:sort] || "") + " " + (params[:direction] || "")
  end
  
  def setup
    @timer = { :start => Time.now }
    @user = User.find_by_id(params[:user_id] || cookies['user_id'])
    if @user.nil? || !@user.has_session?(cookies['session_id'])
      redirect_to :action => 'login', :bounceback => params[:bounceback], :fr => request.request_uri
      return
    end
    @all_data = @user.user_movie_data.where(:value => true).group_by do |x|
      x.key
    end
    @user.buttons.each do |button|
      @all_data[button] = [] if !@all_data.keys.include?(button)
    end
    @all_data.keys.each do |key|
      @all_data[key] = Hash[*@all_data[key].map{ |x| [x.movie_id, x.value == "t"] }.flatten]
    end
  end
end
