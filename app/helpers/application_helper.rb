module ApplicationHelper
  def nameify(user)
    return user.display_name unless !user.display_name || user.display_name.strip.empty?
    id, domain = user.email.split '@'
    id[0, [id.length/2, 1].max] << '...@' << domain[0, 1] << '...'
  end

  def user_class(user)
    case
      when user.admin? then
        content_tag(:span, '[A]', class: [:tag, :user, :admin])
      when user.moderator? then
        content_tag(:span, '[M]', class: [:tag, :user, :mod])
      else
        nil
    end
  end

  def markdown(txt)
    options  = {
        space_after_headers: true,
        fenced_code_blocks:  true,
        autolink:            true,
        superscript:         true,
        underline:           true,
        no_intra_emphasis:   true,
        tables:              true
    }
    renderer = Redcarpet::Render::HTML.new filter_html:     true,
                                           hard_wrap:       true,
                                           with_toc_data:   true,
                                           link_attributes: { rel: 'nofollow', target: '_blank' }
    markdown = Redcarpet::Markdown.new renderer, options

    markdown.render(txt).html_safe
  end
end
