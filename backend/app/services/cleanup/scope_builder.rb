module Cleanup
  # Translates a cleanup-wizard config hash into a `{ sector => ActiveRecord::Relation }`
  # bundle. Both the preview and execute services consume this bundle —
  # preview reads, execute deletes. By centralising scope construction
  # here we keep every cleanup query in one auditable place.
  #
  # Config shape (all keys optional):
  #   {
  #     sectors: ["transactions", "investments", "holdings", "accounts",
  #               "term_accounts", "platform_accounts", "user_instruments",
  #               "import_batches", "assistant_messages", "account_audits"],
  #     date_from:   "2024-01-01",  # ISO date; applies to records with a date column
  #     date_to:     "2024-12-31",
  #     source:      "manual" | "imported" | nil,
  #     account_ids: [ 1, 2 ],       # restricts transactions to these accounts
  #     active:      true | false | nil,   # transactions only
  #     tags_any:    [ "salary" ],   # transactions only — any-match (PG &&)
  #   }
  #
  # No models or columns are touched — this only returns relations.
  class ScopeBuilder
    SECTORS = %w[
      transactions investments holdings accounts term_accounts
      platform_accounts user_instruments import_batches
      assistant_messages account_audits
    ].freeze

    def initialize(user, config)
      @user   = user
      @config = (config || {}).with_indifferent_access
      @from   = parse_date(@config[:date_from])
      @to     = parse_date(@config[:date_to])
    end

    def selected_sectors
      Array(@config[:sectors]).map(&:to_s) & SECTORS
    end

    # Returns { "transactions" => scope, "investments" => scope, ... } only
    # for sectors the user opted in to.
    def scopes
      selected_sectors.to_h { |s| [ s, public_send("scope_for_#{s}") ] }
    end

    # ── Per-sector scope builders ─────────────────────────────────────────

    def scope_for_transactions
      s = @user.transactions
      s = s.where(date: @from..)              if @from
      s = s.where(date: ..@to)                if @to
      s = s.where(source: @config[:source])   if %w[manual imported].include?(@config[:source].to_s)
      if Array(@config[:account_ids]).any?
        s = s.where(linked_account_type: "Account", linked_account_id: @config[:account_ids])
      end
      s = s.where(is_active: @config[:active]) unless @config[:active].nil?
      if Array(@config[:tags_any]).any?
        # Postgres array-overlap: any common tag triggers a match.
        s = s.where("tags && ARRAY[?]::varchar[]", Array(@config[:tags_any]))
      end
      s
    end

    def scope_for_investments
      s = @user.investments
      s = s.where(purchase_date: @from..)    if @from
      s = s.where(purchase_date: ..@to)      if @to
      s = s.where(source: @config[:source])  if %w[manual imported].include?(@config[:source].to_s)
      s
    end

    def scope_for_holdings
      # Holdings are derived; no native date column. Account-filter cascades
      # via platform_account; date filters don't apply.
      @user.holdings
    end

    def scope_for_accounts
      # Account-level filter constrains to specific accounts only.
      ids = Array(@config[:account_ids])
      ids.any? ? @user.accounts.where(id: ids) : @user.accounts
    end

    def scope_for_term_accounts
      @user.term_accounts
    end

    def scope_for_platform_accounts
      @user.platform_accounts
    end

    def scope_for_user_instruments
      @user.user_instruments
    end

    def scope_for_import_batches
      s = @user.import_batches
      s = s.where(created_at: @from.beginning_of_day..) if @from
      s = s.where(created_at: ..@to.end_of_day)         if @to
      s
    end

    def scope_for_assistant_messages
      s = @user.assistant_messages
      s = s.where(created_at: @from.beginning_of_day..) if @from
      s = s.where(created_at: ..@to.end_of_day)         if @to
      s
    end

    def scope_for_account_audits
      acct_ids = @user.accounts.pluck(:id)
      ta_ids   = @user.term_accounts.pluck(:id)
      base = Audited::Audit.where(
        "(auditable_type = 'Account'     AND auditable_id IN (?)) OR " \
        "(auditable_type = 'TermAccount' AND auditable_id IN (?))",
        acct_ids.presence || [ 0 ], ta_ids.presence || [ 0 ]
      )
      base = base.where(created_at: @from.beginning_of_day..) if @from
      base = base.where(created_at: ..@to.end_of_day)         if @to
      base
    end

    private

    def parse_date(raw)
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end
  end
end
