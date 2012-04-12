# 
# info_category.rb
# 

class InfoCategory

  @@captions = {}
  
  def self.categories
    [:permissions, :workflows, :settings, :plugins, :wiki_macros, :rails_info, :version]
  end

  def self.hide_map
    map = {}
    InfoCategory.categories.each {|catsym|
      map['hide_' + catsym.to_s] = (catsym.to_s == "rails_info") ? true : false
    }
    map
  end

  def self.label(catname)
    I18n.t(@@captions[catname.to_sym])
  end

  
  def self.push_menu(menu, catsym, caption = nil, opts = {})
    url = {:controller => :info, :action => :show}
    copts = opts.clone

    url[:id] = catsym
    copts[:if] = Proc.new { (InfoCategory::is_shown?(catsym) or User.current.admin?) }

    if (caption)
      copts[:caption] = caption
    else
      caption = ("label_" + catsym.to_s).to_sym
    end
    @@captions[catsym] = caption

    menu.push(catsym, url, copts)
  end
    
  
  def self.is_shown?(catsym)
    hidekey = 'hide_' + catsym.to_s
    return !Setting.plugin_redmine_information[hidekey]
  end

  
end
