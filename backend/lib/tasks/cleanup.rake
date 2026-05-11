require "io/console"

# Thin rake wrapper around `Cleanup::PreviewService` + `Cleanup::ExecuteService`
# so the same logic the UI uses is reachable from the terminal. Useful for
# automation, batched maintenance, and dummy-user resets where the wizard
# UI would be overkill.
#
# Configurability — every wizard field is reachable via ENV:
#   EMAIL=...              required
#   SECTORS=transactions,investments,...   default: all
#   DATE_FROM=2024-01-01   optional
#   DATE_TO=2024-12-31     optional
#   SOURCE=manual|imported optional
#   ACCOUNT_IDS=1,2        optional (transactions/account scoping)
#   ACTIVE=1|0             optional (transactions only)
#   TAGS_ANY=salary,rent   optional (transactions only)
#   RESET_BALANCES=1       optional — set account/ppf balances to 0 after wipe
#   FAST=1                 skip the final "Type DELETE to confirm" prompt
namespace :cleanup do
  desc "Preview a cleanup config against a user. Prints counts + samples; deletes nothing."
  task preview: :environment do
    user, config = resolve_cleanup_args!
    print_preview(Cleanup::PreviewService.new(user, config).call)
  end

  desc "Execute a cleanup. Prints the preview first, then asks for the literal " \
       "string 'DELETE' to confirm. Same services back the UI wizard."
  task run: :environment do
    user, config = resolve_cleanup_args!

    preview = Cleanup::PreviewService.new(user, config).call
    print_preview(preview)

    if preview[:total].zero?
      puts "\nNothing matches the given config — exiting."
      next
    end

    unless ENV["FAST"] == "1"
      print "\nType DELETE to confirm (anything else cancels): "
      input = $stdin.gets.to_s.strip
      unless input == "DELETE"
        puts "Cancelled."
        next
      end
    end

    result = Cleanup::ExecuteService.new(user, config).call
    puts "\nDone. Deleted #{result[:total]} records."
    result[:deleted].each { |sector, n| puts "  #{sector.ljust(20)} #{n}" if n.positive? }
  end

  # ── Shared helpers ─────────────────────────────────────────────────────

  def resolve_cleanup_args!
    email = ENV["EMAIL"].to_s.strip
    abort "EMAIL=<user-email> is required." if email.empty?

    user = User.find_by(email: email) or abort "No user with email '#{email}'."

    sectors = (ENV["SECTORS"] || Cleanup::ScopeBuilder::SECTORS.join(",")).split(",").map(&:strip).reject(&:empty?)

    config = {
      "sectors"        => sectors,
      "date_from"      => ENV["DATE_FROM"],
      "date_to"        => ENV["DATE_TO"],
      "source"         => ENV["SOURCE"],
      "account_ids"    => ENV["ACCOUNT_IDS"].to_s.split(",").map(&:strip).map(&:to_i).reject(&:zero?),
      "active"         => ([ "1", "true" ].include?(ENV["ACTIVE"].to_s) ? true :
                           [ "0", "false" ].include?(ENV["ACTIVE"].to_s) ? false : nil),
      "tags_any"       => ENV["TAGS_ANY"].to_s.split(",").map(&:strip).reject(&:empty?),
      "reset_balances" => ENV["RESET_BALANCES"] == "1"
    }
    [ user, config ]
  end

  def print_preview(preview)
    puts ""
    puts "Cleanup preview (before → −delete = after)"
    puts "-" * 60
    preview[:sectors].each do |s|
      puts sprintf("  %-20s %5d → -%-5d = %5d", s[:sector], s[:before], s[:to_delete], s[:after])
      s[:samples].first(3).each { |line| puts "      • #{line}" }
    end
    puts "-" * 60
    puts sprintf("  %-20s          -%d", "total to delete", preview[:total])

    if preview[:balance_reset]&.any?
      puts ""
      puts "Balance reset (would zero these out):"
      preview[:balance_reset].each do |b|
        puts sprintf("  %-30s %12.2f → %.2f", b[:nickname], b[:before], b[:after])
      end
    end
  end
end
