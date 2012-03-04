class MovieConnection < ActiveRecord::Base
  attr_accessor :imdb_info
  
  belongs_to :movie
  belongs_to :movie_connection_type
  belongs_to :linked_movie, :class_name => "Movie", :foreign_key => :linked_movie_id
  
  def type
    movie_connection_type.connection_type
  end
  
  def imdb_extra_info(exit_if_miss = false)
    cached = RCache.get("movie:#{movie_id}:imdb:link_info_#{linked_movie_id}:#{type.capitalize}")
    return nil if cached && cached == "[NONE]"
    return cached.gsub(/<a href="[^"]+">([^<]+)<\/a>/, '\1') if cached
    return nil if exit_if_miss
    movie.scan_movie_connections
    imdb_extra_info(true)
  end
end
