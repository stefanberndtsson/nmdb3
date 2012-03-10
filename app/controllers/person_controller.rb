class PersonController < ApplicationController
  layout "nmdb"
  before_filter :setup_or_redirect
  
  def index
    respond_to do |format|
      format.html
      format.xml { render :xml => @person.to_complete_xml }
      format.json { render :xml => @person.to_complete_json }
    end
  end

  def movies_by_genre
    @grouped = @person.movies_by_genre
  end
  
  def movies_by_keyword
    @grouped = @person.movies_by_keyword
  end
  
  def biography
    @aka_names = @person.aka_names
    fetch_biography_data
  end
  
  def trivia
    fetch_biography_data
    render :action => 'biography'
  end

  def quotes
    fetch_biography_data
    render :action => 'biography'
  end
  
  def publicity
    fetch_biography_data
    render :action => 'biography'
  end
  
  def other_works
    fetch_biography_data
    render :action => 'biography'
  end

  def external_links
    if WikipediaFetcher.page(@person)
      @wikipedia_page = WikipediaFetcher.page(@person)
    else
      @wikipedia_page = @person.name
    end
  end

  def image
#    @image_url = WikipediaFetcher.image(@person, true)
#    render :partial => 'image'
    profile_url = @person.tmdb_main_profile(view_context.current_user)
    profile_url = WikipediaFetcher.image(@person, true) if !profile_url
    
    menuitem = I18n.t("menu.images")
    selectable = false
    if @person.has_images?(view_context.current_user, false)
      menuitem = view_context.link_to_page(I18n.t("menu.images"), :person, :images, @person.id)
      selectable = true
    end
    
    render :json => {
      :image => view_context.image_tag(profile_url),
      :menuitem => menuitem,
      :selectable => selectable
    }
  end
  
  def images
    @images = @person.tmdb_images(view_context.current_user)
    @images.delete("id")
  end
  
  def reset_externals
    rc = RCache.keys("person:#{@person.id}:*")
    rc.each do |rc_key|
      RCache.del(rc_key)
    end
    
    redirect_to params[:bounceback]
  end
  
  private
  def fetch_biography_data
    @md_keys = PersonMetadatum.pages[params[:action]][:keys]
    @metadata = @person.person_metadata.find_all_by_key(@md_keys).group_by { |x| x.key }
  end
  
  def setup_or_redirect
    if !params[:id]
      redirect_to :controller => 'search', :action => 'index'
      return
    end
    @person = Person.find(params[:id])
    @timer = { :start => Time.now }
  end
end
