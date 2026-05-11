require "rails_helper"

RSpec.describe Imports::TransactionFormatAdapters do
  describe ".for_headers" do
    it "returns Icici when the ICICI signature is present" do
      headers = %i[ s_no value_date transaction_date cheque_number transaction_remarks
                    withdrawal_amount_inr deposit_amount_inr balance_inr ]
      expect(described_class.for_headers(headers)).to eq(described_class::Icici)
    end

    it "returns Default for the canonical CSV schema" do
      headers = %i[ date amount type linked_account_nickname description tags bank_ref ]
      expect(described_class.for_headers(headers)).to eq(described_class::Default)
    end

    it "normalises string headers to symbols before matching" do
      headers = [ "S No.", "Transaction Date", "Transaction Remarks" ].map(&:downcase).map { |h| h.gsub(/[^a-z0-9]+/, "_").gsub(/^_|_$/, "").to_sym }
      expect(described_class.for_headers(headers)).to eq(described_class::Icici)
    end
  end

  describe described_class::Default do
    it "passes through a CSV::Row-style hash with symbol keys" do
      row = { date: "2026-04-01", amount: "100", type: "debit" }
      expect(described_class.transform(row)).to eq(row)
    end
  end

  describe described_class::Icici do
    let(:debit_row) do
      {
        s_no:                  "1",
        transaction_date:      "01-04-2026",
        transaction_remarks:   "UPI/ZERODHA BR/zerodhabroking/0396009414/HDFC BANK/103125387926/UPIadfaf89bc12b5830b5c9fcc4da9143db/",
        withdrawal_amount_inr: "10000.00",
        deposit_amount_inr:    "0.00"
      }
    end

    let(:credit_row) do
      {
        s_no:                  "2",
        transaction_date:      "01-04-2026",
        transaction_remarks:   "NEFT-HDFCH00902261219-PRASHANT OMER",
        withdrawal_amount_inr: "0.00",
        deposit_amount_inr:    "200000.00"
      }
    end

    it "maps a withdrawal-only row to a debit transaction" do
      out = described_class.transform(debit_row)
      expect(out[:type]).to   eq("debit")
      expect(out[:amount]).to eq("10000.0")
      expect(out[:date]).to   eq("01-04-2026")
      expect(out[:description]).to start_with("UPI/ZERODHA")
    end

    it "maps a deposit-only row to a credit transaction" do
      out = described_class.transform(credit_row)
      expect(out[:type]).to   eq("credit")
      expect(out[:amount]).to eq("200000.0")
    end

    it "stamps bank_ref with the ICICI prefix and truncates to fit the column" do
      out = described_class.transform(debit_row)
      expect(out[:bank_ref]).to start_with("ICICI:")
      expect(out[:bank_ref].length).to be <= 100
    end

    it "ignores per-row linked_account info (batch picks the account)" do
      expect(described_class.transform(debit_row)[:linked_account_nickname]).to be_nil
    end

    it "raises when both withdrawal and deposit are zero" do
      row = debit_row.merge(withdrawal_amount_inr: "0.00", deposit_amount_inr: "0.00")
      expect { described_class.transform(row) }.to raise_error(/zero withdrawal AND deposit/)
    end

    it "raises when Transaction Remarks is blank" do
      row = debit_row.merge(transaction_remarks: "")
      expect { described_class.transform(row) }.to raise_error(/missing Transaction Remarks/)
    end
  end
end
