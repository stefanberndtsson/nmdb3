module SearchHelper
  def facet_presentation(key, id, reverse = false)
    if key == "category"
      return Movie.category_description(id)
    elsif key == "genre"
      return id.genre if !reverse
      return Genre.find_by_id(id).genre if reverse
    elsif key == "keyword"
      return id.display if !reverse
      return Keyword.find_by_id(id).display if reverse
    elsif key == "language"
      return id.language if !reverse
      return Language.find_by_id(id).language if reverse
    elsif key == "episode"
      ["non-episodes", "episodes"][id]
    else
      return id
    end
  end
  
  def facet_attribute(key)
    if key == "category"
      return "category"
    elsif key == "episode"
      return "is_episode"
    elsif key == "genre"
      return "genre_ids"
    elsif key == "keyword"
      return "keyword_ids"
    elsif key == "language"
      return "language_ids"
    elsif key == "year"
      return "year_attr"
    elsif key == "rating"
      return "rating"
    elsif key == "decade"
      return "decade_attr"
    else
      return id
    end
  end
  
  def facet_values(key, id)
    if key == "category"
      return [id]
    elsif key == "genre"
      return [id.id]
    elsif key == "keyword"
      return [id.id]
    elsif key == "language"
      return [id.id]
    else
      return [id]
    end
  end

  def facet_name(key)
    if key == "is_episode"
      return "episode"
    elsif key == "genre_ids"
      return "genre"
    elsif key == "keyword_ids"
      return "keyword"
    elsif key == "language_ids"
      return "language"
    elsif key == "year_attr"
      return "year"
    elsif key == "decade_attr"
      return "decade"
    else
      return key
    end
  end
  
  def active_filter(filter)
    filter_name = facet_name(filter[:attribute])
    filter_text_value = facet_presentation(filter_name, filter[:values][0].to_i, true)
    if filter_name == "rating"
      filter_text_value = filter[:values][0].scan(/^([\d\.]+)\.\.([\d\.]+)$/)[0].map { |x| sprintf("%3.1f", x.to_i/10.0) }.join(" .. ")
    elsif filter[:values][0][/^[\d\.]+\.\.[\d\.]+$/]
      filter_text_value = filter[:values][0]
    end
    direction = "Include"
    direction = "Exclude" if filter[:exclude] == "true"
    return "#{direction} #{filter_name}: #{filter_text_value}"
  end
  
  def ca_count(total, partial)
    ca = (total*partial)/10000.0
    if ca > 15000
      return (5000*((ca/5000).to_i))
    elsif ca > 5000
      return (1000*((ca/1000).to_i))
    elsif ca > 1500
      return (500*((ca/500).to_i))
    elsif ca > 500
      return (100*((ca/100).to_i))
    else
      return (10*((ca/10).to_i))
    end
  end
end
