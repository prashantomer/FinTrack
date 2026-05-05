module Reports
  class DashboardService
    def initialize(user)
      @user  = user
      @today = Date.today
    end

    def call
      Rails.cache.fetch("dashboard/#{@user.id}", expires_in: 5.minutes) do
        compute
      end
    end

    private

    def compute
      first_of_month      = @today.beginning_of_month
      first_of_prev_month = (first_of_month - 1.day).beginning_of_month
      last_of_prev_month  = first_of_month - 1.day

      base    = @user.transactions.active
      credits = base.credit
      debits  = base.debit

      total_inbound       = credits.sum(:amount).to_f
      total_outbound      = debits.sum(:amount).to_f
      this_month_inbound  = credits.where(date: first_of_month..).sum(:amount).to_f
      this_month_outbound = debits.where(date: first_of_month..).sum(:amount).to_f
      prev_month_inbound  = credits.where(date: first_of_prev_month..last_of_prev_month).sum(:amount).to_f
      prev_month_outbound = debits.where(date: first_of_prev_month..last_of_prev_month).sum(:amount).to_f

      accounts          = @user.accounts.open.includes(:bank).order(balance: :desc)
      accounts_balance  = accounts.sum(:balance).to_f

      active_term           = @user.term_accounts.active.includes(parent_account: :bank)
      term_accounts_balance = active_term.sum(:balance).to_f

      cutoff   = @today + 90.days
      upcoming = active_term.select { |ta| ta.maturity_date <= cutoff }.sort_by(&:maturity_date)

      investments = @user.investments.all
      by_type     = investments.group_by(&:investment_type)
      holdings    = by_type.map do |inv_type, invs|
        invested = invs.sum { |i| i.amount_invested.to_f }
        current  = invs.sum { |i| (i.current_value || i.amount_invested).to_f }
        {
          type:            inv_type,
          investment_type: inv_type,
          total_invested:  invested,
          current_value:   current,
          unrealized_gain: current - invested,
          count:           invs.count
        }
      end.sort_by { |h| -h[:current_value] }

      total_invested  = holdings.sum { |h| h[:total_invested] }
      portfolio_value = holdings.sum { |h| h[:current_value] }
      unrealized_gain = portfolio_value - total_invested
      net_worth       = accounts_balance + term_accounts_balance + portfolio_value

      recent = @user.transactions.active.order(date: :desc, id: :desc).limit(8)

      {
        net_worth:             net_worth,
        accounts_balance:      accounts_balance,
        term_accounts_balance: term_accounts_balance,
        portfolio_value:       portfolio_value,
        total_invested:        total_invested,
        unrealized_gain:       unrealized_gain,
        total_inbound:         total_inbound,
        total_outbound:        total_outbound,
        net_balance:           total_inbound - total_outbound,
        this_month_inbound:    this_month_inbound,
        this_month_outbound:   this_month_outbound,
        this_month_net:        this_month_inbound - this_month_outbound,
        prev_month_inbound:    prev_month_inbound,
        prev_month_outbound:   prev_month_outbound,
        accounts: accounts.map { |a|
          { id: a.id, nickname: a.nickname, bank_short_name: a.bank&.short_name,
            account_type: a.account_type, balance: a.balance.to_f }
        },
        upcoming_maturities: upcoming.map { |ta|
          { id: ta.id, account_number: ta.account_number,
            type: ta.account_type, account_type: ta.account_type,
            bank_short_name: ta.parent_account&.bank&.short_name,
            balance: ta.balance.to_f, maturity_date: ta.maturity_date,
            maturity_amount: ta.maturity_amount&.to_f,
            days_remaining: (ta.maturity_date - @today).to_i }
        },
        investment_holdings: holdings,
        recent_transactions: recent.map { |t|
          { id: t.id, date: t.date,
            type: t.transaction_type, transaction_type: t.transaction_type,
            amount: t.amount.to_f, description: t.description, tags: t.tags || [] }
        }
      }
    end
  end
end
