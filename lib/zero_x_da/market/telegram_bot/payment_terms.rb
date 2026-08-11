# frozen_string_literal: true

require_relative "namespace"

require "cgi"
require "digest"
require "time"
require_relative "locale"

module ZeroXDA::Market::TelegramBot
  class PaymentTerms
    VERSION = "20260811v1"
    VERSION_PATTERN = /\A[A-Za-z0-9_-]{1,24}\z/

    COPY = {
      "en_US" => {
        title: "0xda-market Purchase Terms",
        prompt: "Before paying, read the Purchase Terms. Choose ‘I read & agree’ only if you accept them.",
        view: "View Terms",
        agree: "I read & agree",
        command: "Purchase terms",
        body: <<~TEXT.strip
          0xda-market Purchase Terms — version #{VERSION}

          1. Products. 0xda-market offers digital products through Telegram. The exact product, recipient and price are shown before payment.

          2. Payment. Digital purchases inside Telegram are paid only with Telegram Stars (XTR). By pressing “I read & agree” you confirm that you have read and accepted these terms before an invoice is created.

          3. Fulfillment. Delivery starts only after Telegram reports a successful payment and 0xda-market verifies the matching order. If a paid order cannot be fulfilled, 0xda-market may return the Stars through Telegram’s refund mechanism.

          4. Recipient. You are responsible for selecting the intended Telegram recipient and reviewing the order before payment. Product eligibility is checked by 0xda-market where provider information allows it.

          5. Support and disputes. For any purchase problem use /paysupport. Purchase disputes are handled by 0xda-market; Telegram is not the seller and does not resolve merchant purchase disputes for us.

          6. Records. 0xda-market keeps the minimum order, payment and fulfillment records required for reconciliation, support, fraud prevention and refunds.

          Do not pay unless the displayed product, recipient, Stars amount and these terms are acceptable to you.
        TEXT
      },
      "uk_UA" => {
        title: "Умови покупки 0xda-market",
        prompt: "Перед оплатою прочитайте Умови покупки. Натискайте «Прочитав(-ла) і погоджуюсь» лише якщо приймаєте їх.",
        view: "Переглянути умови",
        agree: "Прочитав(-ла) і погоджуюсь",
        command: "Умови покупки",
        body: <<~TEXT.strip
          Умови покупки 0xda-market — версія #{VERSION}

          1. Продукти. 0xda-market пропонує цифрові продукти через Telegram. Точний продукт, одержувач і ціна показуються до оплати.

          2. Оплата. Цифрові покупки всередині Telegram оплачуються лише Telegram Stars (XTR). Натискаючи «Прочитав(-ла) і погоджуюсь», ви підтверджуєте, що прочитали та прийняли ці умови до створення інвойсу.

          3. Виконання. Доставка починається лише після того, як Telegram повідомить про успішну оплату, а 0xda-market перевірить відповідне замовлення. Якщо оплачене замовлення неможливо виконати, 0xda-market може повернути Stars через механізм повернення Telegram.

          4. Одержувач. Ви відповідаєте за вибір потрібного Telegram-одержувача та перевірку замовлення до оплати. 0xda-market перевіряє придатність продукту там, де це дозволяють дані провайдера.

          5. Підтримка та спори. З будь-якою проблемою щодо покупки використовуйте /paysupport. Спори щодо покупки вирішує 0xda-market; Telegram не є продавцем і не вирішує за нас спори щодо покупок у продавця.

          6. Записи. 0xda-market зберігає мінімально необхідні записи про замовлення, оплату та виконання для звірки, підтримки, запобігання шахрайству та повернень.

          Не оплачуйте, якщо вас не влаштовують показані продукт, одержувач, сума Stars або ці умови.
        TEXT
      },
      "ru_RU" => {
        title: "Условия покупки 0xda-market",
        prompt: "Перед оплатой прочитайте Условия покупки. Нажимайте «Прочитал(-а) и согласен(-на)» только если принимаете их.",
        view: "Открыть условия",
        agree: "Прочитал(-а) и согласен(-на)",
        command: "Условия покупки",
        body: <<~TEXT.strip
          Условия покупки 0xda-market — версия #{VERSION}

          1. Продукты. 0xda-market предлагает цифровые продукты через Telegram. Точный продукт, получатель и цена показываются до оплаты.

          2. Оплата. Цифровые покупки внутри Telegram оплачиваются только Telegram Stars (XTR). Нажимая «Прочитал(-а) и согласен(-на)», вы подтверждаете, что прочитали и приняли эти условия до создания инвойса.

          3. Исполнение. Доставка начинается только после того, как Telegram сообщит об успешной оплате, а 0xda-market проверит соответствующий заказ. Если оплаченный заказ невозможно выполнить, 0xda-market может вернуть Stars через механизм возврата Telegram.

          4. Получатель. Вы отвечаете за выбор нужного Telegram-получателя и проверку заказа до оплаты. 0xda-market проверяет допустимость продукта там, где это позволяют данные провайдера.

          5. Поддержка и споры. С любой проблемой по покупке используйте /paysupport. Споры по покупке решает 0xda-market; Telegram не является продавцом и не решает за нас споры по покупкам у продавца.

          6. Записи. 0xda-market хранит минимально необходимые записи о заказе, оплате и исполнении для сверки, поддержки, предотвращения мошенничества и возвратов.

          Не оплачивайте, если вас не устраивают показанные продукт, получатель, сумма Stars или эти условия.
        TEXT
      }
    }.freeze

    attr_reader :version

    def initialize(public_url:, clock: -> { Time.now.utc })
      @public_url = public_url.to_s.delete_suffix("/")
      raise ArgumentError, "public_url must use HTTPS" unless @public_url.start_with?("https://")

      @clock = clock
      @version = VERSION
    end

    def metadata(locale:)
      copy = localized(locale)
      {
        "version" => @version,
        "sha256" => digest(locale: locale),
        "url" => url(locale: locale),
        "title" => copy.fetch(:title),
        "prompt" => copy.fetch(:prompt),
        "view_label" => copy.fetch(:view),
        "agree_label" => copy.fetch(:agree)
      }.freeze
    end

    def text(locale:)
      localized(locale).fetch(:body)
    end

    def command_description(locale:)
      localized(locale).fetch(:command)
    end

    def url(locale:)
      code = Locale.normalize(locale)
      "#{@public_url}/webapp/terms?locale=#{CGI.escape(code)}"
    end

    def digest(locale:)
      Digest::SHA256.hexdigest(text(locale: locale))
    end

    # Converts an explicit, authenticated client attestation into a server-
    # timestamped proof. The proof is later embedded in the signed invoice
    # payload, so a successful payment can be reconciled to the exact terms.
    def accept(client_consent:, telegram_user_id:, locale:)
      consent = client_consent
      unless consent.is_a?(Hash) && consent["accepted"] == true && consent["version"].to_s == @version
        raise ArgumentError, "current purchase terms must be accepted before payment"
      end

      now = current_time
      {
        "accepted" => true,
        "terms_version" => @version,
        "terms_sha256" => digest(locale: locale),
        "accepted_at" => now.iso8601(6),
        "telegram_user_id" => telegram_user_id.to_s,
        "locale" => Locale.normalize(locale)
      }.freeze
    end

    def server_accept(telegram_user_id:, locale:)
      accept(
        client_consent: { "accepted" => true, "version" => @version },
        telegram_user_id: telegram_user_id,
        locale: locale
      )
    end

    def html(locale:)
      copy = localized(locale)
      paragraphs = copy.fetch(:body).split("\n\n").map do |paragraph|
        "<p>#{CGI.escapeHTML(paragraph).gsub("\n", "<br>")}</p>"
      end.join
      <<~HTML
        <!doctype html>
        <html lang="#{CGI.escapeHTML(Locale.normalize(locale).tr("_", "-"))}">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <meta name="color-scheme" content="light dark">
          <title>#{CGI.escapeHTML(copy.fetch(:title))}</title>
        </head>
        <body>
          <main>
            <h1>#{CGI.escapeHTML(copy.fetch(:title))}</h1>
            #{paragraphs}
          </main>
        </body>
        </html>
      HTML
    end

    private

    def localized(locale)
      COPY.fetch(Locale.normalize(locale), COPY.fetch("en_US"))
    end

    def current_time
      value = @clock.call
      raise ArgumentError, "clock must return a Time" unless value.is_a?(Time)

      value.utc
    end
  end
end
