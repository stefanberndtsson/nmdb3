class Search
  MAX_FACET=20
  
  def self.query(query, source = nil, filters = [], forced_output_limit = nil, max_facet_override = nil)
    @max_facet = max_facet_override || MAX_FACET
    query = query.norm
    scores = { }
    config = Rails.configuration.database_configuration[RAILS_ENV]
    sph = Riddle::Client.new(config["host"], 9312)
    sph.match_mode = :extended2
    sph.max_matches = 10000
    sph.limit = sph.max_matches
    sph.field_weights = {
      :title => 120,
      :episode_title => 15,
      :name => 50,
      :cast => 4,
      :movie => 8,
      :character => 2,
      :genre => 5,
      :keyword => 5,
      :language => 3,
      :first => 10,
      :last => 10,
      :plot => 1000,
      :quote => 1000,
      :director => 1,
      :producer => 1,
      :writer => 1,
      :trivia => 1000,
      :goofs => 1000,
      :biography => 1
    }

    result = {
      :exact_person_count => 0,
      :exact_person => [],
      :people_count => 0,
      :people => [],
      :exact_movie_count => 0,
      :exact_movie => [],
      :movies_count => 0,
      :movies => []
    }

    if filters.empty?
      if source.blank? || source == "people"
        already_matched = []
        if !query.match(/@/)
          sph.max_matches = 5
          res = sph.query("@@relaxed ^#{query}$", "people-simple")
          result[:exact_person_count] = res[:total_found]
          tmp_matches= res[:matches].map do |m|
            tmp = already_matched.include?(m[:doc]) ? nil : [m[:doc], m[:weight]]
            already_matched << m[:doc]
            tmp
          end-[nil]
          result[:exact_person] = tmp_matches.map do |x|
            p = Person.find(x[0])
            p.score = x[1]
            p
          end
        end
        sph.max_matches = forced_output_limit || 20
        res = sph.query("@@relaxed #{query}", "biography")
        result[:people_count] = res[:total_found]
        tmp_matches = res[:matches].map do |m|
          already_matched.include?(m[:doc]) ? (result[:people_count] -= 1; nil) : [m[:doc], m[:weight]]
        end-[nil]
        result[:people] = tmp_matches.map do |x|
          p = Person.find(x[0])
          p.score = x[1]
          p
        end
      end
    end
    
    if source.blank? || ["movies", "plots", "quotes"].include?(source)
      already_matched = []
      if !query.match(/@/) && filters.empty? && !["plots", "quotes"].include?(source)
        sph.max_matches = 5
        sph.sort_mode = :expr
        sph.sort_by = Search.sort_expr
        res = sph.query("@@relaxed (@title ^#{query}$) | (@episode_title ^#{query}$)", "movies-simple")
        result[:exact_movie_count] = res[:total_found]
        tmp_matches = res[:matches].map do |m|
          tmp = already_matched.include?(m[:doc]) ? nil : m
          already_matched << m[:doc]
          tmp
        end-[nil]
        movie_list = Movie.where(:id => tmp_matches.map { |x| x[:doc] }).includes(:movie_akas).group_by { |x| x.id }
        result[:exact_movie] = tmp_matches.map do |x|
          tmp = movie_list[x[:doc]].first
          tmp_score = Search.score(x[:weight], 1, x[:attributes]["is_episode"],
                                   x[:attributes]["link_score"],
                                   x[:attributes]["occupation_score"],
                                   x[:attributes]["keyword_ids"],
                                   x[:attributes]["category"],
                                   x[:attributes]["votes"],
                                   x[:attributes]["rating"])
          tmp.score = tmp_score
          scores[tmp_score] = tmp
          tmp
        end
      end

      sph.max_matches = 10000
      sph.filters = filters
      sph.sort_mode = :expr
      sph.sort_by = Search.sort_expr
      used_source = source
      used_source = "movies" if source.blank?
      results = sph.query(query, used_source)

      partial_facets = false
      if (results[:total_found] || 0) > sph.max_matches
        partial_facets = true
      end
      
      facets = calculate_facets(results, sph, @max_facet)
      
      output_limit = forced_output_limit.nil? ? 20 : forced_output_limit
      
      if(result[:exact_person_count] == 0 &&
         result[:people_count] == 0)
        # We're doing only titles now. Let's extend limits.
        
        if results[:total_found].to_i < 80
          output_limit = forced_output_limit.nil? ? results[:total_found].to_i : forced_output_limit
        else
          output_limit = forced_output_limit.nil? ? 50 : forced_output_limit
        end
        
      end
      
      movie_ids = []
      results[:matches].each do |x| 
        movie_ids << x if !already_matched.include?(x[:doc])
        break if movie_ids.length >= output_limit
      end
      movie_list = Movie.where(:id => movie_ids.map { |x| x[:doc] }).includes(:movie_akas).group_by { |x| x.id }
      movies = movie_ids.map do |x| 
        tmp = movie_list[x[:doc]].first
        tmp_score = Search.score(x[:weight], 0, x[:attributes]["is_episode"],
                                 x[:attributes]["link_score"],
                                 x[:attributes]["occupation_score"],
                                 x[:attributes]["keyword_ids"],
                                 x[:attributes]["category"],
                                 x[:attributes]["votes"],
                                 x[:attributes]["rating"])
        tmp.score = tmp_score
        scores[tmp_score] = tmp
        tmp
      end

      result[:movies_count] = results[:total_found]
      result[:movies] = movies
      result[:scores] = scores
    end
    
    return [result, facets || { }, partial_facets]
  end
  
  def self.calculate_facets(results, sph, max_facet)
    @max_facet = max_facet
    facets = { }
    episodes = results[:matches].map { |x| x[:attributes]["is_episode"] }
    e_group = episodes.group_by { |x| x }
    facets["episode"] = e_group.keys.map { |x| [x, e_group[x].length] }.sort_by { |y| y[0] }
    
    categories = results[:matches].map { |x| x[:attributes]["category"] }
    c_group = categories.group_by { |x| x }
    facets["category"] = c_group.keys.map { |x| [x, c_group[x].length] }.sort_by { |y| -y[1] }
    
    keywords = results[:matches].map { |x| x[:attributes]["keyword_ids"] }.flatten
    k_group = keywords.group_by { |x| x }
    facets["keyword"] = k_group.keys.map do |x|
      [x, k_group[x].length]
    end.sort_by { |y| -y[1] }[0..@max_facet-1].map do |z|
      [facet_object("keyword", z[0]), z[1]]
    end.sort_by { |w| [-w[1], w[0].keyword] }

    genres = results[:matches].map { |x| x[:attributes]["genre_ids"] }.flatten
    g_group = genres.group_by { |x| x }
    facets["genre"] = g_group.keys.map do |x|
      [x, g_group[x].length]
    end
    facets["genre"] = facets["genre"].sort_by { |y| -y[1] }[0..@max_facet-1].map do |z|
      [facet_object("genre", z[0]), z[1]]
    end
    facets["genre"] = facets["genre"].select { |x| !x[0].genre.nil?}
    facets["genre"] = facets["genre"].sort_by { |w| [-w[1], w[0].genre] }

    languages = results[:matches].map { |x| x[:attributes]["language_ids"] }.flatten
    l_group = languages.group_by { |x| x }
    facets["language"] = l_group.keys.map do |x|
      [x, l_group[x].length]
    end.sort_by { |y| -y[1] }[0..@max_facet-1].map do |z|
      [facet_object("language", z[0]), z[1]]
    end.sort_by { |w| [-w[1], w[0].language] }

    years = results[:matches].map { |x| x[:attributes]["year_attr"] }.flatten
    y_group = years.group_by { |x| x }
    facets["year"] = y_group.keys.map { |x| [x, y_group[x].length] }.sort_by { |y| -y[0] } #[0..@max_facet-1]

    ratings = results[:matches].map { |x| (10*x[:attributes]["rating"].to_f).to_i }.flatten.select { |x| x > 0 }
    y_group = ratings.group_by { |x| x }
    facets["rating"] = y_group.keys.map { |x| [x, y_group[x].length] }.sort_by { |y| -y[0] } #[0..@max_facet-1]
#    decades = results[:matches].map { |x| x[:attributes]["decade_attr"] }.flatten
#    d_group = decades.group_by { |x| x }
#    facets["decade"] = d_group.keys.map { |x| [x, d_group[x].length] }.sort_by { |y| -y[0] }[0..@max_facet-1]

    # Remove selected facets
    sph.filters.each do |filter|
      facet_name = facet_name(filter.attribute)
      if facet_name == "rating"
      elsif facets[facet_name]
        filter.values.each do |filter_value|
          facets[facet_name] = facets[facet_name].select do |facet|
            (facet_id(facet[0]).to_i != filter_value.to_i) || ["year", "rating"].include?(facet_name)
          end
        end
      end
    end

    # Remove facets covering the entire result
    facets.keys.each do |facet_name|
      facets[facet_name] = facets[facet_name].select do |facet|
        facet[1] != results[:total_found]
      end
    end
    
    facets
  end
  
  def self.sort_expr
    aws = Keyword.find_by_keyword("awards-show")
    aw = Keyword.find_by_keyword("award")

    catmult = "(3*iN(category, 2)+2*iN(category, 0)+1*iN(category, 3))"
    awsmult = "iN(keyword_ids, #{aws.id})*3*#{catmult}"
    awmult = "iN(keyword_ids, #{aw.id})*1*#{catmult}"
    
    award_score = "5000*#{awmult}-5000*#{awsmult}"
    
    "100000*(1-is_episode)+@weight+(3*link_score)*(occupation_score/30.0)+3*link_score+15*occupation_score-#{award_score}+votes/5.0"
  end

  # This is named as it is to not collide with the keyword 'in' and still work as a method whe
  # running eval on the sort_expr above which needs the method to be called in() since sphinx
  # has that name for it.
  def self.iN(expr, val1)
    if expr.class == Array
      return 1.0 if expr.include?(val1)
      return 0.0
    end
    return 1.0 if expr == val1
    return 0.0
  end
  
  def self.score(weight, from_exact, is_episode, link_score, occupation_score, 
                 keyword_ids, category, votes, rating)
    return nil if !weight || !from_exact || !is_episode || !link_score || !occupation_score
    @weight = weight
    value = eval sort_expr
    return 10000*from_exact + value
  end
  
  def self.facet_name(filter_attribute)
    case filter_attribute
    when "year_attr"
      return "year"
    when "decade_attr"
      return "decade"
    when "genre_ids"
      return "genre"
    when "keyword_ids"
      return "keyword"
    when "language_ids"
      return "language"
    when "is_episode"
      return "episode"
    end
    return filter_attribute
  end

  def self.facet_object(facet_name, facet_value)
    f_object = facet_value
    f_object = Genre.find(facet_value) if facet_name == "genre"
    f_object = Keyword.find(facet_value) if facet_name == "keyword"
    f_object = Language.find(facet_value) if facet_name == "language"
    return f_object
  end
  
  def self.facet_id(facet_object)
    return facet_object if facet_object.class == Integer || facet_object.class == Fixnum
    return facet_object.id
  end
  
  def self.dym_movie_old(q)
    trimmed = q.gsub(/[^\w\s]/,"").gsub(/\s+/," ").gsub(/^\s+/,"").gsub(/\s+$/,"")
    Movie.find_by_sql(["SELECT m.id FROM (SELECT sm.movie_id,levenshtein(?, sm.norm_title),sm.link_score,sm.occupation_score FROM suggest_movies sm ORDER BY levenshtein,(occupation_score*link_score) DESC) n INNER JOIN movies m ON m.id = n.movie_id LIMIT 50", trimmed]).map{ |x| x.id.to_i }
  end

  def self.dym_movie(q, max_limit = 50, include_score = false)
    trimmed = q.gsub(/[^\w\s]/,"").gsub(/\s+/," ").gsub(/^\s+/,"").gsub(/\s+$/,"").downcase
    Movie.find_by_sql(["SELECT DISTINCT m.id,m.full_title,n.levenshtein,(n.occupation_score*n.link_score) AS dym_score FROM (SELECT sm.movie_id,levenshtein(?, substr(sm.norm_title, 1, ?)),sm.link_score,sm.occupation_score FROM suggest_movies sm ORDER BY levenshtein,(occupation_score*link_score) DESC LIMIT ?) n INNER JOIN movies m ON m.id = n.movie_id ORDER BY n.levenshtein,(n.occupation_score*n.link_score) DESC LIMIT ?", trimmed, trimmed.size, max_limit*10, max_limit]).map do |x|
      include_score ? [x.id.to_i, x.levenshtein.to_i, x.dym_score.to_i, :movie] : x.id.to_i
    end
  end

  def self.dym_movie_tmp(q)
    trimmed = q.gsub(/[^\w\s]/,"").gsub(/\s+/," ").gsub(/^\s+/,"").gsub(/\s+$/,"")
    # Skip adult movies here. They're usually poorly named for suggestions.
    adult_id = Genre.where(:genre => "Adult").select(:id).first
    adult_id = adult_id.blank? ? 0 : adult_id.id
    Movie.find_by_sql(["SELECT m.id FROM (SELECT sm.movie_id,levenshtein(?, substr(regexp_replace(sm.norm_title, E'^(the |a |an )', ''), 1, ?)),sm.link_score,sm.occupation_score FROM suggest_movies sm ORDER BY levenshtein,(occupation_score*link_score) DESC) n INNER JOIN movies m ON m.id = n.movie_id WHERE m.id IN (SELECT movie_id FROM movie_genres WHERE genre_id != ?) LIMIT 50", trimmed, trimmed.size, adult_id]).map{ |x| x.id.to_i }
  end

  def self.dym_person(q, max_limit = 50, occupation_score_minimum = 0, include_score = false)
    trimmed = q.gsub(/[^\w\s]/,"").gsub(/\s+/," ").gsub(/^\s+/,"").gsub(/\s+$/,"").downcase
    Person.find_by_sql(["SELECT DISTINCT p.id,p.full_name,n.levenshtein,((n.occupation_score/n.score_count)*n.link_score) AS dym_score FROM (SELECT sp.person_id,levenshtein(?, substr(sp.norm_name, 1, ?)),sp.link_score,sp.occupation_score,sp.score_count FROM suggest_people sp WHERE occupation_score > ? ORDER BY levenshtein,((occupation_score/score_count)*link_score) DESC LIMIT ?) n INNER JOIN people p ON p.id = n.person_id ORDER BY n.levenshtein,((n.occupation_score/n.score_count)*n.link_score) DESC LIMIT ?", trimmed, trimmed.size, occupation_score_minimum, max_limit*10, max_limit]).map do |x|
      include_score ? [x.id.to_i, x.levenshtein.to_i+1, x.dym_score.to_i, :person] : x.id.to_i
    end
  end
end
