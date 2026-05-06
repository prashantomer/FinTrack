require "io/console"
require "securerandom"

# ── Helpers ───────────────────────────────────────────────────────────────
module UsersRakeIO
  module_function

  def prompt(text, default: nil)
    suffix = default ? " [#{default}]" : ""
    print "#{text}#{suffix}: "
    input = $stdin.gets&.strip
    input.nil? || input.empty? ? default.to_s : input
  end

  def prompt_required(text)
    loop do
      value = prompt(text)
      return value unless value.empty?
      puts "  Required."
    end
  end

  def prompt_password(text)
    print "#{text}: "
    pw = $stdin.noecho(&:gets)&.chomp
    puts ""
    pw
  end

  def ask_yna(text, default: "n")
    loop do
      raw = prompt("  #{text} [Y/n/a]", default: default).strip.downcase
      return raw if %w[y n a].include?(raw)
      puts "  Please enter y (yes), n (skip), or a (abort)."
    end
  end
end

CURRENCIES = [
  { label: "INR  – Indian Rupee       ₹  (e.g. ₹1,23,456)", code: "INR", locale: "en-IN" },
  { label: "USD  – US Dollar          $  (e.g. $1,234)",              code: "USD", locale: "en-US" },
  { label: "EUR  – Euro               €  (e.g. €1.234)",   code: "EUR", locale: "de-DE" },
  { label: "GBP  – British Pound      £  (e.g. £1,234)",   code: "GBP", locale: "en-GB" },
  { label: "JPY  – Japanese Yen       ¥  (e.g. ¥123,456)", code: "JPY", locale: "ja-JP" },
  { label: "AUD  – Australian Dollar  A$ (e.g. A$1,234)",             code: "AUD", locale: "en-AU" },
  { label: "CAD  – Canadian Dollar    C$ (e.g. C$1,234)",             code: "CAD", locale: "en-CA" },
  { label: "SGD  – Singapore Dollar   S$ (e.g. S$1,234)",             code: "SGD", locale: "en-SG" },
  { label: "AED  – UAE Dirham         AED (e.g. AED 1,234)",          code: "AED", locale: "ar-AE" },
  { label: "Other – enter manually",                                  code: nil,   locale: nil },
].freeze

def pick_currency
  puts "\nCurrency:"
  CURRENCIES.each_with_index { |c, i| puts "  #{(i + 1).to_s.rjust(2)}.  #{c[:label]}" }
  loop do
    raw = UsersRakeIO.prompt("\nSelect [1-#{CURRENCIES.size}]", default: "1")
    idx = Integer(raw, exception: false)
    next puts("  Please enter a number.") if idx.nil?
    next puts("  Please enter a number between 1 and #{CURRENCIES.size}.") unless (1..CURRENCIES.size).cover?(idx)

    entry = CURRENCIES[idx - 1]
    if entry[:code].nil?
      code   = UsersRakeIO.prompt_required("  Currency code   (e.g. CHF, MXN, BRL)")
      locale = UsersRakeIO.prompt_required("  Locale          (e.g. de-CH, es-MX, pt-BR)")
      return [code, locale]
    end
    return [entry[:code], entry[:locale]]
  end
end

# ── Tasks ─────────────────────────────────────────────────────────────────
namespace :users do
  desc "Create a new user (interactive). Pass GENERATE=1 to auto-generate a random password."
  task create: :environment do
    email      = UsersRakeIO.prompt_required("Email")
    first_name = UsersRakeIO.prompt_required("First name")
    last_name  = UsersRakeIO.prompt_required("Last name")

    password = if ENV["GENERATE"] == "1"
      SecureRandom.urlsafe_base64(16)
    else
      pw  = UsersRakeIO.prompt_password("Password")
      pw2 = UsersRakeIO.prompt_password("Confirm password")
      abort "Passwords do not match." unless pw == pw2 && !pw.to_s.empty?
      pw
    end

    abort "Error: a user with email '#{email}' already exists." if User.exists?(email: email)

    code, locale = pick_currency

    user = User.create!(
      email: email,
      first_name: first_name,
      last_name: last_name,
      password: password,
      password_confirmation: password,
      currency_code: code,
      currency_locale: locale,
    )

    puts "\nUser created successfully"
    puts "  Email:    #{user.email}"
    puts "  Name:     #{user.first_name} #{user.last_name}"
    puts "  Currency: #{user.currency_code}  (#{user.currency_locale})"
    puts "  Password: #{password}"
  end

  WIPE_CATEGORIES = [
    { label: "Follios",           assoc: :follios,           format: ->(f) { "##{f.id}  #{f.folio_number}" } },
    { label: "Platform accounts", assoc: :platform_accounts, format: ->(p) { "##{p.id}  #{(p.platform&.name || '—').ljust(20)}  #{p.nickname}" } },
    { label: "Investments",       assoc: :investments,       format: ->(i) { "##{i.id}  #{i.investment_type.to_s.ljust(15)}  #{i.name}" } },
    { label: "Transactions",      assoc: :transactions,      format: ->(t) { "##{t.id}  #{t.date}  #{t.transaction_type.to_s.ljust(6)}  #{format('%.2f', t.amount).rjust(12)}  #{t.description || '—'}" } },
    { label: "Term accounts",     assoc: :term_accounts,     format: ->(t) { "##{t.id}  #{t.account_type.to_s.upcase.ljust(3)}  #{(t.account_number || '—').ljust(24)}  #{format('%.2f', t.balance).rjust(12)}  #{t.is_active ? 'active' : 'closed'}" } },
    { label: "Accounts",          assoc: :accounts,          format: ->(a) { "##{a.id}  #{a.bank.short_name.ljust(6)}  #{a.nickname.ljust(20)}  #{format('%.2f', a.balance).rjust(12)}  #{a.account_type}" } },
  ].freeze

  desc "Wipe a user's financial data (interactive). Pass FAST=1 to confirm once and delete everything."
  task wipe: :environment do
    email = UsersRakeIO.prompt_required("Email")
    user = User.find_by(email: email)
    abort "Error: no user found with email '#{email}'." unless user

    fast = ENV["FAST"] == "1"

    grouped = WIPE_CATEGORIES.map do |cat|
      records = user.public_send(cat[:assoc]).to_a
      cat.merge(records: records)
    end

    total = grouped.sum { |c| c[:records].size }
    if total.zero?
      puts "\nNo data found for #{email}."
      next
    end

    puts "\nData for #{email}:\n\n"
    width = grouped.map { |c| c[:label].length }.max
    grouped.each do |c|
      count = c[:records].empty? ? "none" : c[:records].size.to_s
      puts "  #{c[:label].ljust(width)}  #{count}"
    end
    puts "  #{'-' * width}  ----"
    puts "  #{'Total'.ljust(width)}  #{total}"

    if fast
      puts ""
      choice = UsersRakeIO.ask_yna("Wipe ALL #{total} records?")
      if choice != "y"
        puts(choice == "a" ? "\nAborted. Nothing deleted." : "\nNothing deleted.")
        next
      end

      ActiveRecord::Base.transaction do
        grouped.each { |c| user.public_send(c[:assoc]).delete_all }
      end
      puts "\nDone — #{total} records deleted."
      next
    end

    wiped = 0
    steps = grouped.reject { |c| c[:records].empty? }
    steps.each_with_index do |c, idx|
      puts "\n#{'-' * 50}"
      puts "  Step #{idx + 1}/#{steps.size}  #{c[:label]}  (#{c[:records].size} records)\n\n"
      c[:records].first(20).each { |r| puts "    #{c[:format].call(r)}" }
      puts "    ... and #{c[:records].size - 20} more" if c[:records].size > 20

      choice = UsersRakeIO.ask_yna("Wipe #{c[:label]}?")
      if choice == "a"
        puts "\nAborted. #{wiped} records already deleted."
        next
      end
      if choice == "n"
        puts "  -> Skipped"
        next
      end

      n = user.public_send(c[:assoc]).delete_all
      wiped += n
      puts "  v Deleted #{n} #{c[:label].downcase}"
    end

    puts "\n#{'-' * 50}"
    puts(wiped.positive? ? "\nDone — #{wiped} records deleted." : "\nNothing deleted.")
  end
end
