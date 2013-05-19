class CreateWikitopdfTocPages < ActiveRecord::Migration
  def change
    create_table :wikitopdf_toc_pages do |t|
      t.boolean :istoc
      t.belongs_to :wiki_page
    end
  end
end
