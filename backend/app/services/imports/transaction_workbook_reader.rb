require "roo"
require "roo-xls"

module Imports
  # Reads an .xls / .xlsx transaction statement and yields one normalized row
  # hash at a time. The header row is auto-located by scanning for a known
  # marker ("S No.", "Sl No.", "Date"); rows above it are statement metadata
  # (account number, period, filters) and rows below it are data.
  #
  # Continuation rows — where the bank export wraps a long remark onto a
  # second sheet row with the S No. column blank — are merged into the
  # previous data row's remarks before yielding.
  #
  # Yields each row as { col_name_sym => value, ... } using the literal header
  # text from the sheet so downstream adapters can read by column name. Also
  # exposes `meta` (account number, statement period, etc.) extracted from the
  # rows preceding the header.
  class TransactionWorkbookReader
    HEADER_MARKERS = [ "S No.", "Sl No.", "Sl. No.", "Sr No.", "Sr. No.", "S.No." ].map(&:downcase).freeze
    FOOTER_MARKERS = [ "LEGENDS", "Legends:", "Note:" ].freeze
    ACCOUNT_NUMBER_LABELS = [ "Account Number", "Account No", "A/c No" ].map(&:downcase).freeze

    Row = Struct.new(:cells, :sheet_row, keyword_init: true) do
      def [](key) = cells[key]
      def to_h    = cells.dup
    end

    attr_reader :path, :meta

    def initialize(path:)
      @path = path
      @sheet = Roo::Spreadsheet.open(path.to_s)
      @meta  = {}
      detect_layout!
    end

    # Yields a Row for each data row (after merging continuations and skipping
    # blank / non-data rows). Bare `to_a` works too.
    def each_row(&block)
      return enum_for(:each_row) unless block_given?

      current = nil
      ((@header_row + 1)..@sheet.last_row).each do |i|
        cells = row_cells(i)
        break if footer?(cells)

        if data_row?(cells)
          yield current if current
          current = Row.new(cells: cells, sheet_row: i)
        elsif continuation?(cells) && current
          current.cells[remarks_key] = [ current.cells[remarks_key], cells[remarks_key] ].compact.join(" ").strip
        end
      end
      yield current if current
    end

    # Headers as the adapter sees them (literal sheet text, downcased + symbol).
    def headers
      @header_symbols
    end

    private

    # Resolve the header row, column key array, and pre-header metadata in one
    # pass. The structure (a few label/value rows + the data table) is stable
    # across all bank Excel exports we've seen — ICICI, HDFC, Axis follow it.
    def detect_layout!
      (1..@sheet.last_row).each do |i|
        row = (1..@sheet.last_column).map { |c| @sheet.cell(i, c).to_s.strip }
        first_nonblank = row.find { |v| !v.empty? }
        marker_hit = row.any? { |v| HEADER_MARKERS.include?(v.downcase) }

        if marker_hit
          @header_row     = i
          @header_columns = (1..@sheet.last_column).map { |c| @sheet.cell(i, c).to_s.strip }
          @header_symbols = @header_columns.map { |h| h.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_|_$/, "").to_sym }
          break
        end

        next unless first_nonblank
        capture_meta(row) unless @header_row
      end

      raise "Could not locate header row in #{File.basename(@path)} (looked for any of: #{HEADER_MARKERS.join(', ')})" unless @header_row
    end

    def capture_meta(row)
      # Banks lay out metadata as `[ "Account Number", "", "144... PRASHANT OMER" ]`.
      # Pair adjacent non-blank cells as label -> value.
      compact = row.each_with_index.select { |v, _| !v.empty? }
      return if compact.empty?
      label = compact.first[0]
      value = compact[1]&.dig(0)
      return unless label && value

      key = label.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_|_$/, "").to_sym
      @meta[key] ||= value
    end

    def row_cells(i)
      values = (1..@sheet.last_column).map { |c| @sheet.cell(i, c) }
      @header_symbols.zip(values).to_h
    end

    def data_row?(cells)
      sno = cells[sno_key]
      sno && sno.to_s.strip.match?(/\A\d+\z/)
    end

    def continuation?(cells)
      cells.values.any? { |v| !v.to_s.strip.empty? }
    end

    def footer?(cells)
      first_value = cells.values.map(&:to_s).find { |v| !v.strip.empty? }
      return false unless first_value
      FOOTER_MARKERS.any? { |m| first_value.start_with?(m) }
    end

    def sno_key
      @sno_key ||= @header_symbols.find { |s| s.to_s.match?(/\A(s|sl|sr|serial|sno|slno|srno)(_no)?\z/i) } || @header_symbols.first
    end

    def remarks_key
      @remarks_key ||= @header_symbols.find { |s| s.to_s.include?("remark") || s.to_s.include?("narration") || s.to_s.include?("description") } || @header_symbols[4]
    end
  end
end
