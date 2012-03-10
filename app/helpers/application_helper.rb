module ApplicationHelper
  def current_user
    @current_user ||= User.find_by_id(cookies['user_id'])
    return nil if !@current_user
    return nil if !@current_user.has_session?(cookies['session_id'])
    @current_user.refresh_session(cookies['session_id'])
    @current_user
  end

  def show_debug?
    current_user && current_user.show_setting("show_debug")
  end

  def use_autocomplete?
    current_user && current_user.show_autocomplete?
  end
  
  def link_to_logout
    bounceback = params[:bounceback] || request.fullpath
    link_to "Logout", :controller => :user, :action => :logout, :bounceback => bounceback
  end
  
  def link_to_login
    bounceback = params[:bounceback] || request.fullpath
    link_to "Login", :controller => :user, :action => :login, :bounceback => bounceback
  end
  
  def link_to_register
    bounceback = params[:bounceback] || request.fullpath
    link_to "Register", :controller => :user, :action => :register, :bounceback => bounceback
  end
  
  def link_to_profile
    bounceback = params[:bounceback] || request.fullpath
    link_to "Profile", :controller => :user, :action => :profile, :bounceback => bounceback
  end
  
  def link_to_resetexternal(object_id, type, return_url_only = false)
    bounceback = params[:bounceback] || request.fullpath
    link_text = "Reset Externals"
    if type == "movie"
      link_url = url_for(:controller => :movie, :action => :reset_externals, :id => object_id, :bounceback => bounceback)
      return link_url if return_url_only
      return link_to link_text, link_url
    elsif type == "person"
      link_url = url_for(:controller => :person, :action => :reset_externals, :id => object_id, :bounceback => bounceback)
      return link_url if return_url_only
      return link_to link_text, :controller => :person, :action => :reset_externals, :id => object_id, :bounceback => bounceback
    else
      return link_text
    end
  end
  
  def menu
    case params[:controller]
    when "movie"
      return movie_menu
    when "person"
      return person_menu
    when "user"
      return user_menu
    else
      return nil
    end
  end
  
  def display_single_keyword(keyword, linked_to_search = false)
    return keyword if keyword.class != Keyword
    
    text = keyword.display
    if linked_to_search
      text = link_to_page(text, :search, :result, nil, 
                          :query => "@keyword #{keyword.keyword}",
                          :source => "movies")
    end
    return text.html_safe if !keyword.strong
    content_tag(:strong, text).html_safe
  end
  
  def link_to_page(link_text, controller, action, id, other = { })
    options = { :controller => controller, :action => action, :id => id }.merge(other)
    link_to(link_text, options)
  end
  
  def link_to_movie(movie, forced_text = nil, forced_action = :index, ui_type = :main)
    forced_text = content_tag :span, :class => "movie_title_#{movie.id}" do
      forced_text || movie.display
    end
    if ui_type == :mobile
      link_to(forced_text, 
           :action => :movie, :id => movie.id)
    else
      link_to(forced_text, 
           :controller => :movie, :action => forced_action, :id => movie.id)
    end
  end
  
  def link_to_person(person, include_count = true, ui_type = :main)
    if ui_type == :mobile
      link_to(person.name(include_count), :action => :person, :id => person.id)
    else
      link_to(person.name(include_count), :controller => :person, :id => person.id)
    end
  end
    
  def decode_links(text, ui_type = :main)
    text.gsub(/@@(PID|MID)@(\d+)@@/) do |linktext|
      link_type = $1
      link_id = $2.to_i
      if link_type == "PID"
        person = Person.find_by_id(link_id)
        if !person.nil?
          linktext = link_to_person(person, true, ui_type)
        else
          linktext = "Unknown person #{link_id}"
        end
      elsif link_type == "MID"
        movie = Movie.find_by_id(link_id)
        if !movie.nil?
          linktext = link_to_movie(movie, nil, :index, ui_type)
        else
          linktext = "Unknown movie #{link_id}"
        end
      end
    end.html_safe
  end
  
  def display_title(movie, breaker = nil, suffix = nil)
    score = movie.score ? movie.score.to_i.to_s : ""
    score_class = (current_user && current_user.show_scores?) ? "score_visible" : "score"
    if !score.empty?
      score = "<span class=\"#{score_class}\">&nbsp;(#{score})</span>".html_safe
    end
    return link_to_movie(movie)+score if !breaker || movie.real_title?
    link_to_movie(movie) + breaker.html_safe + movie.full_title + (suffix || "") + score
  end
  
  def display_total_time(timer)
    value = timer[:end].to_f - timer[:start].to_f
    unit = "s"
    if value < 0.25
      value *= 1000
      unit = "ms"
    end
    
    sprintf("%7.3f%s", value, unit)
  end
  
  def cast_list(movie, cast_count = 5)
    return "" if movie.cast.blank?
    
    list = movie.cast[0..cast_count-1]
    
    return list.map { |x| "<span class=\"nowrap\">#{x.person.name(false)}</span>" }.join(", ").html_safe
  end
  
  def movie_list(person, movie_count = 2)
    weighted = person.movies_by_weight(movie_count, true)
    return "" if weighted.blank?
    
    return weighted.map { |x| "<span class=\"nowrap\">#{x.title}</span>" }.join(", ").html_safe
  end
  
  def tmdb_image_info(image, separator = ": ", force_two_parts = false)
    language = nil
    size = nil
    if image["width"] && image["height"]
      size = "#{image["width"]}x#{image["height"]}"
    end
    if image["iso_639_1"]
      language = ISO_639.find_by_code(image["iso_639_1"])
      language = language.english_name if language
    end

    array = ([language, size]-[nil])
    if array.size < 2 && force_two_parts
      array += ["&nbsp;"]
    end
    array.join(separator)
  end
end
