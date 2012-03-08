class Hash
  def serializable_hash(options = nil, root_hash = nil)
    return self if !root_hash
    { root_hash.keys.first => self }
  end
end

module Levenshtein
  def self.new_distance(str1, str2, debug = false)
    dists = []
    dists << Levenshtein.distance(str1, str2)
    dists << Levenshtein.distance(str1.gsub(/\s*\([^)]*\)/,""), str2)
    dists << Levenshtein.distance(str1, str2)
    dists << Levenshtein.distance(str1.gsub(/\s*\([^)]*\)/,""), str2.gsub(/\s*\([^)]*\)/,""))
    dist = dists.min
    STDERR.puts("DEBUG: #{str1.inspect}:#{str2.inspect} #{dist}") if debug
    dist
  end
end

class Movie < ActiveRecord::Base
  IMDB_BASE="http://www.imdb.com/"
  IMDB_URL="#{IMDB_BASE}find"
  
  has_many :movie_akas
  has_many :episodes, :foreign_key => :parent_id, :class_name => "Movie"
  belongs_to :main, :foreign_key => :parent_id, :class_name => "Movie"
  has_one :next_episode
  has_one :prev_episode
  has_many :occupations
  has_many :people, :through => :occupations
  has_many :movie_genres
  has_many :genres, :through => :movie_genres
  has_many :movie_keywords
  has_many :keywords, :through => :movie_keywords
  has_many :movie_languages
  has_many :languages, :through => :movie_languages
  has_many :goofs
  has_many :trivia
  has_many :movie_years
  has_one :rating
  has_many :release_dates
  has_many :running_times
  has_many :taglines
  has_many :technicals
  has_many :plots
  has_many :color_infos
  has_many :alternate_versions
  has_many :certificates
  has_many :crazy_credits
  has_one :complete_cast
  has_one :complete_crew
  has_many :movie_connections
  has_many :quotes
  has_many :soundtrack_titles
  has_many :cast_members
  has_many :movie_directors
  has_one :search_score
  attr_accessor :score

  def is_swedish?
    if(languages.include?(Language.lang_id("Swedish")) &&
       first_release_date && first_release_date.country == "Sweden")
      return true
    end
    return false
  end
  
  def display(ignore_langfix = false, debug = false)
    return full_title if movie_akas.empty? || (is_swedish? && !ignore_langfix)

    cached_title = RCache.get(cache_prefix+"display_title")
    return cached_title if cached_title && !debug
    
    wpage = WikipediaFetcher.page(self)
    if wpage
      wpage = wpage.downcase
      full_title_distance = Levenshtein.new_distance(full_title.downcase, wpage, debug)
      title_distance = Levenshtein.new_distance(title.downcase, wpage, debug)
      distances = movie_akas.map do |maka|
        maka_distance = Levenshtein.new_distance(maka.title.downcase, wpage, debug)
        [maka_distance, 1, maka.title]
      end+[[full_title_distance, 0, full_title], [title_distance, 0, full_title]]
      
      STDERR.puts("DEBUG: distances: #{distances.inspect}") if debug
      
      display_title = distances.sort_by { |x| [x[0], x[1]] }[0][2]
      RCache.set(cache_prefix+"display_title", display_title)
      return display_title
    end
    
    scored_titles = movie_akas.map do |maka|
      priority = 0
      if maka.info
        if maka.info[/\(international: english title\)/i]
          priority += 2
        end
        
        if maka.info[/english title\)/i]
          priority += 2
        end
        
        if maka.info[/\(english title\)/i]
          priority += 1
        end
        
        if maka.info[/\(USA\)/i]
          priority += 1
        end
        
        if maka.info[/title\)/i]
          priority -= 1
        end
        
        if maka.info[/bootleg title\)/i]
          priority -= 2
        end
        
        if maka.info[/version\)/i]
          priority -= 1
        end
        
        if maka.info[/spelling\)/i]
          priority -= 3
        end
        
        if maka.info[/promotional/i]
          priority -= 3
        end
        
        if maka.info[/informal/i]
          priority -= 3
        end
        
        if maka.info[/abbreviation/i]
          priority -= 1
        end
        
        if maka.info[/dvd/i]
          priority -= 1
        end
        
        if maka.info[/director.s cut/i]
          priority -= 1
        end
        
        if maka.info[/(short|long) title\)/i]
          priority -= 3
        end
        
        if maka.info[/new zealand:/i]
          priority -= 1
        end
        
        if maka.info[/philippines:/i]
          priority -= 1
        end

        if maka.info[/singapore:/i]
          priority -= 1
        end

        if maka.info[/\(imdb display title\)/i] && maka.info[/english/i]
          priority += 2
        end
      end
      [priority, maka]
    end
    
    ordered_titles = scored_titles.sort_by { |x| -x[0] }
    
    if ordered_titles[0][0] < 1
      display_title = full_title
    else
      display_title = ordered_titles[0][1].title
    end
    RCache.set(cache_prefix+"display_title", display_title)
    display_title
  end

  def real_title?(allow_diff = 3)
    display == full_title || Levenshtein.distance(reduce_title(display), title) <= allow_diff
  end

  def reduce_title(in_title)
    in_title.gsub(/ \((TV|V|VG)\)$/,"").gsub(/ \([0-9?]{4}(|\/[IVX]+)\)( \{|$)/,"")
  end
  
  def episode_display(skip_nums = false)
    return nil if !is_episode
    nums = ""
    nums = " {#{episode_season}:#{episode_episode}}" if !skip_nums
    "#{episode_name}#{nums} (#{full_year})"
  end
  
  def next_episode
    return nil if !is_episode
    main.episodes_sorted[episode_index + 1]
  end
  
  def prev_episode
    return nil if !is_episode
    return nil if episode_index == 0
    main.episodes_sorted[episode_index - 1]
  end
  
  def episodes_sorted
    return nil if is_episode
    episodes.sort_by { |x| x.episode_sort }
  end
  
  def episode_index
    main.episodes.sort_by { |x| x.episode_sort }.index(self)
  end
  
  def episode_sort
    [episode_season || 0, episode_episode || 0, movie_sort_value || 0]
  end
  
  def category
    title_category ? title_category : "M"
  end

  def self.category_description(category_index)
    ["TV-series", "Movie", "TV", "Video", "Video game"][category_index]
  end
  
  def next_followed
    followed_by = MovieConnectionType.find_by_connection_type("followed by")
    mc = movie_connections.find_all_by_movie_connection_type_id(followed_by.id)
    return nil if mc.empty?
    selected = mc.select do |x|
      !x.linked_movie.suspended
    end
    return nil if selected.empty?
    selected.sort_by do |x|
      [x.linked_movie.title_year == "????" ? 99999 : x.linked_movie.title_year.to_i, (x.linked_movie.movie_sort_value || 0)]
    end.first.linked_movie
  end
  
  def prev_followed
    follows = MovieConnectionType.find_by_connection_type("follows")
    mc = movie_connections.find_all_by_movie_connection_type_id(follows.id)
    return nil if mc.empty?
    selected = mc.select do |x|
      !x.linked_movie.suspended
    end
    return nil if selected.empty?
    selected.sort_by do |x|
      [-(x.linked_movie.title_year == "????" ? 99999 : x.linked_movie.title_year.to_i), -(x.linked_movie.movie_sort_value || 0)]
    end.first.linked_movie
  end
  
  def crew_base
    occupations.
      joins(:role).
      includes(:person)
  end

  def crew_as_role_group(group_name)
    crew_base.where(:roles => { :group => group_name })
  end
  
  def crew_as_role(role_name)
    crew_base.where(:roles => { :role => role_name })
  end
  
  def occupation(person)
    crew_as_role_group(Role::GROUP_CAST).where(:person_id => person.id).first
  end
  
  def cast
    castlist = crew_as_role_group(Role::GROUP_CAST)
    collectlist = castlist.where(:collected => true).select(:person_id)
    sourcelist = castlist.where(:collected => false).where("person_id IN (#{collectlist.to_sql})")
    castlist.where("occupations.id NOT IN (#{sourcelist.select("occupations.id").to_sql})").
      order("CAST(sort_value AS INT),extras,character")
  end
  
  def strong_keywords
    strong = []
    plots.each do |plot|
      next if !plot || !plot.plot_norm
      tmpplot = plot.plot_norm.downcase.gsub("-", " ").gsub(/[^ a-z0-9]/, "")
      keywords.each do |keyword|
        tmpkeyword = keyword.keyword.downcase.gsub("-", " ").gsub(/[^ a-z0-9]/, "").norm
        if tmpplot.index(tmpkeyword)
          keyword.strong = true
          strong << keyword
        end
      end
    end
    strong.uniq
  end
  
  def first_release_date
    release_dates.order(:release_stamp).first
  end
  
  def has_additional?
    return true if !certificates.empty?
    return true if technicals.find_by_key("RAT")
    return true if !color_infos.empty?
    return true if !running_times.empty?
    return true if !languages.empty?
    return true if !movie_akas.empty?
    return false
  end
  
  def has_similar?
    Movie.select("movie_id").from("compare_overlaps").where("movie_id = ?", self.id).count != 0
  end
  
  def find_similar(result_count = 30)
    lc = "co.language_overlap_count::float"
    gc = "co.genre_overlap_count::float"
    knn = "co.normal_normal_count::float"
    kns = "co.normal_strong_count::float"
    ksn = "co.strong_normal_count::float"
    kss = "co.strong_strong_count::float"
    cmy = "convert_to_integer(m.title_year)::float"
    selfgc = genre_ids.count.to_f
    selfkc = keyword_ids.count.to_f
    selflc = language_ids.count.to_f
    selfskc = strong_keywords.count.to_f
    selfyear = title_year.to_i

    nnw = 1.0
    nsw = 2.0
    snw = 3.0
    ssw = 4.0
    gcw = 0.3
    lcw = 0.1
    yrw = 0.01

    score_kwnn = selfkc == 0 ? "" : "(#{nnw}*#{knn}/#{selfkc})"
    score_kwns = selfkc == 0 ? "" : "(#{nsw}*#{kns}/#{selfkc})"
    score_kwsn = selfskc == 0 ? "" : "(#{snw}*#{ksn}/#{selfskc})" 
    score_kwss = selfskc == 0 ? "" : "(#{ssw}*#{kss}/#{selfskc})"
    score_genre = selfgc == 0 ? "" : "(#{gcw}*#{gc}/#{selfgc})"
    score_lang = selflc == 0 ? "" : "(#{lcw}*#{lc}/#{selflc})"
    score_divisor = nnw+nsw+snw+ssw+gcw+lcw
    score_year = "(1+(ABS(#{cmy}-#{selfyear})*#{yrw}))"

    score_expr_top = ([score_kwnn, score_kwns, score_kwsn, 
                       score_kwss, score_genre, score_lang]-[""]).join("+")
    score_expr_middle = score_divisor
    score_expr_bottom = score_year

#    score_expr_top = "((1+#{lc}/10) * (1+#{gc}/5) * (#{knn}+2*#{kns}+2*#{ksn}+3*#{kss}))"
#    score_expr_middle = ((1+selflc/10.0)*(1+selfgc/5.0)*(selfkc))
#    score_expr_bottom = "(1+(ABS(#{cmy}-#{selfyear})/50.0))"
    score_expr = "(#{score_expr_top})/(#{score_expr_middle})/(#{score_expr_bottom})"
#    STDERR.puts(score_expr)
    query = "SELECT co.compare_movie_id AS id, #{score_expr} AS score_value"+
                                " FROM compare_overlaps co"+
                                " INNER JOIN movies m"+
                                "  ON co.compare_movie_id = m.id"+
                                " WHERE movie_id = #{self.id}"+
                                " ORDER BY 2 DESC"+
                                " LIMIT #{result_count}"
    movies = Movie.find_by_sql(query)

    movie_list = { }
    Movie.find_all_by_id(movies.map(&:id), :include => :rating).each do |movie|
      movie_list[movie.id.to_i] = movie
    end

    return (movies.map do |item|
              movie = movie_list[item.id.to_i]
              next if movie.nil?
              score = item.score_value.to_f
              score *= 100.0
              score = 100.0 if score > 100.0
              score = 15 if score <= 0.01
              [movie, sprintf("%3.1f%", score)]
    end - [nil])
  end
  
  def old_find_similar(result_count = 30)
    lc = "co.language_overlap_count::float"
    gc = "co.genre_overlap_count::float"
    knn = "co.normal_normal_count::float"
    kns = "co.normal_strong_count::float"
    ksn = "co.strong_normal_count::float"
    kss = "co.strong_strong_count::float"
    cmy = "convert_to_integer(m.title_year)::float"
    selfgc = genre_ids.count.to_f
    selfkc = keyword_ids.count.to_f
    selflc = language_ids.count.to_f
    selfyear = title_year.to_i

    score_expr_top = "((1+#{lc}/10) * (1+#{gc}/5) * (#{knn}+2*#{kns}+2*#{ksn}+3*#{kss}))"
    score_expr_middle = ((1+selflc/10.0)*(1+selfgc/5.0)*(selfkc))
    score_expr_bottom = "(1+(ABS(#{cmy}-#{selfyear})/50.0))"
    score_expr = "#{score_expr_top}/(#{score_expr_middle})/#{score_expr_bottom}"
    query = "SELECT co.compare_movie_id AS id, #{score_expr} AS score_value"+
                                " FROM compare_overlaps co"+
                                " INNER JOIN movies m"+
                                "  ON co.compare_movie_id = m.id"+
                                " WHERE movie_id = #{self.id}"+
                                " ORDER BY 2 DESC"+
                                " LIMIT #{result_count}"
    movies = Movie.find_by_sql(query)

    movie_list = { }
    Movie.find_all_by_id(movies.map(&:id), :include => :rating).each do |movie|
      movie_list[movie.id.to_i] = movie
    end

    return (movies.map do |item|
              movie = movie_list[item.id.to_i]
              next if movie.nil?
              score = item.score_value.to_f
              score *= 100.0
              score = 100.0 if score > 100.0
              score = 15 if score <= 0.01
              [movie, sprintf("%3.1f%", score)]
    end - [nil])
  end
  
  def active_episodes
    active = @active_episodes || []
    active.sort_by { |x| x[:episode].episode_sort }
  end
  
  def add_active_episode(episode, occupation)
    @active_episodes ||= []
    @active_check ||= { }
    return if @active_check[[episode,occupation]]
    @active_check[[episode,occupation]] = true
    @active_episodes << { 
      :episode => episode,
      :occupation => occupation
    }
    nil
  end

  def cast_members
    cast.map do |cast_member|
      {
        :cast_id => cast_member.id,
        :person_id => cast_member.person_id,
        :person_name => cast_member.person.name(true),
        :character => cast_member.character,
        :sort_value => cast_member.sort_value
      }
    end.sort_by do |item|
      item[:sort_value].nil? ? 1000000 : item[:sort_value].to_i
    end
  end

  def movie_directors
    crew_as_role("director").map do |director|
      {
        :person => director.person,
        :extras => director.extras
      }
    end
  end
  
  def search_score
    [{ :score => @score }]
  end
  
  def serialize_complete_options(options = {})
    default_options = {
      :skip_types => true,
      :include => {
        :plots => { },
        :keywords => { },
        :genres => { },
        :occupations => {
          :include => {
            :person => { },
            :role => { }
          }
        },
        :languages => { },
        :goofs => { },
        :trivia => { },
        :movie_years => { },
        :running_times => { },
        :rating => { },
        :complete_cast => { },
        :complete_crew => { },
        :release_dates => { },
        :soundtrack_titles => {
          :include => {
            :soundtrack_title_data => { }
          }
        },
        :movie_connections => { },
        :taglines => { },
        :technicals => { },
        :alternate_versions => { },
        :certificates => { },
        :color_infos => { },
        :crazy_credits => { },
        :episodes => {
          :include => {
            :plots => { },
            :release_dates => { }
          }
        },
        :next_episode => { },
        :prev_episode => { },
        :main => { }
      }
    }
    
    default_options.merge(options)
  end
  
  def serialize_reduced_options(options = { })
    default_options = {
      :skip_types => true,
      :include => {
        :release_dates => { },
        :rating => { },
        :running_times => { },
        :plots => { },
        :taglines => { },
        :cast_members => { },
        :languages => { },
        :keywords => { },
        :genres => { },
        :movie_directors => { },
        :search_score => { }
      },
    }
    default_options.merge(options)
  end

  alias old_to_xml to_xml
  alias old_to_json to_json
  
  def to_xml(options = { })
    old_to_xml(serialize_reduced_options(options))
  end
  
  def to_json(options = { })
    old_to_json(serialize_reduced_options(options))
  end
  
  def to_complete_xml(options = { })
    old_to_xml(serialize_complete_options(options))
  end

  def to_complete_json(options = { })
    old_to_json(serialize_complete_options(options))
  end
  
  def to_reduced_xml(options = { })
    old_to_xml(serialize_reduced_options(options))
  end

  def to_reduced_json(options = { })
    old_to_json(serialize_reduced_options(options))
  end
  
  def to_specified_data(format, richness = "complete")
    richness = "complete" if richness.nil? || richness.empty?
    optionset = nil
    optionset = serialize_complete_options if richness == "complete"
    optionset = serialize_reduced_options if richness == "reduced"
    return "" if optionset.nil?

    return to_xml(optionset) if format == :xml
    return to_json(optionset) if format == :json
    return ""
  end

  def wikipedia_query_list
    done = []
    list = []
    list2 = []
    wikipedia_query_addons.each do |addon|
      list2 << "#{title} (#{full_year} #{addon})"
      list2 << "#{title} (#{addon})"
    end
    list2 << full_title
    list2 << full_title.gsub(/[\":!]/,"")
    list2 << "#{title} (#{full_year})"
    list2 << "#{title} (#{full_year})".gsub(/[\":!]/,"")
    list << title
    list << title.gsub(/\&/, is_swedish? ? "och" : "and").gsub(/([a-z])([A-Z])/, '\1-\2')
    list << title.gsub(/[\":!]/,"")
    list << title.gsub(/[\":!]/,"").gsub(/ (the|a|an|of) /i) {|x| x.gsub($1, $1.downcase) }
    movie_akas.select do |maka|
      maka.info && maka.info[/english/i]
    end.each do |maka|
      done << maka
      wikipedia_query_addons.each do |addon|
        list2 << "#{maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")} (#{full_year} #{addon})"
        list2 << "#{maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")} (#{addon})"
      end
      list2 << maka.title.gsub(/[\":!]/,"")
      list2 << maka.title.gsub(/ \(\d\d\d\d\)/, "")
      list2 << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
    end
    movie_akas.select do |maka|
      maka.info && maka.info[/imdb display/i] && !done.include?(maka)
    end.each do |maka|
      done << maka
      list << maka.title
      list << maka.title.gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
    end
    movie_akas.select do |maka|
      !done.include?(maka)
    end.each do |maka|
      list << maka.title
      list << maka.title.gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "")
      list << maka.title.gsub(/ \(\d\d\d\d\)/, "").gsub(/ \((TV|V|VG)\)/, "").gsub(/[\":!]/,"")
    end
    
    list.each do |item|
      wikipedia_query_addons.each do |addon|
        list2 << "#{item} (#{full_year} #{addon})"
        list2 << "#{item} (#{addon})"
      end
      list2 << item
    end
    
    output = []
    list2.each do |item|
      output << item
      output << item.titleize
    end
    
    output.uniq
  end
  
  def wikipedia_query_addons
    addons = []
    case category
    when "TVS"
      addons << "TV series"
      addons << "TV Serial"
    when "VG"
      addons << "video game"
      addons << "game"
    else
      addons << "film"
      addons << "miniseries"
    end
    addons
  end

  def wikipedia_fetching_object
    main || self
  end
  
  def wikipedia_opensearch_list
    list = []
    wikipedia_query_addons.each do |addon|
      list << "#{title_norm} (#{addon})"
      list << "#{title_norm} (#{full_year} #{addon})"
    end
    list << "#{title_norm} (#{full_year})"
    list << title_norm
    wikipedia_query_addons.each do |addon|
      movie_akas.each do |maka|
        list << "#{maka.title_norm} (#{addon})"
        list << "#{maka.title_norm} (#{full_year} #{addon})"
      end
    end
    movie_akas.each do |maka|
      list << "#{maka.title_norm} (#{full_year})"
      list << "#{maka.title_norm}"
    end
    list.uniq
  end
  
  def query_source(simple = false)
    simple ? "movies-simple" : "plots"
  end
  
  def cache_prefix
    "movie:#{id.to_s}:"
  end
  
  def has_plot?
    return true if !plots.empty?
    return true if WikipediaFetcher.plot(self)
    return false
  end

  def is_game?
    return true if title_category == "VG"
    return false
  end

  def wikipedia_purge_all
    RCache.data.keys("movie:#{self.id}:wikipedia*").each do |key|
      RCache.del(key)
    end
  end
  
  def imdbid
    @imdbid = imdb_id
    if !@imdbid
      begin
        isotitle = Iconv.conv("iso-8859-1", "utf-8", full_title)
      rescue
        return nil
      end
      res = Net::HTTP.post_form(URI.parse(IMDB_URL), { :s => "tt", :q => isotitle })
      return nil if !res["location"]
      @imdbid = res["location"].scan(/\/title\/(tt\d+)\//).first.first
      return nil if @imdbid.blank?
      update_attribute(:imdb_id, @imdbid)
    end
    @imdbid
  end
  
  def imdb_data(page = "movieconnections")
    cached = RCache.get("movie:#{self.id}:imdb:page_#{page}")
    return cached if cached
    @imdbid = imdbid
    return nil if !@imdbid
    begin
      headers = {
        "Accept-Language" => "en-us,en;q=0.5",
      }
      io = open(IMDB_BASE+"title/#{@imdbid}/"+page, headers)
      page_data = io.read
      doc = Nokogiri::HTML(page_data)
      content = doc.search("#tn15content")
      return nil if content.blank?
      content = content.to_s.gsub(/.*?(<h5>.*)<hr>.*/m,'\1').gsub(/\n?<br>/m,"\n<br>\n").gsub(/^<br>\n/,"")
      content = Iconv.conv("utf-8", "iso-8859-1", content)
      RCache.set("movie:#{self.id}:imdb:page_#{page}", content, 90.days)
    rescue
      return nil
    end
    content
  end

  def debug_mc_unmatched
    @debug_mc_unmatched ||= []
  end

  def debug_mc_unmatched=(value)
    @debug_mc_unmatched ||= []
    @debug_mc_unmatched << value
  end
  
  def debug_mc_unmatched_undo(value)
    @debug_mc_unmatched ||= []
    @debug_mc_unmatched = @debug_mc_unmatched.select { |x| x[0] != value }
  end
  
  def debug_mc_unfound
    @debug_mc_unfound ||= []
  end
  
  def debug_mc_unfound=(value)
    @debug_mc_unfound ||= []
    @debug_mc_unfound << value
  end
  
  def scan_movie_connections
    @debug_mc_unmatched ||= []
    @debug_mc_unfound ||= []
    idata = imdb_data
    return nil if !idata
    
    @mcs = { }
    movie_connections.each do |mc|
      @mcs[[mc.linked_movie.imdb_movie_title, mc.type.capitalize]] = mc.linked_movie_id
      @mcs[[mc.linked_movie.imdb_movie_title(false), mc.type.capitalize]] = mc.linked_movie_id
      @mcs[[mc.linked_movie.imdb_movie_title(true, true), mc.type.capitalize]] = mc.linked_movie_id
      @mcs[[mc.linked_movie.imdb_movie_title(false, true), mc.type.capitalize]] = mc.linked_movie_id
    end

    unfound = movie_connections.map { |x| [x.linked_movie_id, x.type.capitalize] }
    done = false
    second_run = false
    final_run = false
    
    while !done
      last_category = nil
      got_connection = nil
      last_unmatched = nil
      idata.split("\n").each do |line|
        if line[/^<h5>([^<]+)<\/h5>$/]
          last_category = $1
          got_connection = nil
          last_unmatched = nil
          next
        end

        if last_category && line[/<a href=\"\/title\/(tt\d+)\/\">([^<]+)<\/a>(| \((\d{4}[\/IVX]*)\)| \((\d{4}[\/IVX]*)\) \((V|TV|VG)\))$/]
          got_connection = nil
          imdbid = $1
          imdb_title = CGI.unescapeHTML($2)
          imdb_type = nil
          imdb_year = nil
          if $6
            imdb_year = $5
            imdb_type = $6
          else
            imdb_year = $4
          end
          got_connection = matches_movie(imdbid, imdb_title, imdb_year, imdb_type, last_category)
          if got_connection
            unfound.delete([got_connection, last_category])
            RCache.set("movie:#{self.id}:imdb:link_info_#{got_connection}:#{last_category}", "[NONE]", 30.days)
            if second_run || final_run
              matching = [imdbid, imdb_title, imdb_year, imdb_type, last_category]
              self.debug_mc_unmatched_undo(matching)
            end
            last_unmatched = nil
          else
            last_unmatched = [imdbid, imdb_title, imdb_year, imdb_type, last_category]
          end
        end

        if got_connection && line[/^\u00a0-\u00a0 (.*)$/]
          RCache.set("movie:#{self.id}:imdb:link_info_#{got_connection}:#{last_category}", $1, 30.days)
          got_connection = nil
        end
        
        if last_unmatched && line[/^\u00a0-\u00a0 (.*)$/]
          self.debug_mc_unmatched=[last_unmatched, $1] if !second_run && !final_run
          last_unmatched = nil
        end
      end

      if final_run
        done = true
      end

      if !second_run
        @mcs = { }
      end
      
      unfound.each do |linked|
        if second_run || final_run
          self.debug_mc_unfound=linked
        else
          linked_movie = Movie.find(linked[0])
          linked_type = movie_connections.where(:linked_movie_id => linked[0]).first.type
          akas = linked_movie.is_episode ? linked_movie.main.movie_akas : linked_movie.movie_akas
          akas.each do |maka|
            @mcs[[linked_movie.imdb_movie_title(true, false, maka.title), linked_type.capitalize]] = linked[0]
            @mcs[[linked_movie.imdb_movie_title(false, false, maka.title), linked_type.capitalize]] = linked[0]
          end
        end
        RCache.set("movie:#{self.id}:imdb:link_info_#{linked[0]}:#{linked[1]}", "[NONE]", 30.days)
      end
      
      if unfound.blank?
        done = true
        next
      end
      if !second_run && !final_run
        second_run = true
        next
      end
    
      if final_run
        done = true
        next
      end
      
      if second_run
        second_run = false
        final_run = true
      end

      unfound.each do |linked|
        Movie.find(linked[0]).imdbid
      end
    end
    nil
  end
  
  def matches_movie(imdbid, imdb_title, imdb_year, imdb_type, last_category)
    iyear = " (#{imdb_year})"
    extras = imdb_type ? " (#{imdb_type})" : ""
    full_imdb_title = "#{imdb_title}#{iyear}#{extras}"
    if @mcs[[full_imdb_title, last_category]]
      update_attribute(:imdb_id, imdbid)
      return @mcs[[full_imdb_title, last_category]]
    end
    if @mcs[[imdb_title, last_category]]
      return @mcs[[imdb_title, last_category]]
    end
    return nil
  end
  
  def imdb_movie_title(include_year_and_extras = true, use_display_title = false, force_title = nil)
    used_title = title if !use_display_title
    used_title = reduce_title(display(true)) if use_display_title
    used_title = reduce_title(force_title) if force_title
    if is_episode
      ititle = used_title.gsub(/^\"(.*)\"$/, '\1')
      iepisode_data = ""
      if episode_name.blank? && episode_season && episode_episode
        iepisode_data = "Episode ##{episode_season}.#{episode_episode}"
      elsif !episode_name.blank? && episode_season && episode_episode
        iepisode_data = "#{episode_name} (##{episode_season}.#{episode_episode})"
      elsif !episode_name.blank? && !(episode_season && episode_episode)
        if episode_name[/\((\d\d\d\d-\d\d-\d\d\))/]
          stamp = Time.parse($1)
          iepisode_data = stamp.strftime("Episode dated %d %B %Y")
        else
          iepisode_data = "#{episode_name}"
        end
      end
      iyear = first_release_date ? first_release_date.release_stamp.year : full_year
      iyeardata = include_year_and_extras ? " (#{iyear})" : ""
      return "\"#{ititle}: #{iepisode_data}\"#{iyeardata}"
    else
      extras = ""
      if ["V", "VG", "TV"].include?(title_category)
        extras = " (#{title_category})"
      end
      iyeardata = include_year_and_extras ? " (#{full_year})#{extras}" : ""
      return "#{used_title}#{iyeardata}"
    end
  end
  
  def self.imdb_clear_cache(empty_data_only = true)
    RCache.data.keys("*:imdb:*").each do |key|
      next if empty_data_only && RCache.get(key) != "[NONE]"
      RCache.del(key)
    end
  end
  
  def image_url
    return WikipediaFetcher.image(self)
  end
  
  def valid_mobile_pages
    pages = [["cast", "Cast"]]
    pages << ["episodes", "Episodes"] if !episodes.blank?
    pages << ["additional_details", "Additional Details"] if has_additional?
    pages << ["trivia", "Trivia"] if !trivia.blank?
    pages << ["goofs", "Goofs"] if !goofs.blank?
    pages << ["plot", "Plot"] if !plots.blank?
    pages << ["keyword", "Keywords"] if !keywords.blank?
    pages << ["connections", "Movie Connections"] if !movie_connections.blank?
    pages << ["soundtrack", "Soundtrack"] if !soundtrack_titles.blank?
    pages << ["quotes", "Quotes"] if !quotes.blank?
    pages << ["similar", "Similar Movies"] if has_similar?
    pages
  end
  
  def episode_position_display
    return nil if !is_episode?

    if episode_episode && episode_season
      return "Episode #{episode_episode} of Season #{episode_season} of"
    elsif episode_episode && !episode_season
      return "Episode #{episode_episode} of"
    elsif !episode_episode && episode_season
      return "Episode in Season #{episode_season} of"
    else
      return "Episode of"
    end
  end
end
