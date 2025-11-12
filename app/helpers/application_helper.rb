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

  def user_avatar(user, size: "medium")
    size_classes = {
      "small" => "w-8 h-8 text-xs",
      "medium" => "w-12 h-12 text-sm",
      "large" => "w-24 h-24 text-xl"
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
    user.name.present? ? user.name : user.email.split("@").first
  end

  def format_event_datetime(datetime, timezone, format: :long)
    return "Not set" if datetime.blank?

    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    converted_time = datetime.in_time_zone(tz)

    case format
    when :long
      tz_abbr = timezone_abbreviation(timezone)
      converted_time.strftime("%A, %B %-d, %Y at %-I:%M %p #{tz_abbr}")
    when :short
      converted_time.strftime("%b %-d, %-I:%M %p")
    when :date_only
      converted_time.strftime("%A, %B %-d, %Y")
    when :time_only
      converted_time.strftime("%-I:%M %p")
    else
      converted_time.to_s
    end
  end

  def format_event_date_range(event, timezone)
    return "Not scheduled" if event.starts_at.blank?

    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    start_time = event.starts_at.in_time_zone(tz)
    end_time = event.ends_at&.in_time_zone(tz)

    if event.all_day?
      if event.single_day_event?
        start_time.strftime("%b %-d")
      elsif end_time.present?
        "#{start_time.strftime('%b %-d')} - #{end_time.strftime('%b %-d')}"
      else
        start_time.strftime("%b %-d")
      end
    else
      if event.single_day_event?
        if end_time.present?
          "#{start_time.strftime('%b %-d, %-I:%M %p')} - #{end_time.strftime('%-I:%M %p')}"
        else
          start_time.strftime("%b %-d, %-I:%M %p")
        end
      elsif end_time.present?
        "#{start_time.strftime('%b %-d, %-I:%M %p')} - #{end_time.strftime('%b %-d, %-I:%M %p')}"
      else
        start_time.strftime("%b %-d, %-I:%M %p")
      end
    end
  end

  def event_time_badge_class(event)
    base_classes = "inline-flex items-center px-3 py-1 rounded-full border"

    if event.in_progress?
      "#{base_classes} bg-success-50 text-success-700 border-success-200 animate-pulse"
    elsif event.starts_at < Time.current
      "#{base_classes} bg-gray-50 text-gray-700 border-gray-200"
    else
      "#{base_classes} bg-blue-50 text-blue-700 border-blue-200"
    end
  end

  def timezone_abbreviation(timezone)
    tz = ActiveSupport::TimeZone[timezone]
    return "UTC" if tz.blank?

    time_now = Time.current.in_time_zone(tz)
    time_now.strftime("%Z")
  end

  def contrasting_text_color(bg_color)
    rgb = parse_color_to_rgb(bg_color)
    return "#111111" if rgb.nil?

    luminance = calculate_relative_luminance(rgb)
    luminance > 0.5 ? "#000000" : "#ffffff"
  end

  def safe_event_color(event)
    return "#e5e7eb" if event.color.blank?

    rgb = parse_color_to_rgb(event.color)
    return "#e5e7eb" if rgb.nil?

    event.color
  end

  def expense_split_icon(split_strategy)
    case split_strategy.to_s
    when "equal"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 6h18M3 12h18M3 18h18"/>
      </svg>'.html_safe
    when "percentage"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z"/>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z"/>
      </svg>'.html_safe
    when "custom_amounts"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
      </svg>'.html_safe
    else
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
      </svg>'.html_safe
    end
  end

  def format_expense_share(share)
    if share.share_type == :percentage
      "#{share.percentage}% (#{share.formatted_amount})"
    else
      share.formatted_amount
    end
  end

  def transaction_impact_for_user(transaction, user)
    case transaction[:type]
    when :expense
      expense_impact_for_user(transaction[:object], user)
    when :settlement
      settlement_impact_for_user(transaction[:object], user)
    else
      { impact_cents: 0, currency: CurrencyCatalog.default_code }
    end
  end

  def expense_impact_for_user(expense, user)
    user_share = expense.expense_shares.find { |share| share.user_id == user.id }
    user_share_cents = user_share&.calculated_amount || 0

    impact_cents = if expense.spender_id == user.id
      expense.amount_cents - user_share_cents
    else
      -user_share_cents
    end

    currency_code = expense.couple&.default_currency || CurrencyCatalog.default_code
    { impact_cents: impact_cents, currency: currency_code }
  end

  def settlement_impact_for_user(settlement, user)
    impact_cents = if settlement.payer_id == user.id
      -settlement.amount_cents
    elsif settlement.payee_id == user.id
      settlement.amount_cents
    else
      0
    end

    currency_code = settlement.couple&.default_currency || CurrencyCatalog.default_code
    { impact_cents: impact_cents, currency: currency_code }
  end

  def format_impact_badge(impact_cents, currency)
    return "" if impact_cents == 0

    amount = (impact_cents.abs / 100.0)
    symbol = CurrencyCatalog.symbol_for(currency)

    formatted_amount = "#{symbol}#{'%.2f' % amount}"

    if impact_cents > 0
      badge_class = "text-xs font-semibold text-green-700 bg-green-50 px-3 py-1 rounded-full border border-green-200"
      sign = "+"
    else
      badge_class = "text-xs font-semibold text-red-700 bg-red-50 px-3 py-1 rounded-full border border-red-200"
      sign = "−"
    end

    content_tag(:span, "#{sign}#{formatted_amount}", class: badge_class)
  end

  private

  def parse_color_to_rgb(color)
    return nil if color.blank?

    if color.match?(/\A#[0-9a-fA-F]{6}\z/)
      r = color[1..2].to_i(16)
      g = color[3..4].to_i(16)
      b = color[5..6].to_i(16)
      [ r, g, b ]
    elsif color.match?(/\Argba?\(/)
      matches = color.match(/rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*[\d.]+\s*)?\)/)
      return nil unless matches

      r = matches[1].to_i
      g = matches[2].to_i
      b = matches[3].to_i
      [ r, g, b ]
    else
      nil
    end
  end

  def calculate_relative_luminance(rgb)
    r, g, b = rgb.map do |channel|
      normalized = channel / 255.0
      if normalized <= 0.03928
        normalized / 12.92
      else
        ((normalized + 0.055) / 1.055) ** 2.4
      end
    end

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end
end
