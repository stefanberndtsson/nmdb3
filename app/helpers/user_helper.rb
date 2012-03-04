module UserHelper
  def user_menulist
    user = current_user || User.new
    list = []
    if !["login", "register"].include?(params[:action])
      list << { :action => :profile, :title => "profile", :linked => true }
      list << { :action => :prefs, :title => "preferences", :linked => true }
      list << { :action => :wishlist, :title => "wishlist", :linked => user.has_toggle?("wish") }
      list << { :action => :seen, :title => "seen", :linked => user.has_toggle?("wish") }
      list << { :action => :owns, :title => "owns", :linked => user.has_toggle?("owns") }
      list << { :action => :unseen_owns, :title => "unseen_owns", :linked => user.has_unseen_owns? }
      list << { :action => :unwishlist, :title => "unwishlist", :linked => user.has_toggle?("unwish") }
      list << { :action => :error, :title => "error", :linked => user.has_toggle?("error") }
      list << { :action => :logout, :title => "logout", :linked => !!current_user }
    end
    list << { :action => :just_bounce, :title => "back", :linked => true}
    list
  end
  
  def user_menu
    content_tag :ul, :id => "menu" do
      user_menulist.map do |menuitem|
        item_class = (menuitem[:action].to_s == params[:action]) ? "selected" : "unselected"
        item_class = "unlinked" if !menuitem[:linked]
        content_tag :li, :class => item_class do
          link_text = I18n.t("menu."+(menuitem[:title] || menuitem[:action].to_s))
          menuitem[:linked] ? link_to_page(link_text, :user, menuitem[:action], nil, { :bounceback => params[:bounceback]}) : link_text
        end
      end.join("\n").html_safe
    end
  end
  
  def display_date(date)
    (date + 2.hours).strftime("%Y-%m-%d %H:%M")
  end
  
  def sortable(column, title = nil)  
    title ||= column.titleize  
    direction = (column == params[:sort] && params[:direction] == "asc") ? "desc" : "asc"  
    link_to title, :sort => column, :direction => direction  
  end  
end
