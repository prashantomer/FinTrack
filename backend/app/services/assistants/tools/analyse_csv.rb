require "csv"

module Assistants
  module Tools
    class AnalyseCsv < Base
      MAX_ROWS_TO_SHOW = 5

      def name; "analyse_csv"; end
      def description
        "Inspect an uploaded CSV file. Returns the column names and a sample of the first few rows so you can propose how to map source columns onto FinTrack's import format."
      end
      def input_schema
        {
          type: "object",
          properties: {
            attachment_id: { type: "integer", description: "AssistantMessage id with an attached file" },
            target_import_type: { type: "string", enum: %w[transactions investments term_accounts], description: "Which FinTrack import format you intend to convert this into" }
          },
          required: %w[attachment_id target_import_type],
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        attachment_id = a["attachment_id"]
        target = a["target_import_type"]

        msg = user.assistant_messages.find_by(id: attachment_id)
        return { error: "attachment_not_found" } unless msg && msg.file.attached?

        csv_text = msg.file.download.force_encoding("UTF-8")
        rows = CSV.parse(csv_text, headers: true)
        sample = rows.first(MAX_ROWS_TO_SHOW).map(&:to_h)

        target_headers = ::Imports::CsvTemplateService::TEMPLATES.dig(target, :headers) || []

        {
          attachment_id: attachment_id,
          filename: msg.file.filename.to_s,
          target_import_type: target,
          target_headers: target_headers,
          source_columns: rows.headers,
          source_row_count: rows.size,
          sample_rows: sample
        }
      rescue CSV::MalformedCSVError => e
        { error: "malformed_csv", message: e.message }
      end
    end
  end
end
