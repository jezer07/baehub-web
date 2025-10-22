module ApplicationHelper
  def flash_class(type)
    case type.to_sym
    when :notice
      "bg-success-50 text-success-800 border-success-200"
    when :alert, :error
      "bg-error-50 text-error-800 border-error-200"
    when :warning
      "bg-yellow-50 text-yellow-800 border-yellow-200"
    else
      "bg-blue-50 text-blue-800 border-blue-200"
    end
  end

  def flash_icon(type)
    case type.to_sym
    when :notice
      '<svg class="h-5 w-5 text-success-400" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
      </svg>'.html_safe
    when :alert, :error
      '<svg class="h-5 w-5 text-error-400" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
      </svg>'.html_safe
    when :warning
      '<svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
      </svg>'.html_safe
    else
      '<svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
      </svg>'.html_safe
    end
  end

  def user_avatar(user, size: 'medium')
    size_classes = {
      'small' => 'w-8 h-8 text-xs',
      'medium' => 'w-12 h-12 text-sm',
      'large' => 'w-24 h-24 text-xl'
    }

    css_classes = "#{size_classes[size]} rounded-full object-cover"

    if user.avatar_url.present?
      image_tag(user.avatar_url, alt: user.name.to_s, class: css_classes)
    else
      name_for_initials = user.name.to_s.presence || user.email.to_s
      initials = name_for_initials.split(/[@\s]/).map(&:first).take(2).join.upcase
      placeholder_classes = "#{size_classes[size]} bg-primary-500 text-white rounded-full flex items-center justify-center font-semibold"
      content_tag(:div, initials, class: placeholder_classes)
    end
  end

  def user_display_name(user)
    user.name.present? ? user.name : user.email.split('@').first
  end
end
