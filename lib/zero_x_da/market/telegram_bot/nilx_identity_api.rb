# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "namespace"

require "json"
require "net/http"
require "timeout"
require "uri"

module ZeroXDA::Market::TelegramBot
  # 0x1 Identity's partner surface, as the bot needs it for Special. The bot
  # asks about the Telegram account that sent the update. It never learns an
  # internal Bond identifier and never debits or grants anything here.
  class NilxIdentityAPI
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    STATES = %w[linked sign_in_required].freeze

    class Error < StandardError; end

    # One Telegram account, as 0x1 Identity sees it.
    Account = Data.define(:state, :pub_dress, :seeds, :special_held, :special_ends_at, :purchase_open,
                          :link_refusal) do
      def linked? = state == "linked"
    end

    def initialize(base_url:, token:, http: nil)
      raise ArgumentError, "0x1 partner token must be at least 32 bytes" if token.to_s.bytesize < 32

      @uri = URI.join("#{base_url.delete_suffix("/")}/", "api/v1/partner/provider-account")
      raise ArgumentError, "0x1 Identity URL must use HTTPS" unless @uri.scheme == "https" || @uri.host == "localhost"

      @token = token
      @http = http || method(:perform)
    end

    # Raises Error when Identity cannot answer: that is never "not linked".
    def telegram_account(telegram_user_id)
      status, body = @http.call(@uri, @token, JSON.generate(provider: "telegram", subject: telegram_user_id.to_s))
      raise Error, "0x1 Identity answered #{status}" unless status == 200

      parse(JSON.parse(body))
    rescue JSON::ParserError, KeyError, TypeError, IOError, SystemCallError, Timeout::Error => error
      raise Error, "0x1 Identity is unavailable: #{error.class}"
    end

    private

    def parse(document)
      state = document.fetch("state")
      raise Error, "unknown 0x1 account state" unless STATES.include?(state)
      return unlinked(document) unless state == "linked"

      seeds = document.fetch("seeds")
      open = document.fetch("special_purchase_open")
      raise Error, "malformed 0x1 account" unless seeds.is_a?(Integer) && seeds >= 0 && [true, false].include?(open)

      ends_at = document.dig("special", "ends_at_ms")
      Account.new(
        state: state, pub_dress: document.fetch("pub_dress").to_s, seeds: seeds,
        special_held: document.dig("special", "held") == true,
        special_ends_at: ends_at.is_a?(Integer) ? Time.at(ends_at / 1000, in: "UTC") : nil,
        purchase_open: open, link_refusal: nil
      )
    end

    def unlinked(document)
      refusal = document["link_refusal"]
      Account.new(state: "sign_in_required", pub_dress: nil, seeds: nil, special_held: false, special_ends_at: nil,
                  purchase_open: false, link_refusal: refusal.is_a?(String) ? refusal : nil)
    end

    def perform(uri, token, body)
      request = Net::HTTP::Post.new(uri)
      request["authorization"] = "Bearer #{token}"
      request["content-type"] = "application/json"
      request.body = body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
      [response.code.to_i, response.body.to_s]
    end
  end
end
