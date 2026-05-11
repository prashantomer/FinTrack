require "rails_helper"

RSpec.describe "Api::V1::Accounts audit_logs pagination", type: :request do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, balance: 0) }
  let(:headers) { auth_headers(user) }

  # Generate `n` real balance audits by walking the model through update!.
  # `audited` writes one row per save. Delete the account-creation audit
  # first so each test reasons about exactly `n` rows.
  def seed_audits!(n)
    Audited::Audit.where(auditable: account).delete_all
    Audited.audit_class.as_user(user) do
      n.times do |i|
        account.audit_comment = "txn:#{1000 + i}"
        account.update!(balance: account.balance + 1)
      end
    end
  end

  describe "GET /accounts/:id/audit-logs" do
    it "defaults to a page of 50 with next_cursor when more rows exist" do
      seed_audits!(75)
      get "/api/v1/accounts/#{account.id}/audit-logs", headers: headers
      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json["data"].size).to eq(50)
      expect(json.dig("meta_data", "next_cursor")).to be_an(Integer)
    end

    it "honours ?limit= and caps at 200" do
      seed_audits!(10)
      get "/api/v1/accounts/#{account.id}/audit-logs?limit=5", headers: headers
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(5)
    end

    it "returns next_cursor=null on the final page" do
      seed_audits!(3)
      get "/api/v1/accounts/#{account.id}/audit-logs", headers: headers
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(3)
      expect(json.dig("meta_data", "next_cursor")).to be_nil
    end

    it "walks page-by-page via ?before= cursor" do
      seed_audits!(15)
      get "/api/v1/accounts/#{account.id}/audit-logs?limit=5", headers: headers
      page1 = JSON.parse(response.body)
      cursor1 = page1.dig("meta_data", "next_cursor")
      expect(page1["data"].size).to eq(5)
      expect(cursor1).to be_an(Integer)

      get "/api/v1/accounts/#{account.id}/audit-logs?limit=5&before=#{cursor1}", headers: headers
      page2 = JSON.parse(response.body)
      cursor2 = page2.dig("meta_data", "next_cursor")
      expect(page2["data"].size).to eq(5)
      expect(page2["data"].map { |a| a["id"] }).not_to include(*page1["data"].map { |a| a["id"] })

      get "/api/v1/accounts/#{account.id}/audit-logs?limit=5&before=#{cursor2}", headers: headers
      page3 = JSON.parse(response.body)
      expect(page3["data"].size).to eq(5)
      expect(page3.dig("meta_data", "next_cursor")).to be_nil
    end
  end
end
