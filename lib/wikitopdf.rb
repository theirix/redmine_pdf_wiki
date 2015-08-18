module Wikitopdf

  # PDF export via wkhtmltopdf
  class PdfExport
    include Redmine::I18n

    def initialize(page, project, controller)
      @page = page
      @project = project
      @request = controller.request
      @controller = controller
      @wiki = @project.wiki
      @tmpdir = Rails.root.join('tmp', 'pdf')
      @hostname = (URI(Setting.host_name).host or Setting.host_name)
      FileUtils.mkdir_p(@tmpdir) unless File.directory?(@tmpdir)
      raise 'No wiki page found' unless @wiki
    end

    def export
      to_pdf
    end

  private

    def url_by_page page
      '"' + @controller.url_for(:controller => 'wiki', :action => 'show',
        :project_id => page.project, :id => page.title,
        :host => @hostname) + '"'
    end

    def pdf_page_hierarchy(node)
      pages = @wiki.pages.joins(:content).order(:title).select('wiki_pages.*, wiki_contents.updated_on')
      Rails.logger.debug("pages #{pages.size}")
      pages_by_parent_id = pages.group_by(&:parent_id)
      pages = pdf_page_hierarchy_impl(pages_by_parent_id, node)
      Rails.logger.debug("pages list: #{pages.join(', ')}")
      pages
    end

    def pdf_page_hierarchy_impl(pages, node)
      content=[]
      if pages[node]
        pages[node].each do |page|
          title = page.title.downcase
          if title != "sidebar" && title != "stylesheet"
            content << url_by_page(page)
            content += pdf_page_hierarchy_impl(pages, page.id) if pages[page.id]
          end
        end
      end
      content
    end

    def wiki_page_by_pretty_title wiki, pretty_title
      effective_title = pretty_title.split('|').first
      wp = wiki.find_page(effective_title)
      raise "No such page #{effective_title} (full title #{pretty_title})" unless wp
      wp
    end

    # Extract page links from TOC wikipage
    def pages_from_toc page
      page.content.text.split("\r\n").
        reject { |s| s.empty? || s.index("[[") == nil }.
        map { |s| s.gsub(/.*\[\[(.*)\]\].*/, '\1') }.
        map { |s| wiki_page_by_pretty_title(page.wiki,s) }.
        map { |wp| url_by_page(wp) }
    end

    # Return ordered list of wiki page URLs
    # which is passed to converter
    def extract_pages_list
      if @page
        if @page.wikitopdf_toc_page && @page.wikitopdf_toc_page.istoc
          [ url_by_page(@page) ] + pages_from_toc(@page)
        else
          [ url_by_page(@page) ] + pdf_page_hierarchy(@page.id)
        end
      else
        pdf_page_hierarchy(nil)
      end
    end

    def to_pdf
      t = Time.now.strftime("%d")

      pdfname = "#{@tmpdir}/#{t}#{rand(0x100000000).to_s(36)}.pdf"
      #args = Setting.plugin_redmine_pdf_wiki['wtp_command'].split(' ')
      #args << '--quiet'

      pages_list = extract_pages_list

      args = [ '--quiet' ]

      flg=false
      if @request.headers['Cookie']
        flg=true
        value = @request.headers['Cookie']
        args << '--custom-header'
        args << 'Cookie'
        args << '"' + value +'"'
      end
      if @request.headers['Authorization']
        flg=true
        value = @request.headers['Authorization']
        args << '--custom-header'
        args << 'Authorization'
        args << '"' + value +'"'
      end
      args << '--custom-header-propagation' if flg
      args += pages_list
      args << pdfname

      Rails.logger.debug("Exporting #{pages_list.size} wikipages: " + pages_list.join(' ')) if Rails.logger && Rails.logger.debug?

      cmdname = "#{@tmpdir}/#{t}#{rand(0x100000000).to_s(36)}.txt"
      File.open(cmdname, "w") do |f|
        f.write(args.join(' '))
      end

      command = "#{Setting.plugin_redmine_pdf_wiki['wtp_command']} --read-args-from-stdin < #{cmdname}"
      Rails.logger.info("Executing " + command) if Rails.logger && Rails.logger.info?
      `#{command}`

      # Actually we need to return 500 page but it is a helper method so we generate only PDF bytes
      raise "Command '#{command}' failed with code #{$?}" if $? != 0

      IO.read(pdfname)
    rescue => e
      Rails.logger.error(e.to_s) if Rails.logger
      text_to_pdf e.to_s
    ensure
      unless (Setting.plugin_redmine_pdf_wiki['wtp_keeptmp'] || 0)
        safe_unlink cmdname
        safe_unlink pdfname
      end
    end


    def text_to_pdf content
      pdf = Redmine::Export::PDF::ITCPDF.new(current_language, "L")
      title = "WikiToPDF error"
      pdf.set_title(title)
      pdf.alias_nb_pages
      pdf.footer_date = format_date(Date.today)
      pdf.set_auto_page_break(false)
      pdf.add_page("L")

      # Landscape A4 = 210 x 297 mm
      page_height   = pdf.get_page_height # 210
      page_width    = pdf.get_page_width  # 297
      left_margin   = pdf.get_original_margins['left'] # 10
      right_margin  = pdf.get_original_margins['right'] # 10
      bottom_margin = pdf.get_footer_margin

      # title
      pdf.SetFontStyle('B',11)
      pdf.RDMCell(190,10, title)
      pdf.ln

      # body
      pdf.SetFontStyle('',11)
      pdf.write(h=0, content, link='', fill=0, align='L', ln=true, stretch=0, firstline=false, firstblock=false, maxh=0)

      pdf.output
    end


    # unlink that never throws
    def safe_unlink filename
      return unless filename
      begin
        File.unlink filename
      rescue => e
        Rails.logger.warn("Cannot unlink temp file " + filename) if Rails.logger && Rails.logger.warn?
      end
    end

  end

  # Module for patching native PDF engine
  module PDFPatch

    def self.included(base)
      base.class_eval do
        unloadable
      end
      base.send(:include, ModuleMethods)
    end

    module ModuleMethods
      # Patched WikiController method, returns PDF body
      def wiki_page_to_pdf(page, project)
        Rails.logger.debug("Invoked patched wiki_page_to_pdf") if Rails.logger && Rails.logger.debug?
        pdf_export = Wikitopdf::PdfExport.new(page, project, self)
        pdf_export.export
      end
      def wiki_pages_to_pdf(pages, project)
        Rails.logger.debug("Invoked patched wiki_pages_to_pdf") if Rails.logger && Rails.logger.debug?
        pdf_export = Wikitopdf::PdfExport.new(nil, project, self)
        pdf_export.export
      end
    end
  end


end
