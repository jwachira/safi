class PagesController < ApplicationController
  
 def show
  page_id = String(params[:id]).numeric_id
  @page = Page.find(page_id)
 end
 
 def contact_us
   @page = Page.contact_us
 end
 
 def about_us
   @page  = Page.about_us
 end
 
end
