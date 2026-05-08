module Assistants
  module Errors
    class ProviderError < StandardError
      attr_reader :provider, :code

      def initialize(message, provider: nil, code: nil)
        super(message)
        @provider = provider
        @code = code
      end
    end

    class ProviderUnreachable    < ProviderError; end
    class AuthenticationError    < ProviderError; end
    class RateLimitError         < ProviderError; end
    class InvalidRequest         < ProviderError; end
    class NotConfigured          < ProviderError; end
  end
end
