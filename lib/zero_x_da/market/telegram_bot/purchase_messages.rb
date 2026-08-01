# frozen_string_literal: true

require_relative "namespace"

require_relative "locale"
require_relative "timestamp_formatter"

module ZeroXDA::Market::TelegramBot
    module PurchaseMessages
      COPY = {
        "en_US" => {
          quote_title: "Purchase quote",
          product: "Product",
          price: "Price",
          expires: "Valid until",
          accept: "Accept purchase",
          unpriced: "This product has no active price yet.",
          pending: "Request accepted ✅\nWe are already working on it.",
          claimed: "Request accepted ✅\nAn operator is already working on it.",
          refresh: "Refresh status",
          refresh_hint: "You can return later and use this button to read the durable order state.",
          succeeded: "Purchase completed ✅",
          failed: "Purchase failed ❌",
          cancelled: "Purchase cancelled.",
          order: "Order",
          quote_expired: "The quote expired before acceptance. Choose the product again for a current price.",
          back: "Back to catalog"
        },
        "uk_UA" => {
          quote_title: "Пропозиція купівлі",
          product: "Продукт",
          price: "Ціна",
          expires: "Дійсна до",
          accept: "Підтвердити купівлю",
          unpriced: "Для цього продукту ще немає активної ціни.",
          pending: "Заявку прийнято ✅\nМи вже працюємо над нею.",
          claimed: "Заявку прийнято ✅\nОператор уже працює над нею.",
          refresh: "Оновити статус",
          refresh_hint: "Можеш повернутися пізніше й натиснути цю кнопку: стан замовлення збережено.",
          succeeded: "Купівлю завершено ✅",
          failed: "Купівля не вдалася ❌",
          cancelled: "Купівлю скасовано.",
          order: "Замовлення",
          quote_expired: "Строк пропозиції минув до підтвердження. Обери продукт знову, щоб отримати актуальну ціну.",
          back: "До каталогу"
        },
        "ru_RU" => {
          quote_title: "Предложение покупки",
          product: "Продукт",
          price: "Цена",
          expires: "Действует до",
          accept: "Подтвердить покупку",
          unpriced: "Для этого продукта пока нет активной цены.",
          pending: "Заявка принята ✅\nМы уже работаем над ней.",
          claimed: "Заявка принята ✅\nОператор уже работает над ней.",
          refresh: "Обновить статус",
          refresh_hint: "Можно вернуться позже и нажать эту кнопку: состояние заказа сохранено.",
          succeeded: "Покупка завершена ✅",
          failed: "Покупка не удалась ❌",
          cancelled: "Покупка отменена.",
          order: "Заказ",
          quote_expired: "Срок предложения истёк до подтверждения. Выберите продукт снова для актуальной цены.",
          back: "К каталогу"
        },
        "fr_FR" => {
          quote_title: "Offre d’achat",
          product: "Produit",
          price: "Prix",
          expires: "Valable jusqu’au",
          accept: "Accepter l’achat",
          unpriced: "Ce produit n’a pas encore de prix actif.",
          pending: "Demande acceptée ✅\nNous y travaillons déjà.",
          claimed: "Demande acceptée ✅\nUn opérateur s’en occupe déjà.",
          refresh: "Actualiser l’état",
          refresh_hint: "Vous pouvez revenir plus tard et utiliser ce bouton : l’état de la commande est conservé.",
          succeeded: "Achat terminé ✅",
          failed: "Échec de l’achat ❌",
          cancelled: "Achat annulé.",
          order: "Commande",
          quote_expired: "L’offre a expiré avant acceptation. Choisissez à nouveau le produit pour obtenir le prix actuel.",
          back: "Retour au catalogue"
        },
        "es_ES" => {
          quote_title: "Oferta de compra",
          product: "Producto",
          price: "Precio",
          expires: "Válida hasta",
          accept: "Aceptar compra",
          unpriced: "Este producto todavía no tiene un precio activo.",
          pending: "Solicitud aceptada ✅\nYa estamos trabajando en ella.",
          claimed: "Solicitud aceptada ✅\nUn operador ya está trabajando en ella.",
          refresh: "Actualizar estado",
          refresh_hint: "Puedes volver más tarde y usar este botón: el estado del pedido queda guardado.",
          succeeded: "Compra completada ✅",
          failed: "La compra falló ❌",
          cancelled: "Compra cancelada.",
          order: "Pedido",
          quote_expired: "La oferta caducó antes de aceptarla. Elige de nuevo el producto para obtener el precio actual.",
          back: "Volver al catálogo"
        },
        "de_DE" => {
          quote_title: "Kaufangebot",
          product: "Produkt",
          price: "Preis",
          expires: "Gültig bis",
          accept: "Kauf bestätigen",
          unpriced: "Für dieses Produkt gibt es noch keinen aktiven Preis.",
          pending: "Anfrage angenommen ✅\nWir arbeiten bereits daran.",
          claimed: "Anfrage angenommen ✅\nEin Operator arbeitet bereits daran.",
          refresh: "Status aktualisieren",
          refresh_hint: "Du kannst später zurückkehren und diese Schaltfläche nutzen: der Bestellstatus bleibt gespeichert.",
          succeeded: "Kauf abgeschlossen ✅",
          failed: "Kauf fehlgeschlagen ❌",
          cancelled: "Kauf storniert.",
          order: "Bestellung",
          quote_expired: "Das Angebot ist vor der Bestätigung abgelaufen. Wähle das Produkt erneut für den aktuellen Preis.",
          back: "Zurück zum Katalog"
        }
      }.freeze

      DEFAULT_KEYS = COPY.fetch(Locale::DEFAULT).keys.freeze
      COPY.each do |locale, values|
        raise KeyError, "purchase copy mismatch for #{locale}" unless values.keys.sort == DEFAULT_KEYS.sort
      end

      Screen = Struct.new(:text, :reply_markup, keyword_init: true)

      module_function

      def quote(product:, quote:, locale: Locale::DEFAULT)
        copy = copy_for(locale)
        price = product.dig("attributes", "price", "amount_usdt")
        expires_at = quote.dig("attributes", "expires_at")
        Screen.new(
          text: [
            "🧾 #{copy.fetch(:quote_title)}",
            "",
            "#{copy.fetch(:product)}: #{product.dig("attributes", "name")}",
            "#{copy.fetch(:price)}: #{price} USDT",
            "#{copy.fetch(:expires)}: #{TimestampFormatter.format(expires_at)}"
          ].join("\n"),
          reply_markup: {
            inline_keyboard: [[
              { text: copy.fetch(:accept), callback_data: "q:#{quote.fetch("id")}" }
            ]]
          }
        )
      end

      def unpriced(locale: Locale::DEFAULT)
        Screen.new(
          text: copy_for(locale).fetch(:unpriced),
          reply_markup: back_markup(locale)
        )
      end

      def quote_expired(locale: Locale::DEFAULT)
        Screen.new(
          text: copy_for(locale).fetch(:quote_expired),
          reply_markup: back_markup(locale)
        )
      end

      def order(order:, locale: Locale::DEFAULT)
        copy = copy_for(locale)
        attributes = order.fetch("attributes")
        status = attributes.fetch("status")
        product = attributes.dig("payload", "product") || {}
        heading = case status
                  when "succeeded" then copy.fetch(:succeeded)
                  when "failed" then copy.fetch(:failed)
                  when "cancelled" then copy.fetch(:cancelled)
                  else
                    attributes.dig("progress", "data", "status") == "operator_claimed" ?
                      copy.fetch(:claimed) : copy.fetch(:pending)
                  end
        lines = [heading, "", "#{copy.fetch(:order)}: #{order.fetch("id")}"]
        lines << "#{copy.fetch(:product)}: #{product["name"]}" if product["name"]
        lines << "#{copy.fetch(:price)}: #{product["amount_usdt"]} USDT" if product["amount_usdt"]
        markup = if %w[succeeded failed cancelled].include?(status)
                   back_markup(locale)
                 else
                   lines << ""
                   lines << copy.fetch(:refresh_hint)
                   {
                     inline_keyboard: [[
                       { text: copy.fetch(:refresh), callback_data: "o:#{order.fetch("id")}" }
                     ]]
                   }
                 end
        Screen.new(text: lines.join("\n"), reply_markup: markup)
      end

      def copy_for(locale)
        COPY.fetch(Locale.normalize(locale), COPY.fetch(Locale::DEFAULT))
      end

      def back_markup(locale)
        {
          inline_keyboard: [[
            { text: copy_for(locale).fetch(:back), callback_data: "h:b" }
          ]]
        }
      end
    end
end
