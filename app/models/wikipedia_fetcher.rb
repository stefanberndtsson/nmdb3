module Wikipedia
  class Page
    def page
      return { } if !@data['query']['pages']
      @data['query']['pages'].values.first
    end
    
    def redirect?
      content && content.match(/\#REDIRECT\s*\[\[(.*?)\]\]/i)
    end
  end
end

class WikipediaFetcher
  class NoMoreDataException < Exception
  end
  
  WIKIPEDIA_EXPIRE=30.days

  def self.get_or_fetch(object, key, fetch = false, query_indexpoint = nil)
    object = object.wikipedia_fetching_object
    value = RCache.get(object.cache_prefix+"wikipedia:"+key)
    return value if value
    return nil if !fetch
    last_check = Time.at(RCache.get(object.cache_prefix+"wikipedia:last_check").to_i)
    return nil if fetch && last_check > (Time.now - 4.hours)
    if find_page(object, false, query_indexpoint)
      return RCache.get(object.cache_prefix+"wikipedia:"+key)
    end
  end
  
  def self.image(object, fetch = false, query_indexpoint = nil)
    get_or_fetch(object, "image", fetch, query_indexpoint)
  end
  
  def self.page(object, fetch = false)
    get_or_fetch(object, "page", fetch)
  end
  
  def self.plot(object, fetch = false)
    get_or_fetch(object, "plot", fetch)
  end

  def self.year_movie_lookup(wclient, movie, debug = false)
    wclient ||= Wikipedia::Client.new
    titles = []
    if movie.is_game?
      titles << [movie.title_norm, :game]
      titles += movie.movie_akas.select { |x| x.info && x.info[/english/i] }.map { |x| [x.title_norm, :game] }
    else
      if movie.title_category == "TV"
        titles << [movie.title_norm, :tv]
        titles += movie.movie_akas.select { |x| x.info && x.info[/english/i] }.map { |x| [x.title_norm, :tv] }
      end
      titles << [movie.title_norm, :normal]
      titles += movie.movie_akas.select { |x| x.info && x.info[/(swedish|sweden|english|usa)/i] }.map { |x| [x.title_norm, :normal] }
    end
    best_match = 999999999
    best_title = nil
    firstchar_lookup = { }
    firstchar_lookup[:normal] = { }
    firstchar_lookup[:tv] = { }
    firstchar_lookup[:game] = { }
    titles.each do |item|
      title, type = item
#      first_chars = title.gsub(/^(das|the|a|an) /,"").gsub(/^\s+/,"").gsub(/[^a-z0-9 ]/, "")[0..1].upcase
#      last_chars = first_chars[0] + (first_chars[1].ord+1).chr
      first_chars = title.gsub(/^(das|the|a|an) /,"").gsub(/^\s+/,"").gsub(/[^a-z0-9 ]/, "")[0].upcase
      last_chars = (first_chars[0].ord+1).chr
      STDERR.puts("DEBUG: Title: #{title}: #{first_chars}-#{last_chars}") if debug
      reply = firstchar_lookup[type][first_chars]
      if !reply
        cmtitle = "Category:#{movie.title_year} films" if type == :normal
        cmtitle = "Category:#{movie.title_year} television films" if type == :tv
        cmtitle = "Category:#{movie.title_year} video games" if type == :game
        reply = JSON.parse(wclient.request_page("",
                                                :action => "query", 
                                                :list => "categorymembers", 
                                                :cmnamespace => 0, 
                                                :cmlimit => 500, 
                                                :cmtype => "page", 
                                                :cmstartsortkey => first_chars,
                                                :cmendsortkey => last_chars,
                                                :cmtitle => cmtitle))
        firstchar_lookup[type][first_chars] = reply
      end
      pagelist = reply["query"]["categorymembers"].map { |x| x["title"] }
      pagelist.each do |page|
        page_norm = page.norm.gsub(/\([^\)]*\)/,"").gsub(/^\s+/,"").gsub(/\s+$/,"").gsub(/[^a-z0-9 ]/,"")
        STDERR.puts("DEBUG: Comparing: #{page_norm} with #{title}") if debug
        distance = Levenshtein.distance(page_norm, title)
        if distance < best_match
          STDERR.puts("DEBUG: Found new best match: #{distance}") if debug
          best_match = distance
          best_title = page
          return page if distance == 0
        end
      end
    end
    return best_title if best_title && best_match < 6
    return nil
  end
  
  def self.year_person_lookup(wclient, person, debug = false)
    return nil if !person.stamp_of_birth
    birth_year = person.stamp_of_birth.year
    wclient ||= Wikipedia::Client.new
    names = [[person.last_name, person.first_name].compact.join(" "), person.name]
    best_match = 999999999
    best_name = nil
    firstchar_lookup = { }
    names.each do |name|
      name = name.norm
      first_chars = name.gsub(/^\s+/,"").gsub(/[^a-z0-9 ]/, "")[0..1].upcase
      last_chars = first_chars[0] + (first_chars[1].ord+1).chr
#      first_chars = title.gsub(/^(das|the|a|an) /,"").gsub(/^\s+/,"").gsub(/[^a-z0-9 ]/, "")[0].upcase
#      last_chars = (first_chars[0].ord+1).chr
      STDERR.puts("DEBUG: Name: #{name}: #{first_chars}-#{last_chars}") if debug
      reply = firstchar_lookup[first_chars]
      if !reply
        cmtitle = "Category:#{birth_year} births"
        reply = JSON.parse(wclient.request_page("",
                                                :action => "query", 
                                                :list => "categorymembers", 
                                                :cmnamespace => 0, 
                                                :cmlimit => 500, 
                                                :cmtype => "page", 
                                                :cmstartsortkey => first_chars,
                                                :cmendsortkey => last_chars,
                                                :cmtitle => cmtitle))
        firstchar_lookup[first_chars] = reply
      end
      pagelist = reply["query"]["categorymembers"].map { |x| x["title"] }
      pagelist.each do |page|
        page_norm = page.norm.gsub(/\([^\)]*\)/,"").gsub(/^\s+/,"").gsub(/\s+$/,"").gsub(/[^a-z0-9 ]/,"")
        names.each do |name_inner|
          name_inner = name_inner.norm
#          STDERR.puts("DEBUG: Comparing: #{page_norm} with #{name_inner}") if debug
          distance = Levenshtein.distance(page_norm, name_inner)
          if distance < best_match
            STDERR.puts("DEBUG: Comparing: #{page_norm} with #{name_inner}") if debug
            STDERR.puts("DEBUG: Found new best match: #{distance}") if debug
            best_match = distance
            best_name = page
            return page if distance == 0
          end
        end
      end
    end
    return best_name if best_name && best_match < 6
    return nil
  end
  
  def self.find_page(object, debug = false, query_indexpoint = nil)
    query_list = []
    if query_indexpoint && query_indexpoint[:query]
      if query_indexpoint[:query] != -1
        query_list = object.wikipedia_query_list
        raise NoMoreDataException if query_indexpoint[:query] >= query_list.size
        query_list = [query_list[query_indexpoint[:query]]]
      end
    else
      query_list = object.wikipedia_query_list
    end
  
    RCache.set(object.cache_prefix+"wikipedia:last_check", Time.now.to_i, nil)
    wclient = Wikipedia::Client.new

    first_query_list = []
    if object.class == Movie
      year_best_match = year_movie_lookup(wclient, object)
      first_query_list = [year_best_match] if year_best_match
    elsif object.class == Person
      year_best_match = year_person_lookup(wclient, object)
      first_query_list = [year_best_match] if year_best_match
    end
    
    opensearch_list = []
    if query_indexpoint && query_indexpoint[:opensearch]
      if query_indexpoint[:opensearch] != -1
        opensearch_list = object.wikipedia_opensearch_list
        raise NoMoreDataException if query_indexpoint[:opensearch] >= opensearch_list.size
        opensearch_list = [opensearch_list[query_indexpoint[:opensearch]]]
      end
    else
      opensearch_list = object.wikipedia_opensearch_list
    end
    
    opensearch_list.each do |osrch|
      result = JSON.parse(wclient.request_page("", :action => "opensearch", 
                                               :format => "json", :search => osrch))
      next if result[1].blank?
      next if result[1].size > 1
      next if result[1].first.downcase.index("video game") && !object.is_game?
      next if result[1].first.downcase.index("videogame") && !object.is_game?
      next if result[1].first.downcase.index("game") && !object.is_game?
      first_query_list << result[1].first
    end
    query_list = first_query_list + query_list.sort_by { |x| rand(73642) }
    
    probed = []
    match_quality = []
    query_list.each_with_index do |item, i|
      STDERR.puts("DEBUG: Fetching: #{item.inspect}") if debug
      wiki = Wikipedia.find(item, :pllimit => 500, :plnamespace => 0)
      if wiki.nil?
        STDERR.puts("DEBUG: No page found. Skipping...") if debug
        next
      end
      if wiki.links.blank?
        STDERR.puts("DEBUG: No links to use...") if debug
        next
      end
      if !find_image_in_page(object, wiki)
        STDERR.puts("DEBUG: Skipping due to missing image.") if debug
        next
      end
      if probed.include?(wiki.title)
        STDERR.puts("DEBUG: Title already checked...") if debug
        next
      end
      probed << wiki.title
      image_url, percentage = scan_for_match(object, wiki, i == 0, debug)
      match_quality << [image_url, percentage, wiki] if image_url
      if percentage && percentage > 12.5
        break
      end
    end

    best_match = match_quality.sort_by { |x| -x[1] }.first
    return false if !best_match
    image_url = best_match[0]
    wiki = best_match[2]
    
    if image_url
      plot = find_plot_in_page(object, wiki)
      RCache.set(object.cache_prefix+"wikipedia:page", wiki.title, nil)
      if object.class == Movie
        RCache.del(object.cache_prefix+"display_title")
      end
      RCache.set(object.cache_prefix+"wikipedia:image", image_url, nil)
      RCache.set(object.cache_prefix+"wikipedia:expire", (Time.now()+WIKIPEDIA_EXPIRE).to_i, nil)
      if plot
        RCache.set(object.cache_prefix+"wikipedia:plot", plot, nil)
      end
      return true
    end

    return false
  end

  def self.scan_for_match(object, wiki, first, debug = false)
    config = Rails.configuration.database_configuration[RAILS_ENV]
    sph = Riddle::Client.new(config["host"], 9312)
    sph.match_mode = :extended2
    sph.max_matches = 10000
    sph.limit = 1
    sph.sort_mode = :expr
    sph.sort_by = "@id == #{object.id}"
    match_count = 0
    total_links = wiki.links.size
    percentage = 0

    wiki.links.each do |link|
      res = sph.query("\"#{link}\"", object.query_source(true))
      if res[:matches].size == 0 || res[:matches][0][:doc] != object.id
        res = sph.query("\"#{link}\"", object.query_source)
      end
      if res[:matches].size > 0 && res[:matches][0][:doc] == object.id
        match_count += 1
        percentage = 100*(match_count.to_f/total_links)
        STDERR.puts("DEBUG: cnt: #{match_count}: #{wiki.title}: #{percentage}") if debug
        if first && percentage > 1.0
          image_url = find_image_in_page(object, wiki)
          return image_url, 12.6 if image_url
          return nil
        end
      end
    end
    return [find_image_in_page(object, wiki), percentage] if percentage > 1.0
    return nil
  end
  
  def self.find_image_in_page(object, wiki)
    content = wiki.content
    infobox = content.scan(/\{\{(Infobox|Adult).*?(img|image)\s*=\s*([^\|><\n]*)[\|<\n].*\}\}/im)[0]
    return nil if infobox.nil? || infobox.empty?
    imagename = nil
    partial = infobox[2].scan(/^\[\[(File|image):([^\|\]]+)[\|\]]?.*$/i)[0]
    if partial.nil? || partial.empty?
      imagename = infobox[2]
    else
      imagename = partial[1]
    end
    image = Wikipedia.find_image("File:#{imagename}", :iiurlwidth => 640)
    image_url = image.image_url
    if image_url.nil?
      check_redir = Wikipedia.find("File:#{imagename}")
      return nil if check_redir.nil?
      if check_redir.title != "File:#{imagename}"
        image = Wikipedia.find_image(check_redir.title, :iiurlwidth => 640)
        return nil if image.nil?
      end
    end
    image_url = image.image_url
    if image.page && image.page["imageinfo"] && image.page["imageinfo"][0] && image.page["imageinfo"][0]["thumburl"]
      image_url = image.page["imageinfo"][0]["thumburl"]
    end
    return image_url
  end
  
  def self.find_plot_in_page(object, wiki)
    return nil if object.class != Movie

    content = wiki.sanitized_content
    return false if !content.match(/==\s*Plot\s*==/)
    plotdata = content.gsub(/.*(==\s*Plot\s*==)/m, '<p>').gsub(/<p>==\s*[^=]+\s*==.*/m,"")
    # Replace headers
    plotdata = plotdata.gsub(/==(=+)\s*([^=]+?)\s*==(=+)/m) do |match|
      "<h#{$1.length+3}>#{$2}</h#{$1.length+3}>"
    end
    plotdata = plotdata.gsub(/^(|<p>); ([^:]+): (.*)/) do |match|
      "<dl><dt>#{$2}</dt><dd>#{$3}</dd></dl>"
    end
    plotdata = plotdata.gsub(/<\/dl>\s*<dl>/m, "")
    return plotdata
  end
end
