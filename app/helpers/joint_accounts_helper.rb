module JointAccountsHelper
  def format_joint_account_amount(cents, currency)
    symbol = CurrencyCatalog.symbol_for(currency)
    "#{symbol}#{sprintf('%.2f', cents / 100.0)}"
  end

  def joint_account_status_badge(status)
    case status.to_s
    when "active"
      content_tag(:span, status.titleize, class: "px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800")
    when "inactive"
      content_tag(:span, status.titleize, class: "px-3 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800")
    when "archived"
      content_tag(:span, status.titleize, class: "px-3 py-1 rounded-full text-xs font-medium bg-neutral-100 text-neutral-800")
    else
      content_tag(:span, status.titleize, class: "px-3 py-1 rounded-full text-xs font-medium bg-neutral-100 text-neutral-800")
    end
  end

  def balance_color_class(balance_cents)
    if balance_cents < 0
      "text-red-700"
    elsif balance_cents > 0
      "text-green-700"
    else
      "text-neutral-700"
    end
  end

  def balance_background_class(balance_cents)
    if balance_cents < 0
      "bg-red-50"
    elsif balance_cents > 0
      "bg-green-50"
    else
      "bg-neutral-50"
    end
  end

  def direction_badge(direction)
    if direction == "partner_owes_joint_account"
      content_tag(:span, "Borrowed from account", class: "text-xs px-2 py-1 rounded-full bg-red-100 text-red-700")
    else
      content_tag(:span, "Lent to account", class: "text-xs px-2 py-1 rounded-full bg-green-100 text-green-700")
    end
  end
end

