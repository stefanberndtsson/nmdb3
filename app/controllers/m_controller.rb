class MController < ApplicationController
  layout "m"
  before_filter :setup
  
  def index
    @hide_left_link = true
  end
  
  def result
    @max_results = 15
    if params[:search].blank?
      redirect_to :action => 'index'
      return
    end
    @query = params[:search]
    @valid_sources = ["movies", "people", "plots", "quotes"]
    @source_partial = { "movies" => "movies", "people" => "people", "plots" => "movies", "quotes" => "movies" }
    @facet_names = { "category" => "Category/Episodes", "genre" => "Genre", "language" => "Language", "year" => "Year", "rating" => "Rating", "keyword" => "Keyword" }
    @facet_pages = { "category" => "list", "genre" => "list", "language" => "list", "year" => "range", "rating" => "range", "keyword" => "list" }
    @facet_types = @facet_names.keys
    @source = params[:source]
    @source = "movies" if !@valid_sources.include?(@source)

    params.keys.each do |key|
      next if !key[/^active_facet_/]
      facet_key = key[7..-1]
      if params[facet_key]
        params[facet_key].merge!(params[key])
      else
        params[facet_key] = params[key]
      end
#      params.delete(key)
    end
    
    params.keys.each do |key|
      next if !key[/^facet_/]
      next if key == "facet_type"
      if(params[:facet_type] == "reset_facets" ||
          (params["commit"] && params["commit"][/^Reset/] && "facet_#{params["last_facet_selection"]}" == key))
        params[key].delete_if { |k,v| true }
      else
        params[key].delete_if { |k,v| v.empty? }
      end
    end

    @filters = extract_filters(@facet_types+["episode"])
    @results,@facets,@partial_facets = Search.query(@query, @source, @filters, @max_results, 40)
    
    if params[:facet_type] == "reset_facets"
      params[:search_facet_selector] = false
    end
    @show_facet_page = (params[:search_facet_selector] == "true" ? true : false)
    @with_facets = true unless @source == "people"
    @facet_type = params[:facet_type]
    
    if ["genre", "language", "keyword", "category"].include?(@facet_type)
      @facet_page_to_render = "list"
      @facet_list = @facets[@facet_type]
    elsif ["year"].include?(@facet_type)
      @facet_page_to_render = "range"
      if params["facet_year"]
        @facet_min_value = params["facet_year"]["from"]
        @facet_max_value = params["facet_year"]["to"]
      else
        @facet_min_value = @facets[@facet_type].transpose[0].min
        @facet_max_value = @facets[@facet_type].transpose[0].max
      end
      @facet_values = Range.new(MovieYear.year_min, MovieYear.year_max).to_a.map { |x| [x, x] }
    elsif ["rating"].include?(@facet_type)
      @facet_page_to_render = "range"
      if params["facet_rating"]
        @facet_min_value = params["facet_rating"]["from"]
        @facet_max_value = params["facet_rating"]["to"]
      else
        @facet_min_value = @facets[@facet_type].transpose[0].min
        @facet_max_value = @facets[@facet_type].transpose[0].max
      end
      @facet_values = Range.new(10, 100).to_a.map { |x| [x, sprintf("%2.1f", x/10.0)] }
    end
    
    if @source == "movies"
      @result_ids = @results[:movies][0..@max_results].map(&:id)
      @suggestion_ids = Search.dym_movie(@query)
      @suggestion_ids -= @result_ids
      if !@suggestion_ids.blank?
        if !@result_ids.blank?
          @suggestion = [Movie.find(@suggestion_ids.first)]
        else
          @suggestion = @suggestion_ids.uniq[0..6].map { |x| Movie.find(x) }
        end
      end
    elsif @source == "people"
      @result_ids = (@results[:people]+@results[:exact_person]).sort_by { |x| -x.score }[0..@max_results].map(&:id)
      @suggestion_ids = Search.dym_person(@query)
      @suggestion_ids -= @result_ids
      if !@suggestion_ids.blank?
        if !@result_ids.blank?
          @suggestion = [Person.find(@suggestion_ids.first)]
        else
          @suggestion = @suggestion_ids.uniq[0..6].map { |x| Person.find(x) }
        end
      end
    end
  end
  
  def movie
    @movie = Movie.find(params[:id])
    @valid = @movie.valid_mobile_pages
    @page = params[:page]
    @page = "cast" if !@valid.transpose[0].include?(@page)
    
    @genres = @movie.genres.uniq.map(&:genre).join(" / ")
    director = @movie.movie_directors
    if !director.blank?
      @director = director.first[:person]
    end
    tagline = @movie.taglines.first
    if tagline
      @tagline = tagline.tagline
    end
    release = @movie.first_release_date
    if release
      @release = ([release.release_date, release.country.blank? ? nil : "(#{release.country})", release.info]-[nil]).join(" ")
    end
    
    if @page == "connections"
      @connections = @movie.movie_connections.group_by { |x| x.movie_connection_type }
    end
    
    if @page == "episodes"
      @has_seasons = !(@movie.episodes.map(&:episode_season)-[nil]).blank?
    end
    
    if @page == "keyword"
      keywords = @movie.keywords
      strong_keywords = @movie.strong_keywords
      @keywords = (strong_keywords + (keywords - strong_keywords)).sort_by { |x| x.display }
    end
  end
  
  def person
    @person = Person.find(params[:id])
    @valid = @person.valid_mobile_pages
    @page = params[:page]
    @page = "movies_by_weight" if !@valid.transpose[0].include?(@page)
    @page_to_render = @page
    
    @birth = @person.date_of_birth
    @age = @person.age
    @death = @person.date_of_death
    @realname = @person.birth_name
    
    if ["biography", "trivia", "quotes", "publicity", "other_works"].include?(@page)
      @aka_names = @person.aka_names if @page == "biography"
      @md_keys = PersonMetadatum.pages[@page][:keys]
      @metadata = @person.person_metadata.find_all_by_key(@md_keys).group_by { |x| x.key }
      @page_to_render = "biography"
    end
    
    if ["movies_primary_cast", "movies_composer", "movies_director",
        "movies_producer", "movies_writer", "movies_self", "movies_archive"].include?(@page)
      @movie_list = @person.movies_as_primary_cast if @page == "movies_primary_cast"
      @movie_list = @person.movies_as_self if @page == "movies_self"
      @movie_list = @person.movies_as_archive if @page == "movies_archive"
      @movie_list = @person.movies_as_section("composer") if @page == "movies_composer"
      @movie_list = @person.movies_as_section("director") if @page == "movies_director"
      @movie_list = @person.movies_as_section("producer") if @page == "movies_producer"
      @movie_list = @person.movies_as_section("writer") if @page == "movies_writer"
      @page_to_render = "movies_chrono"
    end
  end
  
  def image_view
    @type = params[:type]
    @object_id = params[:object_id]
    if @type == "movie"
      @movie = Movie.find(@object_id)
      @image_url = @movie.image_url(true) # WikipediaFetcher.image(@movie)
      @title = @movie.display
    elsif @type == "person"
      @person = Person.find(@object_id)
      @image_url = @person.image_url(false, true) # WikipediaFetcher.image(@person)
      @title = @person.name(false)
    end
  end
  
  private
  def setup
    @timer = { :start => Time.now }
  end
  
  def extract_filters(types)
    filter_names = {
      "genre" => "genre_ids",
      "keyword" => "keyword_ids",
      "language" => "language_ids",
      "year" => "year_attr",
      "rating" => "rating",
      "episode" => "is_episode",
      "category" => "category"
    }
    
    filters = []
    types.each do |type|
      next if !params["facet_#{type}"]
      if @facet_pages[type] == "range"
        next if !params["facet_#{type}"]["from"] || !params["facet_#{type}"]["to"]
        if type == "rating"
          range = Range.new(params["facet_#{type}"]["from"].to_i/10.0, params["facet_#{type}"]["to"].to_i/10.0)
        else
          range = Range.new(params["facet_#{type}"]["from"].to_i, params["facet_#{type}"]["to"].to_i)
        end
        filters << Riddle::Client::Filter.new(filter_names[type], range, false)
      elsif @facet_pages[type] == "list"
        data = params["facet_#{type}"]
        included = data.keys.select { |x| data[x] == "include" }.map(&:to_i)
        excluded = data.keys.select { |x| data[x] == "exclude" }.map(&:to_i)
        included.each do |value|
          filters << Riddle::Client::Filter.new(filter_names[type], [value], false)
        end
        excluded.each do |value|
          filters << Riddle::Client::Filter.new(filter_names[type], [value], true)
        end
      elsif type == "episode"
        if params["facet_episode"]["0"]
          filters << Riddle::Client::Filter.new("is_episode", [1], params["facet_episode"]["0"] == "exclude")
        end
      end
    end
    
    filters
  end
end
