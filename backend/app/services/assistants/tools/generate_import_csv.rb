require "csv"

module Assistants
  module Tools
    # Transforms an uploaded source CSV into FinTrack's importable format,
    # using a column mapping the LLM has agreed with the user. The output is
    # attached to a brand-new AssistantMessage row so the user can download it.
    class GenerateImportCsv < Base
      def name; "generate_import_csv"; end
      def description
        "Convert a previously uploaded CSV into FinTrack's import format. Provide the source attachment_id, the target import type, and a column_mapping where the keys are FinTrack columns and values are the source column names. Optionally provide value_transforms to remap values per column. Returns a new attachment_id and a preview."
      end

      def input_schema
        {
          type: "object",
          properties: {
            source_attachment_id: { type: "integer" },
            target_import_type: { type: "string", enum: %w[transactions investments term_accounts] },
            column_mapping: {
              type: "object",
              description: "FinTrack column → source column name. Example: { date: 'Trade Date', amount: 'Net Amount' }",
              additionalProperties: { type: "string" }
            },
            value_transforms: {
              type: "object",
              description: "Optional FinTrack column → mapping of source value to target value. Example: { type: { BUY: 'debit', SELL: 'credit' } }",
              additionalProperties: { type: "object", additionalProperties: { type: "string" } }
            },
            row_filter: {
              type: "object",
              description: "Optional. Keep only rows where the source `column` has one of `values` (case-insensitive). Use this to drop SELL rows when converting a broker tradebook into the investments import (FinTrack tracks holdings, not trades).",
              properties: {
                column: { type: "string", description: "Source CSV column name to test" },
                values: { type: "array", items: { type: "string" }, description: "Allow-list of acceptable values" }
              },
              required: %w[column values],
              additionalProperties: false
            }
          },
          required: %w[source_attachment_id target_import_type column_mapping],
          additionalProperties: false
        }
      end

      def call(args)
        a = stringify_keys(args)
        source_id = a["source_attachment_id"]
        target = a["target_import_type"]
        mapping = (a["column_mapping"] || {}).transform_keys(&:to_s)
        transforms = (a["value_transforms"] || {}).transform_keys(&:to_s)
        filter = a["row_filter"]

        source_msg = user.assistant_messages.find_by(id: source_id)
        return { error: "source_not_found" } unless source_msg && source_msg.file.attached?

        target_template = ::Imports::CsvTemplateService::TEMPLATES[target]
        return { error: "unknown_target", target: target } unless target_template
        target_headers = target_template[:headers]

        source_csv = CSV.parse(source_msg.file.download.force_encoding("UTF-8"), headers: true)
        total_rows = source_csv.size

        kept_rows = if filter.is_a?(Hash) && filter["column"].present?
          allowed = Array(filter["values"]).map { |v| v.to_s.downcase }
          source_csv.select { |row| allowed.include?(row[filter["column"]].to_s.strip.downcase) }
        else
          # Use `each_entry`/`map` over the CSV::Table to preserve CSV::Row objects.
          # `CSV::Table#to_a` flattens each row to a plain Array, which would make
          # string-keyed indexing fail downstream with TypeError.
          source_csv.map { |row| row }
        end
        skipped = total_rows - kept_rows.size

        out = CSV.generate(headers: true) do |csv|
          csv << target_headers
          kept_rows.each do |row|
            csv << target_headers.map { |h| transform_value(h, source_value_for(row, mapping[h]), transforms) }
          end
        end

        # Persist as a new assistant message of role=tool with the file attached
        generated = user.assistant_messages.create!(
          session_id: source_msg.session_id,
          role: "tool",
          tool_name: name,
          tool_arguments: a,
          tool_result: { row_count: kept_rows.size, skipped_rows: skipped, target_import_type: target },
          content: nil
        )
        generated.file.attach(
          io: StringIO.new(out),
          filename: generated_filename(source_msg, target),
          content_type: "text/csv"
        )

        file_url = Rails.application.routes.url_helpers.rails_blob_path(generated.file, only_path: true)

        {
          generated_attachment_id: generated.id,
          filename: generated.file.filename.to_s,
          file_url: file_url,
          row_count: kept_rows.size,
          skipped_rows: skipped,
          source_row_count: total_rows,
          target_import_type: target,
          target_headers: target_headers,
          preview: kept_rows.first(3).map { |row|
            target_headers.each_with_object({}) { |h, acc| acc[h] = transform_value(h, source_value_for(row, mapping[h]), transforms) }
          }
        }
      rescue CSV::MalformedCSVError => e
        { error: "malformed_csv", message: e.message }
      end

      private

      # Look up a source column from the CSV::Row safely. Mapping may omit some
      # target columns (the LLM commonly maps a subset), in which case the value
      # is "" — never nil-index a CSV::Row, which raises TypeError.
      def source_value_for(row, source_col)
        return "" if source_col.nil? || source_col.to_s.strip.empty?
        row[source_col.to_s]
      end

      def transform_value(target_col, source_value, transforms)
        return "" if source_value.nil?
        rule = transforms[target_col]
        return source_value.to_s unless rule.is_a?(Hash)
        rule[source_value.to_s] || source_value.to_s
      end

      def generated_filename(source_msg, target)
        base = source_msg.file.filename.to_s.sub(/\.[^.]+$/, "")
        "#{base}_#{target}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      end
    end
  end
end
