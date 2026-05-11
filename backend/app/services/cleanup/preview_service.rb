module Cleanup
  # Read-only counterpart to ExecuteService. Given a wizard config, returns
  # the count + a small sample of records per sector so the UI can show
  # "About to delete: 50 transactions, 4 import batches, ..." before the
  # user clicks the destructive button.
  class PreviewService
    SAMPLE_LIMIT = 5

    def initialize(user, config)
      @user    = user
      @config  = (config || {}).with_indifferent_access
      @builder = ScopeBuilder.new(user, @config)
    end

    def call
      scopes = @builder.scopes
      sectors = scopes.map do |name, scope|
        before = total_for(name)
        to_del = scope.count
        {
          sector:       name,
          before:       before,
          to_delete:    to_del,
          after:        [ before - to_del, 0 ].max,
          samples:      sample_for(name, scope)
        }
      end

      # Balance reset preview — show which accounts would have their balance
      # zeroed if `reset_balances: true` is enabled.
      balance_reset = if @config[:reset_balances]
        @user.accounts.map { |a| { id: a.id, nickname: a.nickname, before: a.balance.to_f, after: 0.0 } } +
        @user.term_accounts.where(account_type: "ppf").map { |t| { id: t.id, nickname: "PPF #{t.account_number}", before: t.balance.to_f, after: 0.0 } }
      else
        []
      end

      {
        sectors:       sectors,
        total:         sectors.sum { |s| s[:to_delete] },
        balance_reset: balance_reset
      }
    end

    private

    # Total row count per sector for the user — independent of the wizard's
    # date/source filters. Used to show the "before" column in the UI.
    def total_for(sector)
      case sector
      when "transactions"       then @user.transactions.count
      when "investments"        then @user.investments.count
      when "holdings"           then @user.holdings.count
      when "accounts"           then @user.accounts.count
      when "term_accounts"      then @user.term_accounts.count
      when "platform_accounts"  then @user.platform_accounts.count
      when "user_instruments"   then @user.user_instruments.count
      when "import_batches"     then @user.import_batches.count
      when "assistant_messages" then @user.assistant_messages.count
      when "account_audits"
        acct_ids = @user.accounts.pluck(:id)
        ta_ids   = @user.term_accounts.pluck(:id)
        Audited::Audit.where(
          "(auditable_type='Account' AND auditable_id IN (?)) OR " \
          "(auditable_type='TermAccount' AND auditable_id IN (?))",
          acct_ids.presence || [ 0 ], ta_ids.presence || [ 0 ]
        ).count
      else 0
      end
    end

    # Per-sector preview lines. Kept tiny so the JSON response stays small
    # and the UI doesn't have to know about each sector's schema.
    def sample_for(sector, scope)
      scope.limit(SAMPLE_LIMIT).map { |r| format_row(sector, r) }
    end

    def format_row(sector, r)
      case sector
      when "transactions"
        "#{r.date}  #{r.transaction_type[0, 3].upcase}  ₹#{format('%.2f', r.amount)}  #{r.description&.slice(0, 50)}"
      when "investments"
        "#{r.purchase_date}  #{r.investment_type}  #{r.name&.slice(0, 50)}"
      when "holdings"
        "#{r.type}  units=#{r.total_units}"
      when "accounts"
        "#{r.bank.short_name}  #{r.nickname}  ₹#{format('%.2f', r.balance)}"
      when "term_accounts"
        "#{r.account_type.upcase}  #{r.account_number}"
      when "platform_accounts"
        "#{r.platform&.name}  #{r.nickname}"
      when "user_instruments"
        "instrument ##{r.instrument_id}"
      when "import_batches"
        "##{r.import_number} v#{r.import_version}  #{r.import_type}  #{r.file_name}"
      when "assistant_messages"
        "#{r.role}  #{r.created_at.to_date}  #{r.content.to_s.gsub(/\s+/, ' ').slice(0, 60)}"
      when "account_audits"
        "##{r.id}  #{r.auditable_type}##{r.auditable_id}  #{r.comment}"
      else
        r.inspect.slice(0, 80)
      end
    end
  end
end
