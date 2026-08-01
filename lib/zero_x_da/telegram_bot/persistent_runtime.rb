# frozen_string_literal: true

module ZeroXDA
  module TelegramBot
    # Runtime policy for the continuously running VPS workload.
    #
    # A slow upstream call is not a server cold start. Keep command execution
    # synchronous and let the normal result or error path describe the outcome.
    module PersistentRuntime
      private

      def with_server_start_notice(_message)
        yield
      end
    end
  end
end
