# frozen_string_literal: true

require_relative "namespace"
require_relative "telegram_mini_app"

module ZeroXDA::Market::TelegramBot
  module TelegramMiniAppPaymentTerms
    def initialize(payment_terms: nil, **options)
      @payment_terms = payment_terms
      super(**options)
    end

    def call(environment)
      request = Rack::Request.new(environment)
      if @payment_terms && request.get? && request.path_info == "/webapp/terms"
        return terms_page(request)
      end

      super
    end

    private

    def accept(request, quote_id)
      body = request_document(request, allow_empty: true)
      document = @service.accept(
        init_data: init_data(request),
        quote_id: quote_id,
        consent: body["consent"]
      )
      post_document(201, document)
    end

    def terms_page(request)
      html = @payment_terms.html(locale: request.params["locale"])
      [
        200,
        {
          "content-type" => "text/html; charset=utf-8",
          "cache-control" => "no-store",
          "content-security-policy" => "default-src 'none'; style-src 'none'; img-src 'none'; frame-ancestors 'self' https://web.telegram.org",
          "x-content-type-options" => "nosniff",
          "content-length" => html.bytesize.to_s
        },
        [html]
      ]
    end
  end

  TelegramMiniApp.prepend(TelegramMiniAppPaymentTerms)
end
