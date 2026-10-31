# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "zero_x_da/market/telegram_bot/nilx_identity_api"

class NilxIdentityAPITest < Minitest::Test
  API = ZeroXDA::Market::TelegramBot::NilxIdentityAPI
  TOKEN = "partner-lookup-token-at-least-32-bytes"

  def test_asks_about_the_telegram_account_with_the_partner_token
    seen = nil
    api = api(lambda do |uri, token, body|
      seen = [uri.to_s, token, JSON.parse(body)]
      [200, JSON.generate("state" => "linked", "pub_dress" => "zero", "seeds" => 9360,
                          "special" => { "held" => true, "ends_at_ms" => 1_793_448_000_000 },
                          "special_purchase_open" => false)]
    end)
    account = api.telegram_account(77)
    assert_equal ["https://identity.example/api/v1/partner/provider-account", TOKEN,
                  { "provider" => "telegram", "subject" => "77" }], seen
    assert account.linked?
    assert_equal ["zero", 9360, true, false], [account.pub_dress, account.seeds, account.special_held, account.purchase_open]
    assert_equal Time.at(1_793_448_000, in: "UTC"), account.special_ends_at
  end

  def test_an_unlinked_account_carries_its_link_refusal
    account = api(->(*) { [200, '{"state":"sign_in_required","provider":"telegram","link_refusal":"provider_type_already_linked"}'] })
              .telegram_account(77)
    refute account.linked?
    assert_equal "provider_type_already_linked", account.link_refusal
  end

  def test_anything_but_a_well_formed_answer_is_unavailable_never_unlinked
    [
      ->(*) { [503, '{"error":"unavailable"}'] },
      ->(*) { [200, "not json"] },
      ->(*) { [200, '{"state":"linked","pub_dress":"zero","seeds":-1,"special_purchase_open":true}'] },
      ->(*) { [200, '{"state":"maybe"}'] },
      ->(*) { raise IOError, "reset" }
    ].each do |answer|
      assert_raises(API::Error) { api(answer).telegram_account(77) }
    end
  end

  def test_refuses_a_weak_token_or_plain_http
    assert_raises(ArgumentError) { API.new(base_url: "https://identity.example", token: "short") }
    assert_raises(ArgumentError) { API.new(base_url: "http://identity.example", token: TOKEN) }
  end

  private

  def api(http)
    API.new(base_url: "https://identity.example", token: TOKEN, http: http)
  end
end
