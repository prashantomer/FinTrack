module Assistants
  # Central registry of tools the LLM can call.
  # Each tool exposes a JSON Schema (for the LLM) and an execute step.
  module ToolRegistry
    module_function

    def all_for(user)
      [
        Tools::QueryDashboard.new(user),
        Tools::QueryTransactions.new(user),
        Tools::QueryTermAccounts.new(user),
        Tools::QueryAccounts.new(user),
        Tools::QueryInvestments.new(user),
        Tools::AnalyseCsv.new(user),
        Tools::GenerateImportCsv.new(user)
      ]
    end

    def find(user, name)
      all_for(user).find { |t| t.name == name.to_s }
    end

    # JSON-schema definitions in a provider-neutral shape.
    # Anthropic / OpenAI both accept { name, description, input_schema } variants.
    def definitions_for(user)
      all_for(user).map(&:definition)
    end
  end
end
