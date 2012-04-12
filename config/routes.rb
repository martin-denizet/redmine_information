ActionController::Routing::Routes.draw do |map|
  map.connect 'info/:action', :controller => 'info'
end