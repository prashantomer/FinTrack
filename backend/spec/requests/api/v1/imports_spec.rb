require "rails_helper"

RSpec.describe "Api::V1::Imports", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:headers)    { auth_headers(user) }

  # Minimal well-formed CSV for upload tests
  let(:csv_content) { "investment_type,name,amount_invested,purchase_date\nstock,Acme,1000,2024-01-01\n" }
  let(:csv_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new(csv_content),
      "text/csv",
      original_filename: "test_import.csv"
    )
  end

  describe "GET /api/v1/imports" do
    context "with no batches" do
      it "returns HTTP 200 and an empty data array" do
        get "/api/v1/imports", headers: headers
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json["data"]).to be_empty
      end

      it "returns pagination meta_data" do
        get "/api/v1/imports", headers: headers
        json = JSON.parse(response.body)
        expect(json["meta_data"]).to include("total", "page", "page_size")
        expect(json.dig("meta_data", "total")).to eq(0)
      end
    end

    context "with existing batches" do
      before do
        3.times { create(:import_batch, user: user) }
      end

      it "returns all batches for the current user" do
        get "/api/v1/imports", headers: headers
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(3)
      end

      it "does not return other users' batches" do
        create(:import_batch, user: other_user)
        get "/api/v1/imports", headers: headers
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(3)
      end

      it "returns total count in meta_data" do
        get "/api/v1/imports", headers: headers
        json = JSON.parse(response.body)
        expect(json.dig("meta_data", "total")).to eq(3)
      end
    end

    context "with pagination" do
      before do
        22.times { create(:import_batch, user: user) }
      end

      it "returns page_size of 20 on page 1" do
        get "/api/v1/imports", headers: headers, params: { page: 1 }
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(20)
      end

      it "returns remaining records on page 2" do
        get "/api/v1/imports", headers: headers, params: { page: 2 }
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(2)
      end
    end

    context "without authentication" do
      it "returns HTTP 401" do
        get "/api/v1/imports"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/imports/:id" do
    let(:batch) { create(:import_batch, user: user) }

    context "when the batch belongs to the current user" do
      it "returns HTTP 200" do
        get "/api/v1/imports/#{batch.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end

      it "returns the batch data" do
        get "/api/v1/imports/#{batch.id}", headers: headers
        json = JSON.parse(response.body)
        expect(json.dig("data", "id")).to eq(batch.id)
      end
    end

    context "when the batch belongs to another user" do
      let(:other_batch) { create(:import_batch, user: other_user) }

      it "returns HTTP 404" do
        get "/api/v1/imports/#{other_batch.id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a non-existent ID" do
      it "returns HTTP 404" do
        get "/api/v1/imports/999999999", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/imports" do
    before do
      allow(Imports::ProcessInvestmentCsvJob).to receive(:perform_later)
        .and_return(double(provider_job_id: "fake-job-id"))
      allow(Imports::ProcessTransactionCsvJob).to receive(:perform_later)
        .and_return(double(provider_job_id: "fake-job-id"))
      allow(Imports::ProcessTermAccountCsvJob).to receive(:perform_later)
        .and_return(double(provider_job_id: "fake-job-id"))
    end

    context "with a valid investments CSV" do
      it "returns HTTP 201" do
        post "/api/v1/imports",
             params:  { file: csv_file, import_type: "investments" },
             headers: headers
        expect(response).to have_http_status(:created)
      end

      it "creates an ImportBatch record" do
        expect {
          post "/api/v1/imports",
               params:  { file: csv_file, import_type: "investments" },
               headers: headers
        }.to change(ImportBatch, :count).by(1)
      end

      it "enqueues the correct background job" do
        post "/api/v1/imports",
             params:  { file: csv_file, import_type: "investments" },
             headers: headers
        expect(Imports::ProcessInvestmentCsvJob).to have_received(:perform_later)
      end

      it "returns the batch in the response" do
        post "/api/v1/imports",
             params:  { file: csv_file, import_type: "investments" },
             headers: headers
        json = JSON.parse(response.body)
        expect(json.dig("data", "import_type")).to eq("investments")
      end
    end

    context "with a transactions import type" do
      let(:txn_csv) do
        Rack::Test::UploadedFile.new(
          StringIO.new("date,amount,type\n2024-01-01,1000,credit\n"),
          "text/csv",
          original_filename: "transactions.csv"
        )
      end

      it "enqueues the transactions job" do
        post "/api/v1/imports",
             params:  { file: txn_csv, import_type: "transactions" },
             headers: headers
        expect(Imports::ProcessTransactionCsvJob).to have_received(:perform_later)
      end
    end

    context "with a term_accounts import type" do
      let(:ta_csv) do
        Rack::Test::UploadedFile.new(
          StringIO.new("account_type,amount\nfd,50000\n"),
          "text/csv",
          original_filename: "term_accounts.csv"
        )
      end

      it "enqueues the term accounts job" do
        post "/api/v1/imports",
             params:  { file: ta_csv, import_type: "term_accounts" },
             headers: headers
        expect(Imports::ProcessTermAccountCsvJob).to have_received(:perform_later)
      end
    end

    context "with an invalid import_type" do
      it "returns HTTP 422" do
        post "/api/v1/imports",
             params:  { file: csv_file, import_type: "unknown_type" },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns a descriptive error message" do
        post "/api/v1/imports",
             params:  { file: csv_file, import_type: "unknown_type" },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/not supported/i)
      end
    end

    context "without a file" do
      it "returns HTTP 422" do
        post "/api/v1/imports",
             params:  { import_type: "investments" },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns an error indicating file is required" do
        post "/api/v1/imports",
             params:  { import_type: "investments" },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/file is required/i)
      end
    end

    context "with a non-CSV file" do
      let(:non_csv_file) do
        Rack::Test::UploadedFile.new(
          StringIO.new("not csv"),
          "application/json",
          original_filename: "data.json"
        )
      end

      it "returns HTTP 422" do
        post "/api/v1/imports",
             params:  { file: non_csv_file, import_type: "investments" },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns an error about file format" do
        post "/api/v1/imports",
             params:  { file: non_csv_file, import_type: "investments" },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/CSV/i)
      end
    end

    context "with an oversized file (> 5 MB)" do
      let(:large_csv_file) do
        large_content = "a" * (5.megabytes + 1)
        Rack::Test::UploadedFile.new(
          StringIO.new(large_content),
          "text/csv",
          original_filename: "huge.csv"
        )
      end

      it "returns HTTP 422" do
        post "/api/v1/imports",
             params:  { file: large_csv_file, import_type: "investments" },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns a file size error" do
        post "/api/v1/imports",
             params:  { file: large_csv_file, import_type: "investments" },
             headers: headers
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/too large/i)
      end
    end

    context "without authentication" do
      it "returns HTTP 401" do
        post "/api/v1/imports", params: { file: csv_file, import_type: "investments" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/imports/template/:import_type" do
    context "with a valid import_type" do
      %w[investments transactions term_accounts].each do |itype|
        it "returns a CSV file for #{itype}" do
          get "/api/v1/imports/template/#{itype}", headers: headers
          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include("text/csv")
        end

        it "sends #{itype} template as attachment" do
          get "/api/v1/imports/template/#{itype}", headers: headers
          expect(response.headers["Content-Disposition"]).to include("attachment")
          expect(response.headers["Content-Disposition"]).to include("#{itype}_import_template.csv")
        end
      end
    end

    context "with an unknown import_type" do
      it "returns HTTP 422" do
        get "/api/v1/imports/template/bogus", headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without authentication" do
      it "returns HTTP 401" do
        get "/api/v1/imports/template/investments"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
