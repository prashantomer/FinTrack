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
  { label: "Other – enter manually",                                  code: nil,   locale: nil }
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
      return [ code, locale ]
    end
    return [ entry[:code], entry[:locale] ]
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
      is_dummy: ENV["DUMMY"] == "1",
    )

    puts "\nUser created successfully"
    puts "  Email:    #{user.email}"
    puts "  Name:     #{user.first_name} #{user.last_name}"
    puts "  Currency: #{user.currency_code}  (#{user.currency_locale})"
    puts "  Kind:     #{user.is_dummy? ? 'dummy (demo / seed data)' : 'real'}"
    puts "  Password: #{password}"
  end

  desc "List all users with their kind (real / dummy). Pass KIND=dummy or KIND=real to filter."
  task list: :environment do
    scope =
      case ENV["KIND"].to_s.downcase
      when "dummy" then User.dummy
      when "real"  then User.real
      else              User.all
      end
    scope = scope.order(:id)

    if scope.empty?
      puts "No users."
      next
    end

    fmt = "  %-4s  %-30s  %-25s  %-6s  %s"
    puts ""
    puts sprintf(fmt, "ID", "Email", "Name", "Kind", "Created")
    puts sprintf(fmt, "----", "-----", "----", "----", "-------")
    scope.each do |u|
      puts sprintf(fmt, u.id, u.email, u.full_name, u.is_dummy? ? "DUMMY" : "real", u.created_at.to_date)
    end
    puts ""
    puts "  total: #{scope.count}  (real: #{User.real.count}, dummy: #{User.dummy.count})"
  end

  desc <<~DESC
    Wipe a user's TRANSACTIONAL history while preserving structural records.

    Keeps:  accounts, term accounts, investments, platform accounts, user_instruments
    Wipes:  transactions, holdings (incl. folios), import batches, balance audit rows
    Resets: account.balance and PPF term_account.balance to 0 (FD balances stay
            because they're principal-based, not a running total).

    Use this when you want to re-import statements without rebuilding the
    account or instrument catalogue you set up.

      $ bin/rails users:wipe_history EMAIL=you@example.com         # interactive
      $ bin/rails users:wipe_history EMAIL=you@example.com FAST=1  # no prompt
  DESC
  task wipe_history: :environment do
    email = ENV["EMAIL"] || UsersRakeIO.prompt_required("Email")
    user  = User.find_by(email: email) or abort "No user with email '#{email}'."
    fast  = ENV["FAST"] == "1"

    counts = {
      transactions:    user.transactions.count,
      holdings:        user.holdings.count,           # folios + equity_holdings (STI)
      import_batches:  user.import_batches.count,
      accounts:        user.accounts.count,
      term_accounts:   user.term_accounts.count,
      investments:     user.investments.count
    }
    affected_account_ids       = user.accounts.pluck(:id)
    affected_term_account_ids  = user.term_accounts.pluck(:id)
    audit_count = Audited::Audit
      .where("(auditable_type = 'Account' AND auditable_id IN (?)) OR (auditable_type = 'TermAccount' AND auditable_id IN (?))",
             affected_account_ids, affected_term_account_ids)
      .where("comment LIKE 'txn:%' OR comment = 'carryover'")
      .count

    puts ""
    puts "User: #{email}"
    puts "  to wipe:"
    puts "    transactions:    #{counts[:transactions]}"
    puts "    holdings:        #{counts[:holdings]}"
    puts "    import batches:  #{counts[:import_batches]}"
    puts "    audit rows:      #{audit_count} (txn/carryover only — opening 'create' rows kept)"
    puts "  preserved:"
    puts "    accounts:         #{counts[:accounts]}  (balance reset to 0)"
    puts "    term accounts:    #{counts[:term_accounts]}  (PPF balance reset to 0; FD principal kept)"
    puts "    investments:      #{counts[:investments]}"
    puts "    platform accts:   #{user.platform_accounts.count}"
    puts ""

    unless fast
      choice = UsersRakeIO.ask_yna("Proceed?")
      if choice != "y"
        puts choice == "a" ? "Aborted." : "Nothing deleted."
        next
      end
    end

    ActiveRecord::Base.transaction do
      user.transactions.delete_all
      user.holdings.delete_all
      user.import_batches.destroy_all  # destroy_all to detach ActiveStorage blobs

      Audited::Audit
        .where("(auditable_type = 'Account' AND auditable_id IN (?)) OR (auditable_type = 'TermAccount' AND auditable_id IN (?))",
               affected_account_ids, affected_term_account_ids)
        .where("comment LIKE 'txn:%' OR comment = 'carryover'")
        .delete_all

      user.accounts.update_all(balance: 0)
      user.term_accounts.where(account_type: "ppf").update_all(balance: 0)
    end

    puts "Done. #{user.email} keeps #{counts[:accounts]} accounts, #{counts[:term_accounts]} term accounts, " \
         "#{counts[:investments]} investments, #{user.platform_accounts.count} platform accounts."
  end

  desc "Mark a user as dummy (or real). Usage: rake users:mark EMAIL=foo@bar.com [REAL=1]"
  task mark: :environment do
    email = ENV["EMAIL"] || UsersRakeIO.prompt_required("Email")
    user  = User.find_by(email: email) or abort "No user with email '#{email}'."

    target = ENV["REAL"] == "1" ? false : true
    if user.is_dummy == target
      puts "User #{user.email} is already #{target ? 'dummy' : 'real'}. No change."
      next
    end
    user.update!(is_dummy: target)
    puts "Marked #{user.email} as #{target ? 'DUMMY' : 'real'}."
  end

  # Sector list for `users:wipe`. Order matters — children before parents so
  # `delete_all` doesn't trip foreign-key constraints. `assoc:` covers
  # straight `has_many` associations; `fetch:` is used for the
  # cross-table audit sweep where there's no direct user association.
  # `delete:` defaults to `.delete_all`; the import-batches sector uses
  # `destroy_all` so the attached ActiveStorage blobs are purged too.
  #
  # `assistant_setting` is intentionally NOT in this list — the provider
  # config + encrypted api_key survive `users:wipe` so the user doesn't
  # have to re-enter credentials after a reset.
  WIPE_CATEGORIES = [
    { label: "Assistant messages", assoc: :assistant_messages,
      format: ->(m) { "##{m.id}  #{m.role.to_s.ljust(9)}  #{m.created_at.to_date}  #{(m.content || '').to_s.gsub(/\s+/, ' ').slice(0, 80)}" } },

    { label: "Import batches",     assoc: :import_batches,
      delete: ->(user, _cat) { user.import_batches.destroy_all.size },
      format: ->(b) { "##{b.import_number}  v#{b.import_version}  #{b.import_type.ljust(13)}  #{b.file_name}" } },

    { label: "Account audits",
      fetch:  ->(user) {
        acct_ids = user.accounts.pluck(:id)
        ta_ids   = user.term_accounts.pluck(:id)
        next Audited::Audit.none if acct_ids.empty? && ta_ids.empty?
        Audited::Audit.where(
          "(auditable_type = 'Account'      AND auditable_id IN (?)) OR " \
          "(auditable_type = 'TermAccount'  AND auditable_id IN (?))",
          acct_ids.presence || [ 0 ], ta_ids.presence || [ 0 ]
        )
      },
      delete: ->(user, cat) { cat[:fetch].call(user).delete_all },
      format: ->(a) { "##{a.id}  #{a.auditable_type.ljust(11)}##{a.auditable_id.to_s.ljust(5)}  #{a.created_at.to_date}  #{a.comment}" } },

    { label: "Holdings",           assoc: :holdings,
      format: ->(h) { "##{h.id}  #{h.type.to_s.ljust(15)}  units=#{h.total_units}  ₹#{format('%.2f', h.current_value || 0)}" } },

    { label: "Transactions",       assoc: :transactions,
      format: ->(t) { "##{t.id}  #{t.date}  #{t.transaction_type.to_s.ljust(6)}  #{format('%.2f', t.amount).rjust(12)}  #{t.description || '—'}" } },

    { label: "Investments",        assoc: :investments,
      format: ->(i) { "##{i.id}  #{i.investment_type.to_s.ljust(15)}  #{i.name}" } },

    { label: "User instruments",   assoc: :user_instruments,
      format: ->(ui) { "##{ui.id}  instrument ##{ui.instrument_id}  added=#{ui.added_at&.to_date}" } },

    { label: "Term accounts",      assoc: :term_accounts,
      format: ->(t) { "##{t.id}  #{t.account_type.to_s.upcase.ljust(3)}  #{(t.account_number || '—').ljust(24)}  #{format('%.2f', t.balance).rjust(12)}  #{t.is_active ? 'active' : 'closed'}" } },

    { label: "Accounts",           assoc: :accounts,
      format: ->(a) { "##{a.id}  #{a.bank.short_name.ljust(6)}  #{a.nickname.ljust(20)}  #{format('%.2f', a.balance).rjust(12)}  #{a.account_type}" } },

    { label: "Platform accounts",  assoc: :platform_accounts,
      format: ->(p) { "##{p.id}  #{(p.platform&.name || '—').ljust(20)}  #{p.nickname}" } }
  ].freeze

  # Records for the summary preview.
  def self.wipe_records_for(user, cat)
    return cat[:fetch].call(user).to_a if cat[:fetch]
    user.public_send(cat[:assoc]).to_a
  end

  # Performs the actual deletion. Returns the deleted count. Honours
  # custom `delete:` lambdas (used by Import batches → destroy_all so blobs
  # detach, and by the audit sweep → delete via the fetched scope).
  def self.wipe_delete(user, cat)
    return cat[:delete].call(user, cat) if cat[:delete]
    user.public_send(cat[:assoc]).delete_all
  end

  desc "Wipe everything attached to a user (interactive, sector-by-sector). " \
       "Preserves assistant_setting + the user row. Pass FAST=1 to confirm once and delete everything."
  task wipe: :environment do
    email = UsersRakeIO.prompt_required("Email")
    user  = User.find_by(email: email)
    abort "Error: no user found with email '#{email}'." unless user

    fast = ENV["FAST"] == "1"

    grouped = WIPE_CATEGORIES.map { |cat| cat.merge(records: wipe_records_for(user, cat)) }
    total   = grouped.sum { |c| c[:records].size }

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
    puts "  (preserved)  assistant_setting + user row"

    if fast
      puts ""
      choice = UsersRakeIO.ask_yna("Wipe ALL #{total} records?")
      if choice != "y"
        puts(choice == "a" ? "\nAborted. Nothing deleted." : "\nNothing deleted.")
        next
      end

      ActiveRecord::Base.transaction do
        grouped.each { |c| wipe_delete(user, c) }
      end
      puts "\nDone — #{total} records deleted. assistant_setting preserved."
      next
    end

    wiped = 0
    steps = grouped.reject { |c| c[:records].empty? }
    aborted = false
    steps.each_with_index do |c, idx|
      next if aborted

      puts "\n#{'-' * 50}"
      puts "  Step #{idx + 1}/#{steps.size}  #{c[:label]}  (#{c[:records].size} records)\n\n"
      c[:records].first(20).each { |r| puts "    #{c[:format].call(r)}" }
      puts "    ... and #{c[:records].size - 20} more" if c[:records].size > 20

      choice = UsersRakeIO.ask_yna("Wipe #{c[:label]}?")
      if choice == "a"
        puts "\nAborted. #{wiped} records already deleted."
        aborted = true
        next
      end
      if choice == "n"
        puts "  -> Skipped"
        next
      end

      n = wipe_delete(user, c)
      wiped += n
      puts "  ✓ Deleted #{n} #{c[:label].downcase}"
    end

    puts "\n#{'-' * 50}"
    if wiped.positive?
      puts "\nDone — #{wiped} records deleted. assistant_setting preserved."
    else
      puts "\nNothing deleted."
    end
  end
end
