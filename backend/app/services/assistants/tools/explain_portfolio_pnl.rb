module Assistants
  module Tools
    # Returns a side-by-side FIFO vs weighted-average breakdown of the user's
    # portfolio P&L, plus the canonical identity that lets us reconcile with
    # any broker statement:
    #
    #   current_value − net_cash_deployed = unrealized_gain + realized_gain
    #
    # The same total holds under either cost-basis method; only the
    # unrealized↔realized split differs. FinTrack uses FIFO in the live UI
    # (matches Indian brokers / ITR conventions); WAVG is offered here as a
    # comparison only.
    class ExplainPortfolioPnl < Base
      def name; "explain_portfolio_pnl"; end

      def description
        "Explain how FinTrack computes invested / current / unrealized / realized for the user's portfolio, with FIFO and weighted-average cost-basis side-by-side. Use this whenever the user asks why their broker's numbers differ from FinTrack, or how invested vs net cash deployed work, or for a per-position reconciliation. Optionally focus on one position by passing user_instrument_id."
      end

      def input_schema
        {
          type: "object",
          properties: {
            user_instrument_id: {
              type:        "integer",
              description: "Optional. Restrict the explanation to a single position by user_instrument_id."
            }
          },
          additionalProperties: false
        }
      end

      def call(args)
        portfolio = ::Reports::PortfolioService.new(user).call
        positions = portfolio[:positions]
        ui_id     = args && (args["user_instrument_id"] || args[:user_instrument_id])
        positions = positions.select { |p| p[:user_instrument_id] == ui_id.to_i } if ui_id

        formatted = positions.map { |p| format_position(p) }

        {
          method_used_in_app: "fifo",
          identity:           "current_value − net_cash_deployed = unrealized_gain + realized_gain (holds under either cost-basis method)",
          notes: [
            "FinTrack uses FIFO in the live UI — matches what Indian brokers (Zerodha, Groww, etc.) report and what ITR / STCG-LTCG filings expect.",
            "Weighted-average is shown alongside FIFO for users who want to see the split that legacy / non-FIFO brokers might report.",
            "A broker's 'Total P&L' is usually unrealized-only (current − invested), NOT FinTrack's total_gain (unrealized + realized).",
            "Bottom-line gain (unrealized + realized) is identical under FIFO and WAVG — only the split differs."
          ],
          totals: {
            current_value:     portfolio[:current_value],
            net_cash_deployed: positions.sum { |p| p[:net_cash_deployed].to_f },
            fifo: {
              cost_basis_held: portfolio[:total_invested],
              unrealized_gain: portfolio[:unrealized_gain],
              realized_gain:   portfolio[:realized_gain],
              total_gain:      portfolio[:total_gain]
            },
            wavg: {
              cost_basis_held: positions.sum { |p| p[:wavg][:cost_basis_held].to_f },
              unrealized_gain: positions.sum { |p| p[:wavg][:unrealized_gain].to_f },
              realized_gain:   positions.sum { |p| p[:wavg][:realized_gain].to_f },
              total_gain:      positions.sum { |p| p[:wavg][:unrealized_gain].to_f + p[:wavg][:realized_gain].to_f }
            }
          },
          positions: formatted
        }
      end

      private

      def format_position(p)
        {
          user_instrument_id: p[:user_instrument_id],
          instrument_name:    p[:instrument_name],
          type:               p[:type],
          is_closed:          p[:is_closed],
          current_price:      p[:current_price],
          current_value:      p[:current_value],
          net_cash_deployed:  p[:net_cash_deployed],
          fifo: {
            cost_basis_held: p[:total_invested],
            unrealized_gain: p[:unrealized_gain],
            realized_gain:   p[:realized_gain]
          },
          wavg:           p[:wavg],
          identity_check: (p[:current_value].to_f - p[:net_cash_deployed].to_f).round(2)
        }
      end
    end
  end
end
