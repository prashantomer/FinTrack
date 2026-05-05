require "rails_helper"

RSpec.describe Imports::ProcessInvestmentRowService, type: :service do
  let(:user)  { create(:user) }
  let(:batch) { create(:import_batch, user: user, import_type: "investments") }

  # Builds a row hash with symbol keys — the service uses @row[:key] so a Hash works.
  def build_row(overrides = {})
    {
      investment_type:  "stock",
      name:             "Acme Corporation",
      isin:             "INE001A01036",
      ticker_symbol:    "ACME",
      exchange:         "NSE",
      fund_house:       nil,
      amount_invested:  "10000",
      current_value:    "12000",
      purchase_date:    "2024-01-15",
      quantity:         "100",
      buy_price:        "100.0",
      units:            nil,
      nav_at_purchase:  nil,
      folio_number:     nil,
      platform_name:    nil,
      notes:            nil
    }.merge(overrides)
  end

  def call_service(idx: 0, **row_overrides)
    described_class.new(batch, build_row(row_overrides), idx).call
  end

  describe "#call" do
    context "when the instrument does not exist" do
      it "creates a new Instrument record" do
        expect { call_service }.to change(Instrument, :count).by(1)
      end

      it "sets the instrument name from the row" do
        call_service
        expect(Instrument.last.name).to eq("Acme Corporation")
      end

      it "sets the ISIN on the new instrument" do
        call_service
        expect(Instrument.last.isin).to eq("INE001A01036")
      end
    end

    context "when an instrument with the same ISIN already exists" do
      let!(:existing_instrument) do
        create(:instrument, isin: "INE001A01036", name: "Acme Corporation", investment_type: "stock")
      end

      it "reuses the existing instrument and does not create a new one" do
        expect { call_service }.not_to change(Instrument, :count)
      end

      it "associates the investment with the existing instrument" do
        call_service
        investment = Investment.last
        expect(investment.user_instrument.instrument).to eq(existing_instrument)
      end
    end

    context "when matched by ticker_symbol (no ISIN in row)" do
      let!(:existing_instrument) do
        create(:instrument, isin: nil, ticker_symbol: "ACME", name: "Acme Corporation", investment_type: "stock")
      end

      it "reuses the existing instrument" do
        expect { call_service(isin: nil) }.not_to change(Instrument, :count)
      end
    end

    describe "UserInstrument creation" do
      it "creates a UserInstrument linking the user to the instrument" do
        expect { call_service }.to change(UserInstrument, :count).by(1)
      end

      it "does not create duplicate UserInstruments on repeated imports" do
        call_service
        expect { call_service }.not_to change(UserInstrument, :count)
      end
    end

    describe "Investment creation" do
      it "creates an Investment record" do
        expect { call_service }.to change(Investment, :count).by(1)
      end

      it "sets amount_invested correctly" do
        call_service
        expect(Investment.last.amount_invested).to eq(10_000.0)
      end

      it "sets purchase_date correctly" do
        call_service
        expect(Investment.last.purchase_date).to eq(Date.new(2024, 1, 15))
      end

      it "sets current_value when provided" do
        call_service
        expect(Investment.last.current_value).to eq(12_000.0)
      end

      it "accepts DD/MM/YYYY date format" do
        call_service(purchase_date: "15/01/2024")
        expect(Investment.last.purchase_date).to eq(Date.new(2024, 1, 15))
      end

      it "accepts DD-MM-YYYY date format" do
        call_service(purchase_date: "15-01-2024")
        expect(Investment.last.purchase_date).to eq(Date.new(2024, 1, 15))
      end

      it "sets investment_type to stock" do
        call_service
        expect(Investment.last.investment_type).to eq("stock")
      end

      it "sets investment_type to mutual_fund when provided" do
        call_service(investment_type: "mutual_fund")
        expect(Investment.last.investment_type).to eq("mutual_fund")
      end
    end

    describe "PlatformAccount creation" do
      let!(:platform) { create(:platform, name: "Zerodha", platform_type: "broker") }

      it "creates a PlatformAccount when platform_name matches a known platform" do
        expect { call_service(platform_name: "Zerodha") }.to change(PlatformAccount, :count).by(1)
      end

      it "reuses an existing PlatformAccount when nickname matches" do
        create(:platform_account, user: user, platform: platform, nickname: "Zerodha")
        expect { call_service(platform_name: "Zerodha") }.not_to change(PlatformAccount, :count)
      end

      it "does not create a PlatformAccount when platform_name is nil" do
        expect { call_service(platform_name: nil) }.not_to change(PlatformAccount, :count)
      end

      it "links the investment to the PlatformAccount" do
        call_service(platform_name: "Zerodha")
        expect(Investment.last.platform_account).to be_present
      end
    end

    describe "ImportRecord creation" do
      it "creates an ImportRecord with status :ok" do
        expect { call_service }.to change(ImportRecord, :count).by(1)
      end

      it "sets the import record status to ok" do
        call_service
        expect(ImportRecord.last.status).to eq("ok")
      end

      it "sets the correct row_index" do
        call_service(idx: 3)
        expect(ImportRecord.last.row_index).to eq(3)
      end

      it "sets importable to the created investment" do
        call_service
        expect(ImportRecord.last.importable).to eq(Investment.last)
      end
    end

    describe "error cases" do
      it "raises when name is blank" do
        expect { call_service(name: "") }.to raise_error(/name is required/)
      end

      it "raises when investment_type is invalid" do
        expect { call_service(investment_type: "nps") }.to raise_error(/not valid/)
      end

      it "raises when purchase_date is blank" do
        expect { call_service(purchase_date: "") }.to raise_error(/purchase_date is required/)
      end

      it "raises when purchase_date format is unrecognisable" do
        expect { call_service(purchase_date: "Jan 15 2024") }.to raise_error(/Invalid purchase_date/)
      end
    end
  end
end
