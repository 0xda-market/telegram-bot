# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/errors_reporter"
require "timeout"
require "socket"

class ErrorsReporterTest < Minitest::Test
  Reporter = ZeroXDA::Market::TelegramBot::ErrorsReporter

  def test_queues_protocol_event_with_only_explicit_context_and_bearer_outside_payload
    delivered = Queue.new
    reporter = Reporter.new(endpoint: "http://127.0.0.1:9293", token: "server-only-secret",
                            transport: ->(event) { delivered << event })
    correlation = "12345678-1234-4123-8123-123456789abc"
    assert reporter.report(error_id: "market.trading.transport.failed", message: "Trading Lab transport failed",
                           correlation_id: correlation, context: { operation: "copy_replay", elapsed_ms: 12_000 })
    event = Timeout.timeout(1) { delivered.pop }
    assert_equal "errors.v1", event[:protocol_version]
    assert_equal "0xda-market/telegram-bot", event[:project]
    assert_equal "market.trading.transport.failed", event[:error_id]
    assert_equal correlation, event[:correlation_id]
    assert_equal 12_000, event.dig(:context, :elapsed_ms)
    refute_includes JSON.generate(event), "server-only-secret"
  ensure
    reporter&.stop
  end

  def test_posts_one_events_v1_document_to_local_collector_and_reads_ack
    server = TCPServer.new("127.0.0.1", 0)
    captured = Queue.new
    receiver = Thread.new do
      socket = server.accept
      headers = []
      while (line = socket.gets) && line != "\r\n"
        headers << line.chomp
      end
      length = headers.find { |line| line.downcase.start_with?("content-length:") }.split(":", 2).last.to_i
      captured << { headers: headers, body: socket.read(length) }
      socket.write "HTTP/1.1 201 Created\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}"
      socket.close
    end
    reporter = Reporter.new(endpoint: "http://127.0.0.1:#{server.addr[1]}", token: "project-bound-test-token")
    assert reporter.report(error_id: "market.trading.upstream.unavailable",
                           message: "Trading Lab returned an unsuccessful response",
                           context: { upstream_status: 502, operation: "copy_replay" })
    request = Timeout.timeout(2) { captured.pop }
    assert_match(/\APOST \/v1\/events HTTP\/1\.1/, request[:headers].first)
    assert(request[:headers].any? { |line| line.casecmp?("authorization: Bearer project-bound-test-token") })
    body = JSON.parse(request[:body])
    assert_equal "errors.v1", body["protocol_version"]
    assert_equal "0xda-market/telegram-bot", body["project"]
    assert_equal 502, body.dig("context", "upstream_status")
    refute_includes request[:body], "project-bound-test-token"
  ensure
    reporter&.stop
    receiver&.join(1)
    receiver&.kill if receiver&.alive?
    server&.close
  end

  def test_invalid_collector_configuration_is_rejected
    assert_raises(ArgumentError) do
      Reporter.new(endpoint: "http://some-public-server.example", token: "secret")
    end
    assert_raises(ArgumentError) do
      Reporter.new(endpoint: "https://collector.example/secret/path", token: "secret")
    end
  end

  def test_reporting_failure_is_isolated_from_main_path
    observed = Queue.new
    reporter = Reporter.new(endpoint: "http://127.0.0.1:9293", token: "token",
                            transport: ->(_event) { observed << true; raise IOError, "collector down" })
    assert reporter.report(error_id: "market.trading.transport.failed", message: "Lab unavailable",
                           context: { operation: "copy_replay" })
    assert Timeout.timeout(1) { observed.pop }
  ensure
    reporter&.stop
  end
end
