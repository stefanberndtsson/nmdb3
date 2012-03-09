module MovieHelper
  def movie_menulist(movie)
    list = []
    list << { :action => :index, :title => "summary", :linked => true }
    list << { :action => :episodes, :linked => !movie.episodes.empty? }
    list << { :action => :additional_details, :linked => movie.has_additional? }
    list << { :action => :trivia, :linked => !movie.trivia.empty? }
    list << { :action => :goofs, :linked => !movie.goofs.empty? }
    list << { :action => :plot, :linked => movie.has_plot? }
    list << { :action => :keywords, :linked => !movie.keywords.empty? }
    list << { :action => :movie_connections, :linked => !movie.movie_connections.empty? }
    list << { :action => :crazy_credits, :linked => !movie.crazy_credits.empty? }
    list << { :action => :soundtrack, :linked => !movie.soundtrack_titles.empty? }
    list << { :action => :alternate_versions, :linked => !movie.alternate_versions.empty? }
    list << { :action => :technicals, :linked => !movie.technicals.empty? }
    list << { :action => :taglines, :linked => !movie.taglines.empty? }
    list << { :action => :quotes, :linked => !movie.quotes.empty? }
    list << { :action => :similar, :linked => movie.has_similar? }
    list << { :action => :images, :linked => movie.has_images?(current_user) }
    list << { :action => :download, :linked => true }
    list << { :action => :external_links, :linked => true }
    list
  end
  
  def movie_menu
    content_tag :ul, :id => "menu" do
      movie_menulist(@movie).map do |menuitem|
        item_class = (menuitem[:action].to_s == params[:action]) ? "selected" : "unselected"
        item_class = "unlinked" if !menuitem[:linked]
        content_tag :li, :class => item_class do
          link_text = I18n.t("menu."+(menuitem[:title] || menuitem[:action].to_s))
          menuitem[:linked] ? link_to_page(link_text, :movie, menuitem[:action], @movie.id) : link_text
        end
      end.join("\n").html_safe
    end
  end

  def display_original_title(movie, force_title = false)
    return if movie.real_title?(0) && !force_title
    render :partial => 'common/summary_table', :locals => { 
      :heading => 'Original title', 
      :rows => [movie.full_title]
    }
  end
  
  def display_aka_titles(movie)
    return if movie.movie_akas.blank?
    aka_table = movie.movie_akas.map do |maka|
      ([maka.title, maka.info]-[nil]).join(" ")
    end
    render :partial => 'common/summary_table', :locals => { :heading => "Also known as", :rows => aka_table }
  end

  def display_color_infos(movie)
    return if movie.color_infos.blank?
    ci_table = movie.color_infos.map do |ci|
      ([ci.color, ci.info]-[nil]).join(" ")
    end
    render :partial => 'common/summary_table', :locals => { :heading => "Color", :rows => ci_table }
  end

  def display_running_times(movie)
    return if movie.running_times.blank?
    rt_table = movie.running_times.map do |rt|
      prefix = rt.location ? "#{rt.location}:" : ""
      suffix = rt.info ? " #{rt.info}" : ""
      "#{prefix}#{rt.running_time} min#{suffix}"
    end.sort
    render :partial => 'common/summary_table', :locals => { :heading => "Running time", :rows => rt_table }
  end
  
  def display_languages(movie)
    return if movie.languages.blank?
    languages = movie.languages.map(&:language)
    render :partial => 'common/summary_table', :locals => { :heading => "Languages", :rows => languages }
  end

  def display_aspect_ratio(movie)
    return if movie.technicals.blank?
    return if movie.technicals.find_by_key("RAT").blank?
    string = movie.technicals.find_by_key("RAT").value
    render :partial => 'common/summary_table', :locals => { :heading => "Aspect ratio", :rows => [string] }
  end

  def display_rating(movie)
    return if !movie.rating
    string = sprintf("%03.1f/10 (%d votes)", movie.rating.rating, movie.rating.votes)
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => "Rating", :rows => [string] }
  end

  def display_genre(movie)
    string = movie.genres.uniq.map(&:genre).join(" / ")
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Genre', :rows => [string] }
  end
  
  def display_keyword(movie, max_count = 10)
    strong = movie.strong_keywords.sort_by { |x| x.keyword.gsub(/-/, "")[2..2] }
    normal = (movie.keywords - strong).sort_by { |x| x.keyword.gsub(/-/, "")[2..2] }
    output = strong[0..max_count].sort_by { |x| x.display }
    if output.size < max_count
      output += normal[0..(max_count-output.size-1)].sort_by { |x| x.display }
    end
    tmp = output[0..max_count-1]
    if (strong + normal).size > max_count
      tmp += [link_to_page("(More)", :movie, :keywords, movie.id)]
    end
    string = tmp.map { |x| display_single_keyword(x, true) }.join(" ").html_safe
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Keyword', :rows => [string] }
  end
  
  def display_release_date(movie)
    string = movie.first_release_date.display
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Release date', :rows => [string] }
  end

  def display_tagline(movie)
    string = movie.taglines.first
    return if string.blank?
    string = string.tagline
    if movie.taglines.size > 1
      string += " "+link_to_page("(More)", :movie, :taglines, movie.id)
    end
    render :partial => 'common/summary_table', :locals => { :heading => 'Tagline', :rows => [string.html_safe] }
  end
  
  def display_quote_data(data, movie = nil)
    data = data.gsub(/\[(.*)\]/, "[<span class=\"quote_comment\">\\1</span>]")
    quoter = data.gsub(/^([^:]+):.*$/, '\1') if data.index(":")
    if quoter
      if movie
        quoter_data = find_quoter(quoter, movie)
        if quoter_data
          quoter = "<a href=\"#{url_for(:controller => :person, :action => :index, :id => quoter_data[1].person_id)}\">#{quoter}</a>"
        end
      end
      data = data.gsub(/^([^:]+:)/, "<span class=\"quote_quoter\">#{quoter}:</span>") if data.index(":")
    end
    data.html_safe
  end
  
  def find_quoter(quoter, movie)
    @find_quoter_cache ||= { }
    return @find_quoter_cache[[movie.id, quoter]] if @find_quoter_cache[[movie.id, quoter]]
    qnorm = quoter.norm
    charlist = movie.cast.map do |member|
      next if member.character.blank? || member.character.norm.blank? || qnorm.blank?
      [Levenshtein.distance(member.character.norm, qnorm), member]
    end.compact.sort_by do |member|
      member[0]
    end

    return nil if charlist.blank?

    tmp = charlist.first
    tmp[0] = tmp[0].to_f/[quoter.size, tmp[1].character.size].max.to_f

    if tmp[0] > 0.25
      new_tmp = charlist.select do |member|
        member[1].character.index(quoter)
      end

      if !new_tmp.blank? && new_tmp.size != 1
        new_tmp = new_tmp.select do |member|
          member[1].character[/#{quoter}( |$)/]
        end
      end

      if new_tmp.blank? || new_tmp.size != 1
        quoter_parts = quoter.split(" ")
        new_tmp = charlist.select do |member|
          quoter_parts_count = 0
          quoter_parts.each do |qpart|
            quoter_parts_count += 1 if member[1].character.index(qpart)
          end
          quoter_parts_count == quoter_parts.size
        end
      end
      return nil if new_tmp.blank? || new_tmp.size != 1
      tmp = new_tmp.first
    end
    @find_quoter_cache[[movie.id, quoter]] = tmp
  end
  
  def display_crew(heading, movie, role_name, compact = false)
    crew_list = movie.crew_as_role(role_name).map { |x| [0, x] }
    total_crew_count = crew_list.size
    
    if compact
      high_prio_list = {
        "producer" => ["(producer)"],
        "writer" => ["(novel", "(written by)", "(story", "(play"],
        "director" => []
      }
      high_prio = high_prio_list[role_name]
      high_prio_count = 0

      sorted_list = movie.crew_as_role(role_name).map do |crew_member|
        priority = 0
        high_prio.each do |high_prio_item|
          if crew_member.extras && crew_member.extras.index(high_prio_item)
            priority = 1
            high_prio_count += 1
          end
        end
        [priority, crew_member]
      end.sort_by { |x| -x[0] }

      if high_prio_count == 0
        crew_list = sorted_list[0..1]
      else
        crew_list = sorted_list[0..[high_prio_count-1,1].min]
      end
    end
    
    return if crew_list.blank?

    crew_list = crew_list.map do |crew_member|
      [link_to_person(crew_member[1].person), crew_member[1].extras].join(" ").html_safe
    end
    
    if crew_list.size < total_crew_count
      crew_list += [link_to_page("(More)", :movie, :additional_details, movie.id)]
    end

    render :partial => 'common/summary_table', :locals => { :heading => heading, :rows => crew_list }
  end
  
  def header_offset
    return "" if !current_user
    buttons = current_user.button_count
    "margin-left: #{buttons*1.5}em; padding-left: #{buttons*2}px;"
  end
end
