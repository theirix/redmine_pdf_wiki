class WikitopdfTocPage < ActiveRecord::Base
  unloadable
  belongs_to :wiki_page
  attr_accessible :istoc
end
