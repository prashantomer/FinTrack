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

      def create
        file = params[:file]
        return render_error(message: "file is required") unless file.present?
        unless file.content_type&.include?("csv") || file.original_filename.to_s.end_with?(".csv")
          return render_error(message: "File must be a CSV")
        end
        if file.size > 5.megabytes
          return render_error(message: "File too large (max 5 MB)")
        end

        import_type = params[:import_type].to_s.strip
        unless ImportBatch.import_types.key?(import_type)
          return render_error(message: "import_type \"#{import_type}\" is not supported")
        end

        raw_csv = file.read.force_encoding("UTF-8")

        batch = current_user.import_batches.create!(
          import_type: import_type,
          file_name:   file.original_filename,
          raw_csv:     raw_csv
        )

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
    end
  end
end
