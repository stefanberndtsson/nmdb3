class Person < ActiveRecord::Base
  TMDB_KEY=Rails.application.config.themoviedb_key if Rails.application.config.respond_to?("themoviedb_key")
  TMDB_API_URL="http://api.themoviedb.org/3"
  has_many :occupations
  has_many :movies, :through => :occupations
  has_many :aka_names
  has_many :person_metadata
  attr_accessor :score
  
  def name(include_count = false)
    output = [first_name, last_name]
    output << "(#{name_count})" if include_count && name_count
    output.join(" ")
  end
  
  def date_of_birth
    db = person_metadata.find_by_key("DB")
    return nil if !db
    db.value
  end
  
  def date_of_death
    dd = person_metadata.find_by_key("DD")
    return nil if !dd
    dd.value
  end
  
  def stamp_of_birth
    db = date_of_birth
    return nil if !db
    
    if db[/^(\d{4}),/]
      return Time.parse("#{$1}-07-01")
    end
    
    begin
      return Time.parse(db)
    rescue
      return nil
    end
  end
  
  def stamp_of_death
    dd = date_of_death
    return nil if !dd
    
    if dd[/^(\d{4}),/]
      return Time.parse("#{$1}-07-01")
    end
    
    begin
      return Time.parse(dd)
    rescue
      return nil
    end
  end

  def age
    birth = stamp_of_birth
    return if !birth
    
    death = stamp_of_death
    if !death
      death = Time.now
    end
    [birth, death]
  end    
  
  def birth_name
    bn = person_metadata.find_by_key("RN")
    return nil if !bn
    bn.value
  end

  def movies_base
    occupations.
      joins(:role).
      joins(:movie).
      includes(:movie).
      includes(:movie => :main).
      includes(:movie => :movie_akas).
      where(:movies => { :suspended => nil }).
      order("movies.full_year DESC")
  end
  
  def movies_as_role_group(group_name)
    movies_base.where(:roles => { :group => group_name })
  end
  
  def movies_as_role(role_name)
    movies_base.where(:roles => { :role => role_name })
  end
  
  def movies_as_cast
    return @cache if @cache
    movies = movies_as_role_group(Role::GROUP_CAST)
    @cache ||= compress_episode_data(movies)
  end

  def new_compress_episode_data(movies)
    grouped = movies.group_by { |x| x.movie.main }
    non_episodes = grouped.delete(nil)
    non_episodes.delete_if { |x| grouped.keys.include?(x) }
    grouped.keys.each do |ep_main_key|
      grouped[ep_main_key].each { |x| ep_main_key.add_active_episode(x.movie, x) }
    end
    
    movies = non_episodes + grouped.keys
    
    movies.sort_by do |movie|
      movie.class == Movie ? -movie.full_year.to_i : -movie.movie.full_year.to_i
    end
  end
  
  def compress_episode_data(movies)
    episodes = movies.select { |x| x.movie.is_episode }
    non_episodes = movies.select { |x| !x.movie.is_episode }
    episode_mains = episodes.map { |x| [x.movie.main, x] }.group_by { |x| x[0] }
    non_episodes.each do |non_ep|
      episode_mains.keys.each do |ep_main_key|
        if ep_main_key == non_ep
          episode_mains[ep_main_key][0].each { |x| non_ep.movie.add_active_episode(x.movie, x) }
          episode_mains.delete(ep_main_key)
        end
      end
    end
    episode_mains.keys.each do |ep_main_key|
      episode_mains[ep_main_key].each { |x| ep_main_key.add_active_episode(x[1].movie, x[1]) }
      non_episodes.delete_if { |x| x.movie_id == ep_main_key.id }
    end
    
    movies = non_episodes + episode_mains.keys
    
    movies.sort_by do |movie|
      movie.class == Movie ? -movie.full_year.to_i : -movie.movie.full_year.to_i
    end
  end
  
  def movies_as_primary_cast
    movies_as_cast - movies_as_self - movies_as_archive
  end
  
  def movies_as_self
    movies_as_cast.select do |movie|
      ((movie.class == Occupation &&
        movie.character &&
        movie.character.match(/(himself|herself|themselves)/i)) || 
       (movie.class == Movie && 
        !movie.active_episodes.blank? && 
        movie.active_episodes[0][:occupation] && 
        movie.active_episodes[0][:occupation].character && 
        movie.active_episodes[0][:occupation].character.match(/(himself|herself|themselves)/i)))
    end
  end
  
  def movies_as_archive
    movies_as_cast.select do |movie|
      ((movie.class == Occupation &&
        movie.extras &&
        movie.extras.match(/(archive footage)/i)) || 
       (movie.class == Movie && 
        !movie.active_episodes.blank? && 
        movie.active_episodes[0][:occupation] && 
        movie.active_episodes[0][:occupation].extras && 
        movie.active_episodes[0][:occupation].extras.match(/(archive footage)/i)))
    end
  end

  def movies_as_section(section_name)
    if ["producer", "director", "writer", "composer"].include?(section_name)
      return movies_as_role(section_name)
    end
    return movies_as_self if section_name == "self"
    return movies_as_archive if section_name == "archive"
    return movies_as_primary_cast if !section_name
  end

  def movies_by_genre
    genres = { }
    movies_as_role_group(Role::GROUP_CAST).each do |movie|
      movie.movie.genres.each do |genre|
        genres[genre] ||= []
        genres[genre] << movie
      end
    end
    genres.keys.each do |key|
      genres[key] = compress_episode_data(genres[key])
    end
    genres
  end
  
  def movies_by_keyword
    keywords = { }
    movies_as_role_group(Role::GROUP_CAST).each do |movie|
      movie.movie.keywords.each do |keyword|
        keywords[keyword] ||= []
        keywords[keyword] << movie
      end
    end
    keywords.keys.each do |key|
      keywords[key] = compress_episode_data(keywords[key])
    end
    keywords
  end

  def movies_by_weight(limit = nil, skip_occupation = false)
    person_filter = Riddle::Client::Filter.new("cast_ids", [self.id], false)
    result = Search.query("@cast \"#{self.name}\"", "movies", [person_filter], limit || self.movies.count)
    return [] if !result && !result[0] && !result[0][:movies]
    if limit
      if skip_occupation
        return result[0][:movies][0..limit-1]
      else
        return result[0][:movies][0..limit-1].map { |x| x.occupation(self) }
      end
    end
    movie_ids = result[0][:movies].map(&:id)
    sort_value = { }
    result[0][:movies].each_with_index { |x,i| sort_value[x.id] = i }
    tmp = occupations.joins(:role).
      where(:movie_id => movies_base.select(:movie_id).map(&:movie_id)).
      where(:roles => { :group => Role::GROUP_CAST }).sort_by { |x| sort_value[x.movie_id] }
    return tmp
  end
  
  def section_heading(section_name)
    if !section_name
      return gender == Role::GENDER_FEMALE ? "actress" : "actor"
    end
    return section_name
  end
  
  def gender
    movies_as_role_group(Role::GROUP_CAST).first.role_id
  end
  
  def has_metadata_page?(page)
    !person_metadata.find_all_by_key(PersonMetadatum.pages[page][:keys]).empty?
  end

  def serialize_complete_options(options = { })
    default_options = {
      :skip_types => true,
      :include => {
        :person_metadata => { },
        :aka_names => { },
        :occupations => {
          :include => {
            :movie => { },
            :role => { }
          }
        }
      }
    }
    
    default_options.merge(options)
  end
  
  def to_complete_xml(options = { })
    to_xml(serialize_complete_options(options))
  end
  
  def to_complete_json(options = { })
    to_json(serialize_complete_options(options))
  end

  def wikipedia_query_list
    list = []
    list << name
    aka_names.each do |akan|
      list << akan.name
    end
    list2 = []
    list.each do |item|
      list2 << item
      wikipedia_query_addons.each do |addon|
        list2 << "#{item} (#{addon})"
      end
    end
    
    list2.uniq
  end

  def wikipedia_query_addons
    addons = []
    addons << "author"
    addons << (gender == Role::GENDER_FEMALE ? "actress" : "actor")
    addons << (gender == Role::GENDER_FEMALE ? "pornographic actress" : "pornographic actor")
    addons << "person"
    addons
  end

  def wikipedia_opensearch_list
    []
  end
  
  def wikipedia_fetching_object
    self
  end
  
  def query_source(simple = false)
    simple ? "people-simple" : "biography"
  end
  
  def cache_prefix
    "person:#{id.to_s}:"
  end
  
  def is_game?
    false
  end

  def image_url(user = nil, cache_only = false)
    if tmdb_main_profile(user, cache_only)
      return tmdb_main_profile(user, cache_only)
    end
    return RCache.get("person:#{id}:wikipedia:image")
  end
  
  def valid_mobile_pages
    pages = [["movies_by_weight", "Movies Weighted"]]
    pages << ["movies_primary_cast", "Movies Chronologically"] if !movies_as_primary_cast.blank?
    pages << ["movies_self", "Movies as Theirself"] if !movies_as_self.blank?
    pages << ["movies_archive", "Movies as Archive footage"] if !movies_as_archive.blank?
    pages << ["movies_producer", "Movies as Producer"] if !movies_as_section("producer").blank?
    pages << ["movies_director", "Movies as Director"] if !movies_as_section("director").blank?
    pages << ["movies_writer", "Movies as Writer"] if !movies_as_section("writer").blank?
    pages << ["movies_composer", "Movies as Composer"] if !movies_as_section("composer").blank?
    pages << ["biography", "Biography"] if has_metadata_page?("biography")
    pages << ["trivia", "Trivia"] if has_metadata_page?("trivia")
    pages << ["quotes", "Quotes"] if has_metadata_page?("quotes")
    pages << ["publicity", "Publicity"] if has_metadata_page?("publicity")
    pages << ["other_works", "Other Works"] if has_metadata_page?("other_works")
    pages
  end
  
  def episode_count(movie)
    occs = occupations.joins(:role).
      where(:movie_id => movie.id).
      where(:roles => { :group => Role::GROUP_CAST }).
      where(:collected => true)
    (occs.count > 0) ? occs.first.episode_count : nil
  end
  
  def has_images?(user = nil, cache_only = true)
    return false if !(tmdb_images(user, cache_only) && !(tmdb_images(user, cache_only)["profiles"].blank?))
    return false if tmdb_images(user, cache_only)["profiles"].size <= 1
    info = tmdb_info(user)
    return false if !info
    return false if info["adult"] && !user
    return true
  end
  
  def tmdb_find(user = nil)
    return nil if !defined?(TMDB_KEY)
    info = RCache.get(cache_prefix+"tmdb:info")
    if !info.blank?
      info = JSON.parse(info)
      return nil if !user && info["adult"]
      return info
    end
    result = nil
    urls = tmdb_find_url(user)
    urls.each do |tmdb_url|
      begin
        open(tmdb_url) do |file|
          json = file.read
          result = JSON.parse(json)
        end
      rescue
        RCache.set(cache_prefix+"tmdb:info", "", 1.hour)
        return nil
      end
      next if result.blank? || result["results"].blank?

      result["results"].each do |res|
        if tmdb_valid?(res["id"])
          if !user && res["adult"]
            RCache.set(cache_prefix+"tmdb:info", "", 1.hour)
            return nil
          end
          info = tmdb_info(res["id"])
          return info
        end
      end
    end
    RCache.set(cache_prefix+"tmdb:info", "", 1.hour)
    return nil
  end
  
  def tmdb_find_url(user = nil, do_akas = true)
    adult = ""
    if user
      adult = "include_adult=true&"
    end
    names = [name_norm]
    names += aka_names.map(&:name_norm) if do_akas
    names.map do |tmp_name|
      TMDB_API_URL+"/search/person?#{adult}api_key="+TMDB_KEY+"&query="+CGI.escape(tmp_name)
    end
  end
  
  def tmdb_images(user = nil, cache_only = false)
    return nil if !defined?(TMDB_KEY)
    info = RCache.get(cache_prefix+"tmdb:info")
    return nil if !user && !info.blank? && JSON.parse(info)["adult"]
    if cache_only
      return nil if !user && info.blank?
      json = RCache.get(cache_prefix+"tmdb:images")
      return JSON.parse(json) if !json.blank?
      return nil
    end
    images = RCache.get(cache_prefix+"tmdb:images")
    return JSON.parse(images) if !images.blank?
    info = tmdb_find(user)
    return nil if info.blank?
    begin
      open(tmdb_info_url(info["id"], "images", user)) do |file|
        json = file.read
        RCache.set(cache_prefix+"tmdb:images", json, 10.days)
        return JSON.parse(json)
      end
    rescue
      RCache.set(cache_prefix+"tmdb:images", "", 1.hour)
      return nil
    end
  end
  
  def tmdb_info(tmdb_id, section = nil)
    return nil if !defined?(TMDB_KEY)
    info = RCache.get(cache_prefix+"tmdb:info")
    return JSON.parse(info) if !info.blank?
    begin
      open(tmdb_info_url(tmdb_id, section)) do |file|
        json = file.read
        RCache.set(cache_prefix+"tmdb:info", json, 10.days) if !section
        return JSON.parse(json)
      end
    rescue
      RCache.set(cache_prefix+"tmdb:info", "", 1.hour) if !section
      return nil
    end
  end
  
  def tmdb_main_profile(user = nil, cache_only = false)
    info = RCache.get(cache_prefix+"tmdb:info")
    return nil if !user && !info.blank? && JSON.parse(info)["adult"]
    if cache_only
      return nil if !user && info.blank?
      url = RCache.get(cache_prefix+"tmdb:main_profile:noexpire")
      return url if !url.blank?
      return nil
    end
    url = RCache.get(cache_prefix+"tmdb:main_profile")
    return url if !url.blank?
    info = tmdb_find(user)
    if info.blank? || info["profile_path"].blank?
      RCache.set(cache_prefix+"tmdb:main_profile", "", 1.hour)
      return nil
    end
    url = tmdb_image_url(info["profile_path"], "large")
    RCache.set(cache_prefix+"tmdb:main_profile", url, 10.days)
    RCache.set(cache_prefix+"tmdb:main_profile:noexpire", url, nil)
    url
  end
  
  def tmdb_info_url(tmdb_id, section = nil, user = nil)
    section = section ? "/#{section}" : ""
    adult = ""
    if user
      adult = "include_adult=true&"
    end
    TMDB_API_URL+"/person/#{tmdb_id}"+section+"?#{adult}api_key="+TMDB_KEY
  end
  
  def tmdb_valid?(tmdb_id)
    tmp = RCache.get(cache_prefix+"tmdb:id")
    return true if tmp == tmdb_id.to_s
    movies = tmdb_info(tmdb_id, "credits")
    return nil if movies.blank? || movies["cast"].blank?

    movies = movies["cast"].map do |movie|
      next if movie["release_date"].blank?
      begin
        year = Time.parse(movie["release_date"]).year
      rescue
        next
      end
      tmdb_movie_title_match(
                       [movie["title"], movie["original_title"]],
                       self.movies.joins(:movie_years).where(:movie_years => { :year => year.to_s })
                       )
    end.compact.reject { |x| x[0]+x[1] > 3 }.map { |x| x[2].id }

    matched_movies = self.movies.where(:id => movies)
    return false if matched_movies.size <= 1
    if matched_movies.size.to_f/movies.size.to_f > 0.75
      RCache.set(cache_prefix+"tmdb:id", tmdb_id.to_s, 10.days)
      return true
    end
    return false
  end

  def tmdb_movie_title_match(tmdb_titles, nmdb_titles)
    nmdb_titles.map do |nt|
      [
        Levenshtein.distance(nt.title, tmdb_titles.first),
        Levenshtein.distance(nt.title, tmdb_titles.last),
        nt
      ]
    end.sort_by do |matched|
      matched[0]+matched[1]
    end.first
  end
  
  def tmdb_image_url(path, size_string = "thumb")
    config = tmdb_configuration
    base_url = config["images"]["base_url"]
    size = tmdb_image_size(size_string)
    return base_url+size+path
  end
  
  def tmdb_image_size(size_string = "thumb")
    config = tmdb_configuration
    return nil if !config
    return size_string if size_string == "original"
    if size_string == "thumb"
      return config["images"]["profile_sizes"][0]
    elsif size_string == "large"
      return config["images"]["profile_sizes"][-2]
    elsif size_string == "medium"
      idx = (config["images"]["profile_sizes"].size-1)/2
      return config["images"]["profile_sizes"][idx]
    end
    return nil
  end
  
  def tmdb_configuration
    return nil if !defined?(TMDB_KEY)
    @@tmdb_config ||= { }
    return @@tmdb_config if @@tmdb_config["images"]
    begin
      open(tmdb_configuration_url) do |file|
        @@tmdb_config = JSON.parse(file.read)
      end
    rescue
    end
    @@tmdb_config
  end
  
  def tmdb_configuration_url
    TMDB_API_URL+"/configuration?api_key="+TMDB_KEY
  end
  
  def image_skip_probe?
    probestamp = RCache.get(cache_prefix+"image:has_probed")
    return true if !probestamp.blank?
    RCache.set(cache_prefix+"image:has_probed", true, 1.day)
    return false
  end
end
