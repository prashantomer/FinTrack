module Imports
  # Typed error used to pass structured failure information between import
  # layers (row processor → job → controller → API). Carries a stable
  # machine-readable `code` and an optional `context` hash so higher
  # layers can branch on the cause without parsing message strings.
  #
  # Stable code names (extend as needed — keep snake_case):
  #   :amount_invalid        amount missing or non-positive
  #   :type_invalid          transaction_type not credit/debit
  #   :date_invalid          date missing / unparseable
  #   :linked_account_missing  no linked_account could be resolved
  #   :duplicate_row         row matched an existing transaction
  #   :balance_mismatch      file's running balance disagrees with computed
  #   :adapter_failure       bank-specific adapter rejected the row
  #   :file_parse_failure    workbook/CSV failed to parse
  #   :unknown               unclassified — see message for details
  #
  # Usage:
  #
  #   raise Imports::Error.new("amount must be greater than 0",
  #                            code: :amount_invalid,
  #                            context: { raw: "0" })
  #
  # Callers can inspect:
  #
  #   rescue Imports::Error => e
  #     e.code        # :amount_invalid
  #     e.context     # { raw: "0" }
  #     e.message     # human-readable
  #     e.to_h        # { code:, message:, context: }
  class Error < StandardError
    attr_reader :code, :context

    def initialize(message, code: :unknown, context: {})
      super(message)
      @code    = code.to_sym
      @context = context || {}
    end

    def to_h
      { code: code, message: message, context: context }
    end

    # Wrap a generic StandardError as an Imports::Error so the layer
    # boundary always sees the typed shape. If the source already is an
    # Imports::Error, returns it unchanged.
    def self.wrap(err, code: :unknown, context: {})
      return err if err.is_a?(Imports::Error)
      new(err.message, code: code, context: context.merge(original_class: err.class.name))
    end
  end
end
