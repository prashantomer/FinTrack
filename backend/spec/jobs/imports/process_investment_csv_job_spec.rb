require "rails_helper"

RSpec.describe Imports::ProcessInvestmentCsvJob, type: :job do
  let(:user) { create(:user) }

  def attach_csv(batch, csv_text)
    batch.file.purge
    batch.file.attach(
      io:           StringIO.new(csv_text),
      filename:     "test.csv",
      content_type: "text/csv"
    )
  end

  context "with a Zerodha Coin MF Orders CSV" do
    let(:csv) do
      <<~CSV
        symbol,isin,trade_date,exchange,segment,series,trade_type,auction,quantity,price,trade_id,order_id,order_execution_time
        SBI BANKING & FINANCIAL SERVICES FUND - DIRECT PLAN,INF200KA1507,2023-08-14,BSE,MF,,buy,FALSE,163.584000,30.563800,799259193,799259193,2023-08-14T00:00:00
        NIPPON INDIA LIQUID FUND - DIRECT PLAN,INF204K01ZH0,2023-09-07,BSE,MF,,sell,FALSE,7.000000,5674.340000,824805051,824805051,2023-09-07T00:00:00
      CSV
    end

    let(:batch) do
      b = create(:import_batch, user: user, import_type: "investments")
      attach_csv(b, csv)
      b
    end

    it "creates an Investment for each row" do
      expect { described_class.new.perform(batch.id) }.to change(Investment, :count).by(2)
    end

    it "marks the batch completed and counts rows" do
      described_class.new.perform(batch.id)
      batch.reload
      expect(batch.status).to eq("completed")
      expect(batch.total_rows).to eq(2)
      expect(batch.processed_rows).to eq(2)
      expect(batch.failed_rows).to eq(0)
    end

    it "maps MF segment to mutual_fund and computes amount_invested = quantity × price" do
      described_class.new.perform(batch.id)
      buy = Investment.find_by(order_id: "799259193")
      expect(buy.investment_type).to eq("mutual_fund")
      expect(buy.trade_type).to eq("buy")
      expect(buy.units.to_f).to be_within(1e-3).of(163.584)
      expect(buy.quantity).to be_nil
      expect(buy.price.to_f).to be_within(1e-4).of(30.5638)
      expect(buy.amount_invested.to_f).to eq(4999.75)
    end

    it "links lots to a 'Coin by Zerodha' platform account" do
      create(:platform, name: "Coin by Zerodha", short_name: "COIN", platform_type: "mf_platform")
      described_class.new.perform(batch.id)
      buy = Investment.find_by(order_id: "799259193")
      expect(buy.platform_account&.platform&.name).to eq("Coin by Zerodha")
    end

    it "preserves sell trades" do
      described_class.new.perform(batch.id)
      sell = Investment.find_by(order_id: "824805051")
      expect(sell.trade_type).to eq("sell")
    end
  end

  context "with the legacy normalized CSV format" do
    let(:csv) do
      <<~CSV
        trade_type,investment_type,name,isin,amount_invested,purchase_date,quantity,price,platform_name
        buy,stock,Acme Corp,INE001A01036,10000,2024-01-15,100,100.00,
      CSV
    end

    let(:batch) do
      b = create(:import_batch, user: user, import_type: "investments")
      attach_csv(b, csv)
      b
    end

    it "still imports through the Default adapter" do
      expect { described_class.new.perform(batch.id) }.to change(Investment, :count).by(1)
      expect(batch.reload.status).to eq("completed")
    end
  end
end
