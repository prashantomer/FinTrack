require "io/console"

# Admin/emergency configuration for a single user's assistant settings. The
# normal flow is for users to configure themselves in the UI; these tasks are
# for headless setup (CI seed, support, demo).
namespace :assistant do
  module AssistantRakeIO
    module_function

    def prompt(text, default: nil)
      suffix = default ? " [#{default}]" : ""
      print "#{text}#{suffix}: "
      input = $stdin.gets&.strip
      input.nil? || input.empty? ? default.to_s : input
    end

    def prompt_password(text)
      print "#{text}: "
      pw = $stdin.noecho(&:gets)&.chomp
      puts ""
      pw
    end
  end

  desc "Configure a user's AI provider (interactive). Usage: bin/rails 'assistant:configure[email@example.com]'"
  task :configure, [ :email ] => :environment do |_, args|
    email = args[:email] || AssistantRakeIO.prompt("User email")
    user = User.find_by(email: email)
    abort "Error: no user with email '#{email}'" unless user

    setting = user.assistant_setting || user.create_assistant_setting!

    puts "\nProviders: 1=anthropic, 2=openai, 3=ollama"
    choice = AssistantRakeIO.prompt("Select [1-3]", default: "1")
    provider = { "1" => "anthropic", "2" => "openai", "3" => "ollama" }[choice.strip]
    abort "Invalid choice" unless provider

    default_model = UserAssistantSetting::DEFAULT_MODEL_BY_PROVIDER[provider]
    default_url   = UserAssistantSetting::DEFAULT_BASE_URL_BY_PROVIDER[provider]

    model    = AssistantRakeIO.prompt("Model", default: default_model)
    base_url = AssistantRakeIO.prompt("Base URL", default: default_url)
    api_key = if provider == "ollama"
      nil
    else
      AssistantRakeIO.prompt_password("API key (input hidden)")
    end

    setting.update!(provider: provider, model: model.presence, base_url: base_url.presence, api_key: api_key.presence)

    puts "\nValidating with a test call…"
    begin
      ms = Assistants::Provider.for(setting).ping
      setting.record_test_result(:ok, latency_ms: ms)
      puts "  OK (latency: #{ms}ms)"
    rescue Assistants::Errors::ProviderError => e
      setting.record_test_result(:error, error: e.message)
      puts "  FAILED: #{e.class.name.demodulize} — #{e.message}"
    end
  end

  desc "Show a user's AI assistant configuration. Usage: bin/rails 'assistant:status[email@example.com]'"
  task :status, [ :email ] => :environment do |_, args|
    email = args[:email] || AssistantRakeIO.prompt("User email")
    user = User.find_by(email: email)
    abort "Error: no user with email '#{email}'" unless user

    setting = user.assistant_setting
    if setting.nil? || !setting.configured?
      puts "#{email} — not configured (will fall back to local Ollama)"
      next
    end

    puts "#{email} — provider=#{setting.provider} model=#{setting.effective_model} base_url=#{setting.effective_base_url}"
    puts "  api_key: #{setting.api_key_tail || '(not set)'}"
    puts "  daily_limit: #{setting.daily_limit}"
    if setting.last_tested_at
      puts "  last test: #{setting.last_test_status} at #{setting.last_tested_at}"
      puts "  last error: #{setting.last_test_error}" if setting.last_test_error.present?
    end

    print "  Pinging now… "
    begin
      ms = Assistants::Provider.for(setting).ping
      puts "OK (#{ms}ms)"
    rescue Assistants::Errors::ProviderError => e
      puts "FAILED: #{e.class.name.demodulize} — #{e.message}"
    end
  end
end
