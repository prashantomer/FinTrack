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

        source_msg = user.assistant_messages.find_by(id: source_id)
        return { error: "source_not_found" } unless source_msg && source_msg.file.attached?

        target_template = ::Imports::CsvTemplateService::TEMPLATES[target]
        return { error: "unknown_target", target: target } unless target_template
        target_headers = target_template[:headers]

        source_csv = CSV.parse(source_msg.file.download.force_encoding("UTF-8"), headers: true)

        out = CSV.generate(headers: true) do |csv|
          csv << target_headers
          source_csv.each do |row|
            csv << target_headers.map { |h| transform_value(h, row[mapping[h]], transforms) }
          end
        end

        # Persist as a new assistant message of role=tool with the file attached
        generated = user.assistant_messages.create!(
          session_id: source_msg.session_id,
          role: "tool",
          tool_name: name,
          tool_arguments: a,
          tool_result: { row_count: source_csv.size, target_import_type: target },
          content: nil
        )
        generated.file.attach(
          io: StringIO.new(out),
          filename: generated_filename(source_msg, target),
          content_type: "text/csv"
        )

        {
          generated_attachment_id: generated.id,
          filename: generated.file.filename.to_s,
          row_count: source_csv.size,
          target_import_type: target,
          target_headers: target_headers,
          preview: source_csv.first(3).map { |row|
            target_headers.each_with_object({}) { |h, acc| acc[h] = transform_value(h, row[mapping[h]], transforms) }
          }
        }
      rescue CSV::MalformedCSVError => e
        { error: "malformed_csv", message: e.message }
      end

      private

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
