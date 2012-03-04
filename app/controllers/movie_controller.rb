class MovieController < ApplicationController
  layout "nmdb"
  before_filter :setup_or_redirect
  
  def index
    respond_to do |format|
      format.html
      format.xml { render :xml => @movie.to_specified_data(:xml, params[:richness]) }
      format.json { render :json => @movie.to_specified_data(:json, params[:richness]) }
    end
  end

  def episodes
    @episodes = @movie.episodes_sorted.group_by { |x| x.episode_season || "Unknown" }
  end

  def keywords
    keywords = @movie.keywords
    strong_keywords = @movie.strong_keywords
    @keywords = (strong_keywords + (keywords - strong_keywords)).sort_by { |x| x.display }
  end

  def movie_connections
    @mcon = @movie.movie_connections.all(:include => [:movie_connection_type, 
                                                      :linked_movie]).group_by { |x| x.type }
    @mcon.keys.each do |con|
      @mcon[con] = @mcon[con].sort_by { |x| x.linked_movie.full_year || "zzzzzzzzzzzz" }
    end
  end

  def technicals
    @technicals = @movie.technicals.group_by { |x| x.key }
  end

  def external_links
    if WikipediaFetcher.page(@movie)
      @wikipedia_page = WikipediaFetcher.page(@movie)
    else
      @wikipedia_page = @movie.display
    end
  end
  
  def image
    @image_url = WikipediaFetcher.image(@movie, true)
    render :partial => 'image'
  end

  def image_new
    query_id = params[:next_query_id].to_i
    opensearch_id = params[:next_opensearch_id].to_i
    @next_query_id = query_id
    @next_opensearch_id = opensearch_id
    @movie.wikipedia_purge_all
    @image_url = nil
    begin
      @image_url = WikipediaFetcher.image(@movie, true, { 
                                            :query => query_id,
                                            :opensearch => opensearch_id
                                          })
    rescue WikipediaFetcher::NoMoreDataException
      if query_id == -1
        @next_query_id = 0
        @next_opensearch_id = -1
      else
        @next_query_id = nil
        @next_opensearch_id = nil
      end
    else
      if query_id == -1
        @next_query_id = -1
        @next_opensearch_id += 1
      else
        @next_query_id += 1
        @next_opensearch_id = -1
      end
    end
    @image_url = true if !@image_url
    if @image_url
      render :partial => 'image_new'
    else
      render :text => ''
    end
  end
  
  def new_title
    render :text => @movie.display
  end
  
  def reset_externals
    rc = RCache.keys("movie:#{@movie.id}:*")
    rc.each do |rc_key|
      RCache.del(rc_key)
    end
    
    redirect_to params[:bounceback]
  end
  
  private
  def setup_or_redirect
    if !params[:id]
      redirect_to :controller => 'search', :action => 'index'
      return
    end
    @movie = Movie.find(params[:id])
    @timer = { :start => Time.now }
  end
end
