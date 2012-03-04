class SearchController < ApplicationController
  layout "nmdb"
  before_filter :setup
  
  def index
  end
  
  def result
    @query = params[:query]
    if @query.blank?
      redirect_to :action => 'index'
      return
    end

    @year_min = MovieYear.year_min
    @year_max = MovieYear.year_max
    
    @rating_min = Rating.rating_min
    @rating_max = Rating.rating_max
    
    @param_filters = params[:filters]
    @param_filters = [] if @param_filters.class != Array
    @filters = []
    has_decade = false
    filtering_year = false
    @param_filters.each do |filter|
      range = nil
      if filter[:values].size == 1 && filter[:values].first[/^[\d\.]+\.\.[\d\.]+$/]
        parts = filter[:values].first.scan(/^([\d\.]+)\.\.([\d\.]+)$/)[0]
        if parts
          if filter[:attribute] == "rating"
            parts.map! { |x| (x.to_i/10.0).to_f }
          else
            parts.map! { |x| x.to_i }
          end
          range = Range.new(parts[0], parts[1])
        end
      end
      if range
        if filter[:attribute] == "year_attr"
          @force_year = range
        end
        if filter[:attribute] == "rating"
          @force_rating = Range.new((10*range.min).to_i, (10*range.max).to_i)
        end
        @filters << Riddle::Client::Filter.new(filter[:attribute], 
                                               range, filter[:exclude] == "true")
      else
        @filters << Riddle::Client::Filter.new(filter[:attribute], 
                                               filter[:values], filter[:exclude] == "true")
      end
      has_decade = true if filter[:attribute] == "decade_attr"
      filtering_year = true if filter[:attribute] == "year_attr"
    end
    
    @source = params[:source]
    @selected = @source
    
    @search_query_reply = Search.query(@query, @source, @filters)
    @results, @facets, @partial_facets = @search_query_reply
    if @force_year
      @facet_year_min = @force_year.min
      @facet_year_max = @force_year.max
    else
      if @partial_facets || @facets["year"].blank?
        @facet_year_min = @year_min
        @facet_year_max = @year_max
      else
        @facet_year_min = @facets["year"].map { |x| x[0] }.min
        @facet_year_max = @facets["year"].map { |x| x[0] }.max
      end
    end
    if @force_rating
      @facet_rating_min = @force_rating.min
      @facet_rating_max = @force_rating.max
    else
      if @partial_facets || @facets["rating"].blank?
        @facet_rating_min = @rating_min
        @facet_rating_max = @rating_max
      else
        @facet_rating_min = @facets["rating"].map { |x| x[0] }.min
        @facet_rating_max = @facets["rating"].map { |x| x[0] }.max
      end
    end
    
#    @facets.delete("year") if @facets["year"] && !has_decade
#    @facets.delete("decade") if @facets["decade"]
    
    @movie_list = @results[:movies].map { |x| x.id.to_i }
    @exact_movie_list = @results[:exact_movie].map { |x| x.id.to_i }
    @person_list = @results[:people].map { |x| x.id.to_i }
    @exact_person_list = @results[:exact_person].map { |x| x.id.to_i }
    
    @top_score_movies = []
    if @results[:scores] && !@results[:scores].keys.blank?
      scores = @results[:scores].keys.sort.reverse
      @score_median = scores[scores.size/2]
      top = scores.shift || 1.0
      second = scores.shift || 1.0
      if top > 300000 || top > @score_median*2
        @top_score_movies << @results[:scores][top]
      end
      if top/second < 1.20 || second > 300000
        if @top_score_movies.empty?
          @top_score_movies << @results[:scores][top]
        end
        @top_score_movies << @results[:scores][second]
      end
      @top_score_movies.each do |movie|
        @results[:movies].delete(movie)
        @results[:exact_movie].delete(movie)
      end
    end

    @search_query_reply[0].delete(:scores)
    
    respond_to do |format|
      format.html
      format.xml { render :xml => @search_query_reply }
      format.json { render :json => @search_query_reply }
    end
  end
  
  def dym_movie
    @query = params[:query]
    @movie_list = params[:movie_list] || []
    @exact_movie_list = params[:exact_movie_list] || []
    @suggestion = nil
    Search.dym_movie(@query).each do |item|
      next if @movie_list.include?(item.to_s)
      next if @exact_movie_list.include?(item.to_s)
      @suggestion = Movie.find_by_id(item)
      break
    end
    render :partial => 'dym_movie'
  end
  
  def dym_person
    @query = params[:query]
    @person_list = params[:person_list] || []
    @exact_person_list = params[:exact_person_list] || []
    @suggestion = nil
    Search.dym_person(@query).each do |item|
      next if @person_list.include?(item.to_s)
      next if @exact_person_list.include?(item.to_s)
      @suggestion = Person.find_by_id(item)
      break
    end
    render :partial => 'dym_person'
  end
  
  def autocomplete_search
    @query = params[:q]
    result_movies = Search.dym_movie(@query, 10, true).uniq_by { |x| x[0] }
    result_people = Search.dym_person(@query, 10, 10000, true).uniq_by { |x| x[0] }
    movies = Movie.where(:id => result_movies.transpose[0]).includes(:languages).includes(:movie_akas).includes(:release_dates).group_by { |x| x.id }
    people = Person.where(:id => result_people.transpose[0]).group_by { |x| x.id }
    result = (result_movies+result_people).sort_by { |x| [x[1],-x[2]] }.map do |x|
      object = (x[3] == :movie) ? movies[x[0]].first : people[x[0]].first
      autocomplete_string(object, x[3])
    end

#    [result_movies.size, result_people.size].max.times do |i|
#      movie = movies[result_movies[i][0]]
#      person = people[result_people[i][0]]
#      result << ["<b>"+movie.first.display+"</b>", url_for(:controller => :movie, :id => movie.first.id)].join("|") if movie
#      result << [person.first.name(false), url_for(:controller => :person, :id => person.first.id)].join("|") if person
#    end
    render :text => result[0..7].join("\n")
  end
  
  private
  def setup
    @timer = { :start => Time.now }
  end
  
  def autocomplete_string(object, type)
    string = (type == :movie) ? "<b>#{object.display}</b>" : object.name(false)
    value = url_for(:controller => type, :id => object.id)
    [string, value].join("|")
  end
end
