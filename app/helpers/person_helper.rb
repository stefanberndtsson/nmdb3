module PersonHelper
  def person_menulist(person)
    list = []
    list << { :action => :index, :title => "summary", :linked => true }
    list << { :action => :movies_by_weight, :linked => true }
    list << { :action => :movies_by_genre, :linked => true }
    list << { :action => :movies_by_keyword, :linked => true }
    list << { :action => :biography, :linked => person.has_metadata_page?("biography") }
    list << { :action => :trivia, :linked => person.has_metadata_page?("trivia") }
    list << { :action => :quotes, :linked => person.has_metadata_page?("quotes") }
    list << { :action => :publicity, :linked => person.has_metadata_page?("publicity") }
    list << { :action => :other_works, :linked => person.has_metadata_page?("other_works") }
    list << { :action => :images, :linked => person.has_images?(current_user), :id => "ajax_images_menuitem" }
    list << { :action => :download, :linked => true }
    list << { :action => :external_links, :linked => true }
    list
  end
  
  def person_menu
    content_tag :ul, :id => "menu" do
      person_menulist(@person).map do |menuitem|
        item_class = (menuitem[:action].to_s == params[:action]) ? "selected" : "unselected"
        item_class = "unlinked" if !menuitem[:linked]
        content_tag :li, :class => item_class, :id => menuitem[:id] do
          link_text = I18n.t("menu."+(menuitem[:title] || menuitem[:action].to_s))
          menuitem[:linked] ? link_to_page(link_text, :person, menuitem[:action], @person.id) : link_text
        end
      end.join("\n").html_safe
    end
  end
  
  def display_date_of_birth(person)
    string = person.date_of_birth
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Date of Birth', :rows => [string] }
  end
  
  def display_date_of_death(person)
    string = person.date_of_death
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Date of Death', :rows => [string] }
  end
  
  def display_age(person)
    return if !person.age
    return if (person.age-[nil]).size != 2
    age = distance_of_time_in_words(*person.age)
    render :partial => 'common/summary_table', :locals => { :heading => 'Age', :rows => [age] }
  end
  
  def display_birth_name(person)
    string = person.birth_name
    return if string.blank?
    render :partial => 'common/summary_table', :locals => { :heading => 'Birth Name', :rows => [string] }
  end
  
  def display_movies(person, section_name = nil)
    movies = person.movies_as_section(section_name)
    return if movies.blank?
    
    render :partial => 'movies', :object => movies, :locals => { 
      :heading => I18n.t("role."+person.section_heading(section_name)) }
  end
end
