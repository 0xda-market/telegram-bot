# frozen_string_literal: true

require_relative "namespace"

module ZeroXDA::Market::TelegramBot
  # Runtime policy for the continuously running VPS workload.
  #
  # A slow upstream call is not a server cold start. The VPS bot must use the
  # normal command result or error path and must never emit a startup notice.
  module PersistentRuntime
    private

    def with_server_start_notice(_message)
      yield
    end
  end
end

ZeroXDA::Market::TelegramBot::Bot.prepend(
  ZeroXDA::Market::TelegramBot::PersistentRuntime
)
