module Wikitopdf

  class ViewHook < Redmine::Hook::ViewListener

    def view_layouts_base_body_bottom(context= { })
      # Redmine 4 is not supported because it is hard
      # to inject partial inside a wiki editor form
      return '' if Redmine::VERSION::MAJOR >= 4

      controller = context[:controller]
      action = controller.action_name

      hook_res = ''
      if controller.is_a?(WikiController)
        context[:page] = controller.instance_variable_get("@page")
        return '' unless context[:page]
        if action == 'edit'
          hook_res = view_wiki_form_bottom(context)
          scripts = ''
          hook_res.scan(/<script.*<\/script>/m) { |m| scripts += m}
          hook_res.gsub!(/<script.*<\/script>/m, ' ')
          hook_res.gsub!(/\n/, " \\\n")
          hook_res = javascript_tag "$('#attachments_fields').parent().after('#{hook_res}')"
          hook_res += scripts.html_safe
        end
      end

      return hook_res
    end

    def view_wiki_form_bottom(context= { })
      context[:controller].send(:render_to_string, {
        :partial => "wikitopdf_toc_page/edit",
        :locals => {:page => context[:page] }
      })
    end

  end

  # Hook controller to save TocPage in wikipage
  class ControllerHook < Redmine::Hook::Listener

    def controller_wiki_edit_after_save context
      attrs = context[:params][:wikitopdf_toc_page]
      if attrs
        if context[:page].wikitopdf_toc_page
          context[:page].wikitopdf_toc_page.update_attributes attrs
        else
          context[:page].wikitopdf_toc_page = WikitopdfTocPage.create(attrs)
        end
      end
    end
  end

  # Module for patching wiki model
  module WikiPagePatch

    def self.included(base)
      base.class_eval do
        unloadable
        has_one :wikitopdf_toc_page
        accepts_nested_attributes_for :wikitopdf_toc_page
      end
    end
  end

end
