#PDF plugin for REDMINE
require 'redmine'

Redmine::Plugin.register :redmine_pdf_wiki do
  name 'WikiToPdf plugin'
  author 'Arnaud Martel'
  description 'Export wiki pages to PDF file'
  version '0.0.10'

  # due to Dispatcher changes
  requires_redmine :version_or_higher => '2.0.0'

  settings :default => {'wtp_command' => "/usr/local/bin/wkhtmltopdf --print-media-type --no-outline  --disable-external-links --disable-internal-links -n --load-error-handling ignore --user-style-sheet #{File.join(File.dirname(__FILE__), 'pdf.css')}", 'wtp_keeptmp' => false }, :partial => 'settings/wtp_settings'
end

require 'wikitopdf'
require 'wiki_page_patch'

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'redmine/export/pdf'
  require_dependency 'wiki_helper'
  require_dependency 'wiki_page'

  if Redmine::VERSION::MAJOR >= 3
    # redmine 3
    unless WikiHelper.included_modules.include? Wikitopdf::PDFPatch
      WikiHelper.send(:include, Wikitopdf::PDFPatch)
    end
  else
    # redmine 2
    unless WikiController.included_modules.include? Wikitopdf::PDFPatch
      WikiController.send(:include, Wikitopdf::PDFPatch)
    end
  end
  unless WikiPage.included_modules.include? Wikitopdf::WikiPagePatch
    WikiPage.send(:include, Wikitopdf::WikiPagePatch)
  end
end
