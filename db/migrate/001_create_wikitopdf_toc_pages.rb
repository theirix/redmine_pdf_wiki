class CreateWikitopdfTocPages < (Rails.version < '5.1') ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    create_table :wikitopdf_toc_pages do |t|
      t.boolean :istoc
      t.belongs_to :wiki_page
    end
  end
end
