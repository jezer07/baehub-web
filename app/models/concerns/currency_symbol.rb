module CurrencySymbol
  extend ActiveSupport::Concern

  def currency_symbol
    couple&.default_currency_symbol || CurrencyCatalog.symbol_for(CurrencyCatalog.default_code)
  end
end
