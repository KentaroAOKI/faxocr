ActionController::Routing::Routes.draw do |map|

  map.resources :role_mappings

  map.resources :groups, :member => { :report => :get } do |group|
    group.resources :surveys do |survey|
      survey.resources :sheets do |sheet|
        sheet.resources :sheet_properties
      end
      survey.resources :survey_properties
      survey.resources :survey_candidates
      survey.resources :answer_sheets, :member => { :image => :get, :edit_recognize => :get, :update_recognize => :put } do |answer_sheet|
        answer_sheet.resources :answer_sheet_properties, :member => { :image => :get }
      end
      survey.connect "report/:year/:month/:day",
        :controller => "report",
        :action => "daily",
        :requirements => {:year => /(19|20)\d\d/,
                          :month => /[01]?\d/,
                          :day => /[0-3]\d/},
        :day => nil,
        :month => nil
      survey.connect "export/:year/:month/:day",
        :controller => "export",
        :action => "csv",
        :requirements => {:year => /(19|20)\d\d/,
                          :month => /[01]?\d/,
                          :day => /[0-3]\d/},
        :day => nil,
        :month => nil
    end
    group.resources :candidates
    group.resources :users, :member => {:edit_self => :get, :update_self => :post}
  end

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # PHP driver
  map.connect 'external/register/:group_id',
    :controller => 'external',
    :action => 'register'

  # PHP driver
  map.connect 'external/form/:group_id/:survey_id',
    :controller => 'external',
    :action => 'form'

  # PHP driver
  map.connect 'external/:action',
    :controller => 'external'

  map.connect 'faxocr/direct_masquerade/:group_id/:id',
    :controller => 'faxocr',
    :action => 'direct_masquerade'

  map.connect 'faxocr/:action',
    :controller => 'faxocr'

  map.connect "inbox/",
    :controller => "inbox",
    :action => "index"

  map.connect "inbox/:group_id",
    :controller =>"inbox",
    :action => "group_surveys"

  map.connect "inbox/:group_id/:survey_id/",
    :controller => "inbox",
    :action => "survey_answer_sheets"

  map.connect "inbox/:group_id/:survey_id/:answer_sheet_id/",
    :controller => "inbox",
    :action => "answer_sheet_properties"

  map.connect "inbox/:group_id/:survey_id/:answer_sheet_id/update",
    :controller => "inbox",
    :action => "update_answer_sheet_properties"

  map.connect "report/:survey_id/daily/:year/:month/:day",
    :controller => "report",
    :action => "daily",
    :requirements => {:year => /(19|20)\d\d/,
                      :month => /[01]?\d/,
                      :day => /[0-3]\d/},
    :day => nil,
    :month => nil

  map.connect "util/survey/:survey_code/fax_numbers",
    :controller => "util",
    :action => "survey_fax_numbers"

  map.connect "util/sheet/:survey_code/srml",
    :controller => "util",
    :action => "srml"

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  #map.connect ':controller/:action/:id'
  #map.connect ':controller/:action/:id.:format'
end
