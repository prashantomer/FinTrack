module Api
  module V1
    class ImportsController < ApplicationController
      before_action :set_batch, only: [ :show ]

      def index
        page_size = 20
        page      = [ (params[:page] || 1).to_i, 1 ].max
        offset    = (page - 1) * page_size

        scope = current_user.import_batches.order(created_at: :desc)
        total = scope.count
        items = scope.includes(:import_records).offset(offset).limit(page_size)

        render_success(
          data:      items,
          meta_data: { total: total, page: page, page_size: page_size }
        )
      end

      def show
        render_success(data: @batch)
      end

      # POST /api/v1/imports/:id/resolve
      # Body: { action: "adjust" | "abort" }
      # Resolves a batch in `needs_reconciliation` status. "adjust" creates a
      # balancing transaction to bring the account to expected_balance;
      # "abort" rolls the entire batch back.
      def resolve
        batch = current_user.import_batches.find(params[:id])
        unless batch.needs_reconciliation?
          return render_error(message: "Batch is not awaiting reconciliation (status: #{batch.status})")
        end

        case params[:action_choice].to_s
        when "adjust"
          account = batch.linked_account_type.safe_constantize.find(batch.linked_account_id)
          Accounts::AdjustBalanceService.new(
            current_user, account,
            target_balance: batch.expected_balance,
            date:           Date.current,
            description:    "Import reconciliation (batch ##{batch.id})"
          ).call
          batch.update!(status: :completed)
          render_success(data: batch.reload)
        when "abort"
          Imports::AbortBatchService.new(batch).call
          render_success(data: batch.reload)
        else
          render_error(message: "action_choice must be 'adjust' or 'abort'")
        end
      rescue Accounts::AdjustBalanceService::Error => e
        render_error(message: e.message)
      end

      def create
        file = params[:file]
        return render_error(message: "file is required") unless file.present?

        ext = File.extname(file.original_filename.to_s).downcase
        unless [ ".csv", ".xls", ".xlsx" ].include?(ext)
          return render_error(message: "File must be CSV, XLS, or XLSX")
        end

        if file.size > 5.megabytes
          return render_error(message: "File too large (max 5 MB)")
        end

        import_type = params[:import_type].to_s.strip
        unless ImportBatch.import_types.key?(import_type)
          return render_error(message: "import_type \"#{import_type}\" is not supported")
        end

        # Bank-statement Excel imports (ICICI, etc.) don't carry per-row
        # account info — the user picks the target account at upload time.
        linked_type, linked_id = resolve_linked_account_param

        # User's reconciliation policy. Accept the canonical values from the
        # ImportBatch enum (`ask`/`adjust`/`fail`); fall back to the default
        # ("ask") when missing or invalid so the model stays consistent.
        reconcile = params[:on_balance_mismatch].to_s.presence
        reconcile = "ask" unless %w[ask adjust fail].include?(reconcile)

        batch = current_user.import_batches.new(
          import_type:         import_type,
          file_name:           file.original_filename,
          linked_account_type: linked_type,
          linked_account_id:   linked_id,
          on_balance_mismatch: reconcile
        )
        batch.file.attach(file)
        batch.save!

        job_class = {
          "investments"  => Imports::ProcessInvestmentCsvJob,
          "transactions" => Imports::ProcessTransactionCsvJob,
          "term_accounts"=> Imports::ProcessTermAccountCsvJob
        }.fetch(import_type)

        job = job_class.perform_later(batch.id)
        batch.update_column(:sidekiq_job_id, job.provider_job_id)

        render_created(data: batch)
      end

      def template
        import_type = params[:import_type].to_s
        unless ImportBatch.import_types.key?(import_type)
          return render_error(message: "Unknown import type")
        end

        csv = Imports::CsvTemplateService.new.call(import_type)
        send_data csv,
                  filename:    "#{import_type}_import_template.csv",
                  type:        "text/csv",
                  disposition: "attachment"
      end

      private

      def set_batch
        @batch = current_user.import_batches.includes(:import_records).find(params[:id])
      end

      # Accepts either:
      #   linked_account_type=Account, linked_account_id=<id>
      # or the polymorphic shorthand used by the transaction form:
      #   linked_account=account:<id> | term_account:<id>
      # Returns [ nil, nil ] when not supplied.
      def resolve_linked_account_param
        combined = params[:linked_account].to_s.presence
        if combined&.include?(":")
          kind, id = combined.split(":", 2)
          return [ kind.classify, id.to_i ]
        end

        kind = params[:linked_account_type].to_s.presence
        id   = params[:linked_account_id].to_s.presence
        return [ nil, nil ] unless kind && id
        [ kind.classify, id.to_i ]
      end
    end
  end
end
