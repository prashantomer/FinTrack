require "csv"

module Imports
  class CsvTemplateService
    TEMPLATES = {
      "investments" => {
        headers: %w[
          investment_type name isin ticker_symbol exchange fund_house
          amount_invested current_value purchase_date
          quantity buy_price
          units nav_at_purchase
          folio_number platform_name notes
        ],
        rows: [
          ["stock",       "Reliance Industries", "INE002A01018", "RELIANCE", "NSE", "",
           "15000.00", "18500.00", "2024-01-15", "10", "1500.00", "", "", "", "Zerodha", "Long-term hold"],
          ["mutual_fund", "HDFC Top 100 Fund",   "",             "",         "",    "HDFC AMC",
           "50000.00", "62000.00", "2024-02-01", "", "", "100.00", "500.00", "12345678", "Groww", "Monthly SIP"],
        ]
      }.freeze,
      "transactions" => {
        headers: %w[date amount type linked_account_nickname description tags bank_ref],
        rows: [
          ["2024-01-15", "5000.00", "credit", "HDFC Savings", "Salary credit",       "salary",         "NEFT123456"],
          ["2024-01-20", "1200.00", "debit",  "HDFC Savings", "Grocery shopping",    "groceries,food", ""],
          ["2024-02-01", "500.00",  "debit",  "",             "Online subscription", "subscriptions",  ""],
        ]
      }.freeze,
      "term_accounts" => {
        headers: %w[
          account_type parent_account_nickname account_number
          amount open_date interest_rate tenure_days
          maturity_date maturity_amount balance
        ],
        rows: [
          ["fd",  "HDFC Savings", "FD20240115", "100000.00", "2024-01-15", "7.5", "365",
           "2025-01-15", "107500.00", "100000.00"],
          ["ppf", "SBI Savings",  "",           "50000.00",  "2024-04-01", "7.1", "",
           "2039-04-01", "",          "50000.00"],
        ]
      }.freeze
    }.freeze

    def call(import_type)
      template = TEMPLATES[import_type.to_s] || TEMPLATES["investments"]
      CSV.generate(headers: true) do |csv|
        csv << template[:headers]
        template[:rows].each { |row| csv << row }
      end
    end
  end
end
