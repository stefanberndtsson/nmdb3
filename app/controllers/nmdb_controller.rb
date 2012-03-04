class NmdbController < ApplicationController
  def index
    redirect_to :controller => :search
  end

  def movie
    @page = params[:page]
    @page = "index" if !@page
    @page = "index" if @page == "summary"
    @page = "technicals" if @page == "technical"
    @page.gsub!(/ /,"_")
    redirect_to :controller => 'movie', :action => @page, :id => params[:id]
  end
  
  def person
    @page = params[:page]
    @page = "index" if !@page
    @page = "index" if @page == "summary"
    @page = "movies_by_weight" if @page == "weighted movies"
    @page = "movies_by_genre" if @page == "by genre"
    @page = "movies_by_keyword" if @page == "by keyword"
    @page = "quotes" if @page == "quote"
    @page.gsub!(/ /,"_")
    redirect_to :controller => 'person', :action => @page, :id => params[:id]
  end
end
