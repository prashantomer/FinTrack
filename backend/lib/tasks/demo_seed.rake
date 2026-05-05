namespace :db do
  namespace :seed do
    desc "Wipe and recreate heavy demo data with proper transaction accounting"
    task demo: :environment do
      EMAIL    = "test@fintrack.dev"
      PASSWORD = "password123"

      user = User.find_or_initialize_by(email: EMAIL)
      user.assign_attributes(
        first_name: "Demo", last_name: "User",
        password: PASSWORD, is_active: true, is_superuser: false,
        currency_code: "INR", currency_locale: "en-IN"
      )
      user.save!
      puts "User: #{user.email}"

      user.transactions.delete_all
      user.investments.delete_all
      user.follios.delete_all
      user.term_accounts.delete_all
      user.accounts.delete_all
      user.platform_accounts.delete_all
      user.user_instruments.delete_all
      puts "Cleared existing data"

      # ── Reference data ─────────────────────────────────────────────────────
      hdfc  = Bank.find_by!(short_name: "HDFC")
      sbi   = Bank.find_by!(short_name: "SBI")
      icici = Bank.find_by!(short_name: "ICICI")
      kotak = Bank.find_by!(short_name: "KOTAK")
      axis  = Bank.find_by!(short_name: "AXIS")
      indus = Bank.find_by!(short_name: "INDUS")

      zerodha = Platform.find_by!(short_name: "ZERODHA")
      groww   = Platform.find_by!(short_name: "GROWW")
      kite    = Platform.find_by!(short_name: "KITE")
      upstox  = Platform.find_by!(short_name: "UPSTOX")
      coin    = Platform.find_by!(short_name: "COIN")

      # ── Accounts ─────────────────────────────────────────────────────────
      hdfc_primary = user.accounts.create!(
        bank: hdfc,  nickname: "HDFC Primary",     account_type: "savings",
        account_number: "HDFC0001234", open_date: "2020-06-01"
      )
      sbi_salary = user.accounts.create!(
        bank: sbi,   nickname: "SBI Salary",        account_type: "salary",
        account_number: "SBI0005678",  open_date: "2021-04-01"
      )
      icici_nre = user.accounts.create!(
        bank: icici, nickname: "ICICI NRE",         account_type: "nre",
        account_number: "ICICI009876", open_date: "2022-01-15"
      )
      axis_current = user.accounts.create!(
        bank: axis,  nickname: "Axis Current",      account_type: "current",
        account_number: "AXIS112233",  open_date: "2023-08-10"
      )
      indus_nro = user.accounts.create!(
        bank: indus, nickname: "IndusInd NRO",      account_type: "nro",
        account_number: "INDUS445566", open_date: "2022-03-01"
      )
      user.accounts.create!(
        bank: kotak, nickname: "Kotak Old Savings", account_type: "savings",
        account_number: "KOTAK778899", open_date: "2018-03-01",
        closed_date: "2024-09-15", closed_amount: 62_800.00
      )
      user.accounts.create!(
        bank: sbi, nickname: "SBI Old Salary", account_type: "salary",
        account_number: "SBI0001111",  open_date: "2019-07-01",
        closed_date: "2021-03-31", closed_amount: 8_400.00
      )
      puts "Created #{user.accounts.count} accounts (2 closed)"

      # ── Platform accounts ─────────────────────────────────────────────────
      zerodha_pa = user.platform_accounts.create!(platform: zerodha, nickname: "Zerodha",       account_id: "ZR-PR-123456")
      groww_pa   = user.platform_accounts.create!(platform: groww,   nickname: "Groww MF",      account_id: "GW-789012")
      kite_pa    = user.platform_accounts.create!(platform: kite,    nickname: "Kite - Equities", account_id: "KT-223344")
      coin_pa    = user.platform_accounts.create!(platform: coin,    nickname: "Coin - MFs",    account_id: "CN-556677")
      upstox_pa  = user.platform_accounts.create!(platform: upstox,  nickname: "Upstox",        account_id: "UX-889900")
      puts "Created #{user.platform_accounts.count} platform accounts"

      # ── Transaction helper ────────────────────────────────────────────────
      def txn(user, account, type, amount, desc, date, tags: [], ref: nil)
        user.transactions.create!(
          transaction_type: type, amount: amount, description: desc,
          date: date, tags: tags, bank_ref: ref, linked_account: account
        )
      end

      # ── Opening balance transactions (Apr 2024 — start of history) ────────
      # Represents accumulated savings before tracking begins
      txn(user, hdfc_primary, "credit", 1_400_000.00, "Opening Balance",          Date.new(2024, 4, 30), tags: [ "opening" ])
      txn(user, sbi_salary,   "credit",   100_000.00, "Opening Balance",          Date.new(2024, 4, 30), tags: [ "opening" ])
      txn(user, icici_nre,    "credit",   200_000.00, "Opening Balance",          Date.new(2024, 4, 30), tags: [ "opening" ])
      txn(user, axis_current, "credit",    40_000.00, "Opening Balance",          Date.new(2024, 4, 30), tags: [ "opening" ])
      txn(user, indus_nro,    "credit",    55_000.00, "Opening Balance",          Date.new(2024, 4, 30), tags: [ "opening" ])

      # ── Monthly recurring: May 2024 – Apr 2025 (₹92K salary) ─────────────
      (0..11).each do |i|
        m = Date.new(2024, 5, 1) >> i
        txn(user, sbi_salary,   "credit",  92_000.00, "Salary - #{m.strftime('%b %Y')}", m,       tags: [ "salary" ], ref: "NEFT#{m.strftime('%Y%m')}01")
        txn(user, sbi_salary,   "debit",   68_000.00, "Transfer to HDFC Primary",         m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "credit",  68_000.00, "Transfer from SBI Salary",          m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "debit",   24_000.00, "Rent - #{m.strftime('%b %Y')}",     m + 4,  tags: [ "housing", "rent" ])
        txn(user, hdfc_primary, "debit",    9_100.00, "Groceries & Household",             m + 8,  tags: [ "groceries" ])
        txn(user, hdfc_primary, "debit",    3_800.00, "Electricity & Internet",            m + 5,  tags: [ "utilities" ])
        txn(user, hdfc_primary, "debit",    4_500.00, "Dining & Restaurants",              m + 12, tags: [ "dining" ])
        txn(user, hdfc_primary, "debit",    2_900.00, "Fuel & Transport",                  m + 9,  tags: [ "transport" ])
        txn(user, hdfc_primary, "debit",    1_299.00, "OTT & Subscriptions",               m + 10, tags: [ "subscriptions" ])
      end

      # ── Monthly recurring: May – Sep 2025 (₹98K salary) ──────────────────
      (0..4).each do |i|
        m = Date.new(2025, 5, 1) >> i
        txn(user, sbi_salary,   "credit",  98_000.00, "Salary - #{m.strftime('%b %Y')}", m,       tags: [ "salary" ], ref: "NEFT#{m.strftime('%Y%m')}01")
        txn(user, sbi_salary,   "debit",   70_000.00, "Transfer to HDFC Primary",         m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "credit",  70_000.00, "Transfer from SBI Salary",          m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "debit",   24_000.00, "Rent - #{m.strftime('%b %Y')}",     m + 4,  tags: [ "housing", "rent" ])
        txn(user, hdfc_primary, "debit",    9_100.00, "Groceries & Household",             m + 8,  tags: [ "groceries" ])
        txn(user, hdfc_primary, "debit",    3_800.00, "Electricity & Internet",            m + 5,  tags: [ "utilities" ])
        txn(user, hdfc_primary, "debit",    4_500.00, "Dining & Restaurants",              m + 12, tags: [ "dining" ])
        txn(user, hdfc_primary, "debit",    2_900.00, "Fuel & Transport",                  m + 9,  tags: [ "transport" ])
        txn(user, hdfc_primary, "debit",    1_299.00, "OTT & Subscriptions",               m + 10, tags: [ "subscriptions" ])
      end

      # ── Monthly recurring: Oct 2025 – May 2026 (₹1.15L post-raise) ───────
      (0..7).each do |i|
        m = Date.new(2025, 10, 1) >> i
        txn(user, sbi_salary,   "credit", 115_000.00, "Salary - #{m.strftime('%b %Y')}", m,       tags: [ "salary" ], ref: "NEFT#{m.strftime('%Y%m')}01")
        txn(user, sbi_salary,   "debit",   82_000.00, "Transfer to HDFC Primary",         m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "credit",  82_000.00, "Transfer from SBI Salary",          m + 1,  tags: [ "transfer" ])
        txn(user, hdfc_primary, "debit",   26_000.00, "Rent - #{m.strftime('%b %Y')}",     m + 4,  tags: [ "housing", "rent" ])
        txn(user, hdfc_primary, "debit",   10_200.00, "Groceries & Household",             m + 8,  tags: [ "groceries" ])
        txn(user, hdfc_primary, "debit",    4_200.00, "Electricity & Internet",            m + 5,  tags: [ "utilities" ])
        txn(user, hdfc_primary, "debit",    5_100.00, "Dining & Restaurants",              m + 12, tags: [ "dining" ])
        txn(user, hdfc_primary, "debit",    3_100.00, "Fuel & Transport",                  m + 9,  tags: [ "transport" ])
        txn(user, hdfc_primary, "debit",    1_499.00, "OTT & Subscriptions",               m + 10, tags: [ "subscriptions" ])
      end

      # ── Irregular / one-off transactions ──────────────────────────────────
      # 2024
      txn(user, hdfc_primary, "debit",   18_500.00, "Laptop - Lenovo ThinkPad",        Date.new(2024,  6, 15), tags: [ "electronics" ])
      txn(user, hdfc_primary, "debit",    8_200.00, "Flight - Mumbai-Delhi RT",        Date.new(2024,  7, 22), tags: [ "travel" ])
      txn(user, hdfc_primary, "debit",    6_800.00, "Hotel - Delhi 3N",                Date.new(2024,  7, 23), tags: [ "travel" ])
      txn(user, sbi_salary,   "credit",  42_000.00, "Consulting Invoice #2024-07",     Date.new(2024,  7, 31), tags: [ "freelance" ])
      txn(user, hdfc_primary, "debit",   12_000.00, "Annual Health Insurance",         Date.new(2024,  8,  5), tags: [ "insurance", "health" ])
      txn(user, icici_nre,    "credit", 180_000.00, "Foreign Remittance - Aug 2024",   Date.new(2024,  8, 12), tags: [ "remittance" ], ref: "SWFT2408A1")
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q2 FY25",             Date.new(2024,  9, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "debit",   22_000.00, "Flight + Hotel - Goa",            Date.new(2024, 10,  3), tags: [ "travel" ])
      txn(user, hdfc_primary, "credit",   7_500.00, "Cashback - Credit Card Oct",      Date.new(2024, 10, 18), tags: [ "cashback" ])
      txn(user, sbi_salary,   "credit",  65_000.00, "Year-end Bonus Q2",               Date.new(2024, 10, 28), tags: [ "salary", "bonus" ])
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q3 FY25",             Date.new(2024, 12, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "debit",   45_000.00, "iPhone 16 Pro",                   Date.new(2024, 12, 20), tags: [ "electronics" ])
      txn(user, hdfc_primary, "debit",    6_500.00, "Christmas Gifts",                 Date.new(2024, 12, 24), tags: [ "shopping" ])
      txn(user, sbi_salary,   "credit",  80_000.00, "Annual Performance Bonus",        Date.new(2024, 12, 30), tags: [ "salary", "bonus" ])

      # 2025
      txn(user, icici_nre,    "credit", 200_000.00, "Foreign Remittance - Jan 2025",   Date.new(2025,  1, 10), tags: [ "remittance" ], ref: "SWFT2501B2")
      txn(user, hdfc_primary, "debit",   15_500.00, "Flight - Bangkok",                Date.new(2025,  1, 18), tags: [ "travel" ])
      txn(user, hdfc_primary, "debit",   22_000.00, "Hotel - Bangkok 4N",              Date.new(2025,  1, 19), tags: [ "travel" ])
      txn(user, hdfc_primary, "debit",   12_000.00, "Medical - Shoulder",              Date.new(2025,  2, 14), tags: [ "medical" ])
      txn(user, hdfc_primary, "credit",  48_000.00, "Health Insurance Claim",          Date.new(2025,  3,  1), tags: [ "insurance", "health" ])
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q4 FY25",             Date.new(2025,  3, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "credit",  22_000.00, "ITR Refund FY24",                 Date.new(2025,  4,  8), tags: [ "tax", "refund" ], ref: "ITRITR2425A")
      txn(user, sbi_salary,   "credit",  90_000.00, "Consulting Invoice #2025-04",     Date.new(2025,  4, 30), tags: [ "freelance" ])
      txn(user, hdfc_primary, "debit",   18_000.00, "Two-Wheeler Insurance",           Date.new(2025,  5, 22), tags: [ "insurance", "vehicle" ])
      txn(user, hdfc_primary, "debit",   35_000.00, "Bike Service + Parts",            Date.new(2025,  6, 10), tags: [ "vehicle" ])
      txn(user, hdfc_primary, "debit",    4_200.00, "Apple One + Spotify Annual",      Date.new(2025,  7,  1), tags: [ "subscriptions" ])
      txn(user, hdfc_primary, "credit",   8_200.00, "Cashback - CC Annual Rewards",    Date.new(2025,  7, 20), tags: [ "cashback" ])
      txn(user, icici_nre,    "credit", 220_000.00, "Foreign Remittance - Aug 2025",   Date.new(2025,  8,  5), tags: [ "remittance" ], ref: "SWFT2508C3")
      txn(user, sbi_salary,   "credit",  75_000.00, "Consulting Invoice #2025-08",     Date.new(2025,  8, 29), tags: [ "freelance" ])
      txn(user, hdfc_primary, "debit",   28_000.00, "MacBook Pro Accessories",         Date.new(2025,  9,  4), tags: [ "electronics" ])
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q2 FY26",             Date.new(2025,  9, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "debit",   16_000.00, "Diwali Shopping",                 Date.new(2025, 10, 28), tags: [ "shopping", "gifts" ])
      txn(user, sbi_salary,   "credit", 100_000.00, "Diwali Bonus",                    Date.new(2025, 10, 29), tags: [ "salary", "bonus" ])
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q3 FY26",             Date.new(2025, 12, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "debit",   42_000.00, "Flight + Hotel - Europe",         Date.new(2025, 12,  5), tags: [ "travel" ])
      txn(user, hdfc_primary, "debit",   25_000.00, "Europe Trip Expenses",            Date.new(2025, 12, 10), tags: [ "travel" ])
      txn(user, sbi_salary,   "credit",  85_000.00, "Year-end Performance Bonus",      Date.new(2025, 12, 28), tags: [ "salary", "bonus" ])

      # 2026
      txn(user, axis_current, "credit",  50_000.00, "Client Payment - Project A",      Date.new(2026,  1, 12), tags: [ "freelance" ])
      txn(user, axis_current, "credit",  75_000.00, "Client Payment - Project B",      Date.new(2026,  2, 18), tags: [ "freelance" ])
      txn(user, icici_nre,    "credit", 250_000.00, "Foreign Remittance - Mar 2026",   Date.new(2026,  3,  3), tags: [ "remittance" ], ref: "SWFT2603D4")
      txn(user, hdfc_primary, "debit",    9_600.00, "Advance Tax Q4 FY26",             Date.new(2026,  3, 15), tags: [ "tax" ])
      txn(user, hdfc_primary, "credit",  35_000.00, "ITR Refund FY25",                 Date.new(2026,  4, 22), tags: [ "tax", "refund" ])
      txn(user, hdfc_primary, "debit",   55_000.00, "Annual Term Insurance Premium",   Date.new(2026,  5,  1), tags: [ "insurance", "life" ])
      txn(user, axis_current, "credit",  60_000.00, "Client Payment - Project C",      Date.new(2026,  5,  3), tags: [ "freelance" ])

      puts "Created #{user.transactions.count} base transactions"

      # ── Term accounts — active FDs (service creates opening debit txn) ────
      fd1 = TermAccounts::CreateService.new(user, {
        parent_account_id: hdfc_primary.id, account_type: "fd",
        account_number: "FD-HDFC-2025-001",
        amount: 200_000.00, interest_rate: 7.25, tenure_days: 365,
        open_date: "2025-06-01"
      }).call
      puts "FD1: #{fd1.account_number} ₹2L @ 7.25% → debited HDFC"

      fd2 = TermAccounts::CreateService.new(user, {
        parent_account_id: sbi_salary.id, account_type: "fd",
        account_number: "FD-SBI-2025-001",
        amount: 100_000.00, interest_rate: 6.8, tenure_days: 180,
        open_date: "2025-11-01"
      }).call
      puts "FD2: #{fd2.account_number} ₹1L @ 6.8% → debited SBI"

      fd3 = TermAccounts::CreateService.new(user, {
        parent_account_id: icici_nre.id, account_type: "fd",
        account_number: "FD-ICICI-2026-001",
        amount: 300_000.00, interest_rate: 7.1, tenure_days: 270,
        open_date: "2026-01-15"
      }).call
      puts "FD3: #{fd3.account_number} ₹3L @ 7.1% → debited ICICI NRE"

      ppf = TermAccounts::CreateService.new(user, {
        parent_account_id: sbi_salary.id, account_type: "ppf",
        account_number: "PPF-SBI-2021-001",
        amount: 1_500.00, interest_rate: 7.1,
        open_date: "2021-04-01", maturity_amount: 450_000.00
      }).call
      puts "PPF: #{ppf.account_number} (matures #{ppf.maturity_date})"

      # ── Closed FDs (manual records + transactions) ────────────────────────
      # FD-HDFC-2024-001: opened Jun 2023 (pre-history), matured Jun 2024
      # No opening debit (pre-history). Maturity credit within history.
      cfd1 = user.term_accounts.create!(
        parent_account_id: hdfc_primary.id, account_type: "fd",
        account_number: "FD-HDFC-2024-001", amount: 150_000.00,
        interest_rate: 6.5, tenure_days: 365,
        open_date: "2023-06-01", maturity_date: "2024-06-01",
        maturity_amount: 159_750.00, balance: 0.0,
        is_active: false, closed_date: "2024-06-01", closed_amount: 159_750.00
      )
      # Maturity credit back to HDFC
      txn(user, hdfc_primary, "credit", 159_750.00, "FD Maturity: #{cfd1.account_number}", Date.new(2024, 6, 1), tags: [ "investment", "fd_maturity" ])

      # FD-SBI-2024-001: opened Jul 2024 (in-history), matured Dec 2024
      # Opening debit from SBI + maturity credit to SBI
      cfd2 = user.term_accounts.create!(
        parent_account_id: sbi_salary.id, account_type: "fd",
        account_number: "FD-SBI-2024-001", amount: 75_000.00,
        interest_rate: 7.0, tenure_days: 180,
        open_date: "2024-07-01", maturity_date: "2024-12-31",
        maturity_amount: 77_625.00, balance: 0.0,
        is_active: false, closed_date: "2024-12-31", closed_amount: 77_625.00
      )
      txn(user, sbi_salary, "debit",  75_000.00, "FD Opening: #{cfd2.account_number}", Date.new(2024, 7, 1),   tags: [ "investment", "fd" ])
      txn(user, sbi_salary, "credit", 77_625.00, "FD Maturity: #{cfd2.account_number}", Date.new(2024, 12, 31), tags: [ "investment", "fd_maturity" ])
      # Link FD balance to SBI as credit transaction (auto via TermAccount create doesn't run here)
      user.transactions.create!(
        transaction_type: "credit", amount: 75_000.00,
        description: "FD Opening: #{cfd2.account_number}", date: Date.new(2024, 7, 1),
        tags: [ "investment", "fd" ], linked_account: cfd2
      )

      puts "Created #{user.term_accounts.count} term accounts (4 active, 2 closed)"

      # ── Instruments ───────────────────────────────────────────────────────
      def find_stock(ticker, *names)
        inst = Instrument.find_by(ticker_symbol: ticker)
        return inst if inst
        names.each do |n|
          inst = Instrument.where("name ILIKE ?", "%#{n}%").where(investment_type: "stock").first
          return inst if inst
        end
        Instrument.find_or_create_by!(ticker_symbol: ticker) { |i|
          i.name = names.first; i.investment_type = "stock"; i.exchange = "NSE"
        }
      end

      def find_mf(*name_frags, fund_house: nil)
        name_frags.each do |frag|
          inst = Instrument.where("name ILIKE ? AND name ILIKE ?", "%#{frag.split[0]}%", "%Direct%")
                           .where(investment_type: "mutual_fund").first
          return inst if inst
        end
        Instrument.find_or_create_by!(name: "#{name_frags.first} - Direct Growth") { |i|
          i.investment_type = "mutual_fund"; i.fund_house = fund_house
        }
      end

      tcs        = find_stock("TCS",        "Tata Consultancy")
      infy       = find_stock("INFY",       "Infosys")
      hdfcbank   = find_stock("HDFCBANK",   "HDFC Bank")
      reliance   = find_stock("RELIANCE",   "Reliance Industries")
      wipro      = find_stock("WIPRO",      "Wipro")
      itc        = find_stock("ITC",        "ITC Ltd")
      bajfinance = find_stock("BAJFINANCE", "Bajaj Finance")

      hdfc_flexi  = find_mf("HDFC Flexi Cap",          fund_house: "HDFC Mutual Fund")
      parag_flexi = find_mf("Parag Parikh Flexi",       fund_house: "PPFAS Mutual Fund")
      mirae_elss  = find_mf("Mirae Asset ELSS",         fund_house: "Mirae Asset")
      sbi_blue    = find_mf("SBI Blue Chip",            fund_house: "SBI Funds Management")
      nippon_idx  = find_mf("Nippon India Index Nifty", fund_house: "Nippon India Mutual Fund")
      axis_mid    = find_mf("Axis Midcap",              fund_house: "Axis Mutual Fund")

      ui_tcs       = user.user_instruments.find_or_create_by!(instrument: tcs)        { |u| u.added_at = "2022-04-01" }
      ui_infy      = user.user_instruments.find_or_create_by!(instrument: infy)       { |u| u.added_at = "2022-06-15" }
      ui_hdfcbank  = user.user_instruments.find_or_create_by!(instrument: hdfcbank)   { |u| u.added_at = "2023-02-10" }
      ui_reliance  = user.user_instruments.find_or_create_by!(instrument: reliance)   { |u| u.added_at = "2023-08-01" }
      ui_wipro     = user.user_instruments.find_or_create_by!(instrument: wipro)      { |u| u.added_at = "2024-01-20" }
      ui_itc       = user.user_instruments.find_or_create_by!(instrument: itc)        { |u| u.added_at = "2024-03-15" }
      ui_bajfin    = user.user_instruments.find_or_create_by!(instrument: bajfinance) { |u| u.added_at = "2024-09-05" }
      ui_hdfc_flexi = user.user_instruments.find_or_create_by!(instrument: hdfc_flexi)  { |u| u.added_at = "2022-05-01" }
      ui_parag      = user.user_instruments.find_or_create_by!(instrument: parag_flexi) { |u| u.added_at = "2022-05-01" }
      ui_mirae      = user.user_instruments.find_or_create_by!(instrument: mirae_elss)  { |u| u.added_at = "2022-05-01" }
      ui_sbi_blue   = user.user_instruments.find_or_create_by!(instrument: sbi_blue)    { |u| u.added_at = "2023-01-10" }
      ui_nippon     = user.user_instruments.find_or_create_by!(instrument: nippon_idx)  { |u| u.added_at = "2023-06-01" }
      ui_axis_mid   = user.user_instruments.find_or_create_by!(instrument: axis_mid)    { |u| u.added_at = "2024-04-01" }

      # ── Stock investments ─────────────────────────────────────────────────
      # Pre-history lots (before May 2024): no debit transaction
      # Post-history lots: debit transaction from HDFC Primary
      history_start = Date.new(2024, 5, 1)

      stocks = [
        # TCS
        { ui: ui_tcs,      name: "TCS",           date: "2022-04-12", amount: 38_500, cv: 49_200, qty: 10,  price: 3850, pa: zerodha_pa },
        { ui: ui_tcs,      name: "TCS",           date: "2023-07-05", amount: 42_500, cv: 47_600, qty: 10,  price: 4250, pa: zerodha_pa },
        { ui: ui_tcs,      name: "TCS",           date: "2024-02-20", amount: 23_280, cv: 24_500, qty:  5,  price: 4656, pa: zerodha_pa },
        { ui: ui_tcs,      name: "TCS",           date: "2025-01-08", amount: 47_850, cv: 50_100, qty: 10,  price: 4785, pa: kite_pa },
        # Infosys
        { ui: ui_infy,     name: "Infosys",       date: "2022-06-22", amount: 28_200, cv: 35_100, qty: 20,  price: 1410, pa: zerodha_pa },
        { ui: ui_infy,     name: "Infosys",       date: "2023-09-14", amount: 31_200, cv: 34_800, qty: 20,  price: 1560, pa: zerodha_pa },
        { ui: ui_infy,     name: "Infosys",       date: "2025-03-20", amount: 16_250, cv: 17_500, qty: 10,  price: 1625, pa: upstox_pa },
        # HDFC Bank
        { ui: ui_hdfcbank, name: "HDFC Bank",     date: "2023-02-18", amount: 30_000, cv: 38_400, qty: 20,  price: 1500, pa: zerodha_pa },
        { ui: ui_hdfcbank, name: "HDFC Bank",     date: "2024-08-10", amount: 35_000, cv: 39_200, qty: 20,  price: 1750, pa: zerodha_pa },
        # Reliance
        { ui: ui_reliance, name: "Reliance",      date: "2023-08-05", amount: 24_600, cv: 29_800, qty: 10,  price: 2460, pa: kite_pa },
        { ui: ui_reliance, name: "Reliance",      date: "2024-11-22", amount: 25_300, cv: 28_100, qty: 10,  price: 2530, pa: kite_pa },
        # Wipro
        { ui: ui_wipro,    name: "Wipro",         date: "2024-01-25", amount: 22_800, cv: 25_600, qty: 40,  price:  570, pa: upstox_pa },
        { ui: ui_wipro,    name: "Wipro",         date: "2025-02-14", amount: 12_400, cv: 14_200, qty: 20,  price:  620, pa: upstox_pa },
        # ITC
        { ui: ui_itc,      name: "ITC",           date: "2024-03-20", amount: 19_500, cv: 22_000, qty: 50,  price:  390, pa: zerodha_pa },
        # Bajaj Finance
        { ui: ui_bajfin,   name: "Bajaj Finance", date: "2024-09-10", amount: 35_400, cv: 41_200, qty:  5,  price: 7080, pa: kite_pa }
      ]

      stocks.each do |s|
        purchase_date = Date.parse(s[:date])
        user.investments.create!(
          investment_type: "stock",
          name: s[:name], amount_invested: s[:amount], current_value: s[:cv],
          purchase_date: purchase_date, user_instrument: s[:ui],
          platform_account: s[:pa], quantity: s[:qty], buy_price: s[:price]
        )
        # Debit transaction only for in-history purchases
        if purchase_date >= history_start
          txn(user, hdfc_primary, "debit", s[:amount],
              "Stock Purchase: #{s[:name]} (#{s[:qty]}×₹#{s[:price]})",
              purchase_date, tags: [ "investment", "stocks" ])
        end
      end

      # ── MF SIP investments (25 months per fund, each lot has a debit txn) ─
      # Period 1: months 0-11 (May 2024 - Apr 2025)  → HDFC ₹10K, Parag ₹8K, Mirae ₹5K
      # Period 2: months 12-16 (May 2025 - Sep 2025) → same
      # Period 3: months 17-24 (Oct 2025 - May 2026) → HDFC ₹15K, Parag ₹10K, Mirae ₹8K
      sip_months = (0..24).map { |i| Date.new(2024, 5, 3) >> i }

      sip_funds = [
        { ui: ui_hdfc_flexi, name: "HDFC Flexi Cap",         pa: groww_pa, folio: "2345678/01",
          nav_lo: 68.5,  nav_hi: 81.2,
          amounts: sip_months.each_with_index.map { |_, i| i < 17 ? 10_000 : 15_000 } },
        { ui: ui_parag,      name: "Parag Parikh Flexi Cap", pa: coin_pa,  folio: "8765432/01",
          nav_lo: 72.0,  nav_hi: 89.4,
          amounts: sip_months.each_with_index.map { |_, i| i < 17 ? 8_000 : 10_000 } },
        { ui: ui_mirae,      name: "Mirae Asset ELSS",       pa: groww_pa, folio: "3456789/01",
          nav_lo: 32.1,  nav_hi: 40.8,
          amounts: sip_months.each_with_index.map { |_, i| i < 17 ? 5_000 : 8_000 } }
      ]

      sip_funds.each do |fund|
        n = sip_months.size
        sip_months.each_with_index do |dt, i|
          nav   = (fund[:nav_lo] + (fund[:nav_hi] - fund[:nav_lo]) * i.to_f / (n - 1)).round(2)
          units = (fund[:amounts][i] / nav).round(3)
          cv    = (units * (fund[:nav_hi] * (1 + rand * 0.06 - 0.01))).round(2)
          user.investments.create!(
            investment_type: "mutual_fund",
            name: fund[:name], amount_invested: fund[:amounts][i], current_value: cv,
            purchase_date: dt, user_instrument: fund[:ui],
            platform_account: fund[:pa], folio_number: fund[:folio],
            units: units, nav_at_purchase: nav
          )
          txn(user, hdfc_primary, "debit", fund[:amounts][i],
              "SIP - #{fund[:name]}", dt, tags: [ "investment", "sip" ])
        end
      end

      # ── Lumpsum MF investments ─────────────────────────────────────────────
      lumpsum_mfs = [
        # SBI Blue Chip — 5 lumpsums, some pre-history
        { ui: ui_sbi_blue, name: "SBI Bluechip", pa: coin_pa, folio: "9876543/01",
          lots: [
            { date: "2023-09-01", amount: 50_000, nav: 70.5,  cv: 62_000 },
            { date: "2024-01-03", amount: 25_000, nav: 74.2,  cv: 30_200 },
            { date: "2024-07-03", amount: 25_000, nav: 78.8,  cv: 28_500 },
            { date: "2025-01-03", amount: 30_000, nav: 81.5,  cv: 33_000 },
            { date: "2025-07-03", amount: 30_000, nav: 84.2,  cv: 31_500 }
          ]
        },
        # Nippon India Index Nifty — quarterly
        { ui: ui_nippon, name: "Nippon Nifty 50 Index", pa: groww_pa, folio: "1122334/01",
          lots: [
            { date: "2024-01-10", amount: 15_000, nav: 200.4, cv: 19_200 },
            { date: "2024-04-10", amount: 15_000, nav: 218.5, cv: 17_800 },
            { date: "2024-07-10", amount: 15_000, nav: 228.0, cv: 17_100 },
            { date: "2024-10-10", amount: 15_000, nav: 235.6, cv: 16_500 },
            { date: "2025-01-10", amount: 15_000, nav: 241.8, cv: 16_200 },
            { date: "2025-04-10", amount: 15_000, nav: 248.6, cv: 15_800 }
          ]
        },
        # Axis Midcap — 3 lumpsum annually
        { ui: ui_axis_mid, name: "Axis Midcap", pa: groww_pa, folio: "5566778/01",
          lots: [
            { date: "2024-04-05", amount: 30_000, nav: 85.2,  cv: 37_800 },
            { date: "2024-10-05", amount: 30_000, nav: 93.5,  cv: 34_200 },
            { date: "2025-04-05", amount: 30_000, nav: 102.8, cv: 31_500 }
          ]
        }
      ]

      lumpsum_mfs.each do |fund|
        fund[:lots].each do |lot|
          purchase_date = Date.parse(lot[:date])
          units = (lot[:amount] / lot[:nav]).round(3)
          user.investments.create!(
            investment_type: "mutual_fund",
            name: fund[:name], amount_invested: lot[:amount], current_value: lot[:cv],
            purchase_date: purchase_date, user_instrument: fund[:ui],
            platform_account: fund[:pa], folio_number: fund[:folio],
            units: units, nav_at_purchase: lot[:nav]
          )
          # Only create debit transaction for in-history purchases
          if purchase_date >= history_start
            txn(user, hdfc_primary, "debit", lot[:amount],
                "MF Purchase - #{fund[:name]}", purchase_date,
                tags: [ "investment", "mutual_fund" ])
          end
        end
      end

      puts "Created #{user.investments.count} investments"

      # ── Follios ───────────────────────────────────────────────────────────
      [
        [ ui_hdfc_flexi, groww_pa, "2345678/01" ],
        [ ui_parag,      coin_pa,  "8765432/01" ],
        [ ui_mirae,      groww_pa, "3456789/01" ],
        [ ui_sbi_blue,   coin_pa,  "9876543/01" ],
        [ ui_nippon,     groww_pa, "1122334/01" ],
        [ ui_axis_mid,   groww_pa, "5566778/01" ]
      ].each do |ui, pa, folio|
        user.follios.create!(user_instrument: ui, platform_account: pa, folio_number: folio)
      end
      puts "Created #{user.follios.count} follios"

      # ── Summary ───────────────────────────────────────────────────────────
      stock_lots = user.investments.where(investment_type: "stock")
      mf_lots    = user.investments.where(investment_type: "mutual_fund")
      puts ""
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "  Demo seed complete"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "  Credentials:       #{EMAIL} / #{PASSWORD}"
      puts "  Accounts:          #{user.accounts.count} (#{user.accounts.where.not(closed_date: nil).count} closed)"
      puts "  Term Accounts:     #{user.term_accounts.count} (#{user.term_accounts.where(is_active: true).count} active)"
      puts "  Transactions:      #{user.transactions.count}"
      puts "  Investments:       #{user.investments.count}"
      puts "    Stocks:          #{stock_lots.count} lots / #{stock_lots.distinct.count(:user_instrument_id)} instruments"
      puts "    Mutual Funds:    #{mf_lots.count} lots / #{mf_lots.distinct.count(:user_instrument_id)} funds"
      puts "  Platform Accounts: #{user.platform_accounts.count}"
      puts "  Follios:           #{user.follios.count}"
      puts "  Tracked Instruments: #{user.user_instruments.count}"
      puts ""
      puts "  Account Balances:"
      [ hdfc_primary, sbi_salary, icici_nre, axis_current, indus_nro ].each do |a|
        puts "    #{a.nickname.ljust(22)} ₹#{a.reload.balance.to_f.round(2)}"
      end
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end
  end
end
