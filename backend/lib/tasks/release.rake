require "shellwords"

# Interactive release driver. Wraps `bin/release` with prompted-and-defaulted
# inputs so the operator just types `bin/rails release` and walks through
# the wizard. Each prompt shows the suggested value in [brackets] — press
# Enter to accept.
#
# Rules enforced by the underlying script (`bin/release`):
#   • runs only against `main`
#   • working tree must be clean and in sync with `origin/main`
#   • target ref must be reachable from `main`
namespace :release do
  desc "Interactive release wizard. Prompts for version / ref / draft / schedule, then runs bin/release."
  task wizard: :environment do
    repo_root = Rails.root.parent
    script    = repo_root.join("bin/release")
    abort "✗ bin/release not found at #{script}" unless File.executable?(script)

    # ── Discover defaults ────────────────────────────────────────────────
    current_version = read_version(repo_root)
    last_tag        = Dir.chdir(repo_root) { `git tag --sort=-v:refname --list 'v*' | head -n1`.strip }
    last_version    = last_tag.sub(/\Av/, "")
    last_version    = "0.0.0" if last_version.empty?
    suggested_bump  = "patch"
    suggested_next  = bump(last_version, suggested_bump)

    branch    = Dir.chdir(repo_root) { `git rev-parse --abbrev-ref HEAD`.strip }
    head_sha  = Dir.chdir(repo_root) { `git rev-parse --short HEAD`.strip }
    head_msg  = Dir.chdir(repo_root) { `git log -1 --format=%s HEAD`.strip }

    puts ""
    puts "FinTrack release wizard"
    puts "─" * 60
    puts "  branch:           #{branch}"
    puts "  current VERSION:  #{current_version}"
    puts "  last tag:         #{last_tag.empty? ? '(none)' : last_tag}"
    puts "  HEAD:             #{head_sha} — #{head_msg}"
    puts "─" * 60

    # ── Prompt: bump kind ────────────────────────────────────────────────
    bump_kind = prompt(
      "Bump kind [patch/minor/major/explicit]",
      default: suggested_bump
    ).downcase
    bump_kind = "patch" if bump_kind.empty?

    version_flag = nil
    if bump_kind == "explicit"
      version = prompt("Exact version (e.g. v1.2.3)", default: "v#{suggested_next}")
      version = "v#{version}" unless version.start_with?("v")
      version_flag = [ "--version", version ]
    elsif %w[patch minor major].include?(bump_kind)
      version_flag = [ "--#{bump_kind}" ]
    else
      abort "✗ unknown bump kind '#{bump_kind}'."
    end

    # ── Prompt: ref ──────────────────────────────────────────────────────
    ref = prompt("Release commit (HEAD or a SHA on main)", default: "HEAD")
    ref_flag = ref == "HEAD" ? [] : [ "--ref", ref ]

    # ── Prompt: draft ────────────────────────────────────────────────────
    draft_input = prompt("Draft release? [y/N]", default: "n").downcase
    draft_flag  = %w[y yes].include?(draft_input) ? [ "--draft" ] : []

    # ── Prompt: schedule ─────────────────────────────────────────────────
    schedule_input = prompt("Schedule for a future date? [YYYY-MM-DD, blank for now]", default: "")
    at_flag        = schedule_input.empty? ? [] : [ "--at", schedule_input ]

    # ── Plan summary ─────────────────────────────────────────────────────
    target = if ref == "HEAD"
      "HEAD (#{head_sha})"
    else
      ref
    end
    puts ""
    puts "Plan"
    puts "─" * 60
    puts "  version bump:     #{bump_kind == 'explicit' ? version_flag[1] : bump_kind}  " \
         "(suggested next: #{suggested_next})"
    puts "  target:           #{target}"
    puts "  draft:            #{draft_flag.any? ? 'yes' : 'no'}"
    puts "  scheduled for:    #{at_flag.any? ? at_flag[1] : 'publish immediately'}"
    puts "─" * 60

    ok = prompt("Proceed?", default: "y").downcase
    abort "Cancelled." unless %w[y yes].include?(ok)

    # ── Invoke bin/release ───────────────────────────────────────────────
    cmd = [ script.to_s, "--yes", *version_flag, *ref_flag, *draft_flag, *at_flag ]
    puts "\n$ #{Shellwords.join(cmd)}\n"

    Dir.chdir(repo_root) do
      system(*cmd) or abort "✗ release script exited non-zero. See output above."
    end
  end

  # ── helpers ────────────────────────────────────────────────────────────

  def read_version(root)
    file = root.join("VERSION")
    return "0.0.0" unless file.exist?
    file.read.strip.then { |v| v.empty? ? "0.0.0" : v }
  end

  def bump(version, kind)
    major, minor, patch = version.split(".").map(&:to_i)
    case kind
    when "major" then "#{major + 1}.0.0"
    when "minor" then "#{major}.#{minor + 1}.0"
    else              "#{major}.#{minor}.#{patch + 1}"
    end
  end

  def prompt(question, default:)
    suffix = default.empty? ? "" : " [#{default}]"
    print "  #{question}#{suffix}: "
    input = $stdin.gets.to_s.strip
    input.empty? ? default : input
  end
end

# Aliases for ergonomics — `bin/rails release` and `bin/rails release:run`
# both invoke the wizard.
desc "Interactive release wizard (alias for release:wizard)"
task release: "release:wizard"

namespace :release do
  desc "Alias for release:wizard"
  task run: :wizard
end
