# encoding: utf-8

module CurrencyCatalog
  SUPPORTED_CURRENCIES = {
    "USD" => { symbol: "$" },
    "EUR" => { symbol: "€" },
    "GBP" => { symbol: "£" },
    "JPY" => { symbol: "¥" },
    "CAD" => { symbol: "C$" },
    "AUD" => { symbol: "A$" },
    "PHP" => { symbol: "₱" }
  }.freeze

  DEFAULT_CODE = "USD".freeze

  module_function

  def codes
    SUPPORTED_CURRENCIES.keys
  end

  def default_code
    DEFAULT_CODE
  end

  def symbol_for(code)
    SUPPORTED_CURRENCIES[code.to_s.upcase]&.fetch(:symbol, code) || code
  end

  def options_for_select
    SUPPORTED_CURRENCIES.map do |code, details|
      [ "#{code} (#{details[:symbol]})", code ]
    end
  end
end
