# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "namespace"
require_relative "locale"

module ZeroXDA::Market::TelegramBot
  # Screens for buying 0x1 Special with seeds from the chat. Every number on
  # them comes from 0x1 Identity (wallet, Special) or Market (price, order);
  # the bot never computes a balance or decides that a purchase succeeded.
  module SpecialCheckoutMessages
    Screen = Struct.new(:text, :reply_markup, keyword_init: true)

    COPY = {
      "en_US" => {
        bond: "0x1 Bond: %<bond>s", balance: "Balance: %<seeds>s ₴€£", price: "Price: %<price>s ₴€£",
        buy: "Buy for %<price>s ₴€£", not_enough: "Not enough seeds (%<seeds>s ₴€£)",
        held: "Special is already yours until %<until>s. A new purchase opens when it ends.",
        held_short: "Special is already active",
        sign_in: "Connect this Telegram account to your 0x1 Bond to pay with seeds.",
        sign_in_button: "Sign in to 0x1", check: "I have connected · check",
        other_telegram: "Your 0x1 Bond is already connected to another Telegram account. " \
                        "Buy from that account, or disconnect it in 0x1 and connect this one.",
        unavailable: "0x1 is not answering right now. Nothing was charged; try again in a moment.",
        not_sold: "Special for seeds is not on sale right now.",
        confirm: "Pay %<price>s ₴€£ from the wallet of %<bond>s for %<name>s?",
        confirm_button: "Pay %<price>s ₴€£", back: "‹ Back", home: "⌂ Home",
        pending: "Order placed. 0x1 is charging the wallet…", refresh: "↻ Refresh", cancel: "Cancel order",
        paid: "Paid ✅ %<name>s is yours.\n\nxPing is flying to 0xda-market to pick it up. " \
              "If you call the flight off, the purchase stays “Paid” and waits at any 0xda-market point.",
        cancelled: "Order cancelled. Nothing was charged.",
        expired: "The order was not confirmed in time. Nothing was charged.",
        rejected: "0x1 did not accept the payment (%<reason>s). Nothing was charged.",
        reasons: { "insufficient_seeds" => "not enough seeds", "special_active" => "Special is already active",
                   "account_unlinked" => "this Telegram account is no longer connected",
                   "recipient_mismatch" => "the connected Bond changed" }
      },
      "uk_UA" => {
        bond: "Bond 0x1: %<bond>s", balance: "Баланс: %<seeds>s ₴€£", price: "Ціна: %<price>s ₴€£",
        buy: "Купити за %<price>s ₴€£", not_enough: "Недостатньо сідів (%<seeds>s ₴€£)",
        held: "Special уже твоя до %<until>s. Нова купівля відкриється, коли вона закінчиться.",
        held_short: "Special уже активна",
        sign_in: "Привʼяжи цей Telegram до свого Bond у 0x1, щоб платити сідами.",
        sign_in_button: "Авторизуватися у 0x1", check: "Я привʼязав · перевірити",
        other_telegram: "Твій Bond у 0x1 уже привʼязаний до іншого акаунта Telegram. " \
                        "Купуй з того акаунта або відвʼяжи його в 0x1 і привʼяжи цей.",
        unavailable: "0x1 зараз не відповідає. Нічого не списано; спробуй трохи згодом.",
        not_sold: "Special за сіди зараз не продається.",
        confirm: "Сплатити %<price>s ₴€£ з гаманця %<bond>s за %<name>s?",
        confirm_button: "Сплатити %<price>s ₴€£", back: "‹ Назад", home: "⌂ Головна",
        pending: "Замовлення створено. 0x1 списує з гаманця…", refresh: "↻ Оновити", cancel: "Скасувати замовлення",
        paid: "Оплачено ✅ %<name>s — твоя.\n\nxPing летить до 0xda-market забрати покупку. " \
              "Якщо скасуєш політ, покупка лишиться «Оплачено» і чекатиме в будь-якій точці 0xda-market.",
        cancelled: "Замовлення скасовано. Нічого не списано.",
        expired: "Замовлення не підтвердилось вчасно. Нічого не списано.",
        rejected: "0x1 не прийняв оплату (%<reason>s). Нічого не списано.",
        reasons: { "insufficient_seeds" => "недостатньо сідів", "special_active" => "Special уже активна",
                   "account_unlinked" => "цей Telegram більше не привʼязаний",
                   "recipient_mismatch" => "привʼязаний Bond змінився" }
      },
      "ru_RU" => {
        bond: "Bond 0x1: %<bond>s", balance: "Баланс: %<seeds>s ₴€£", price: "Цена: %<price>s ₴€£",
        buy: "Купить за %<price>s ₴€£", not_enough: "Недостаточно сидов (%<seeds>s ₴€£)",
        held: "Special уже твоя до %<until>s. Новая покупка откроется, когда она закончится.",
        held_short: "Special уже активна",
        sign_in: "Привяжи этот Telegram к своему Bond в 0x1, чтобы платить сидами.",
        sign_in_button: "Авторизоваться в 0x1", check: "Я привязал · проверить",
        other_telegram: "Твой Bond в 0x1 уже привязан к другому аккаунту Telegram. " \
                        "Покупай с того аккаунта или отвяжи его в 0x1 и привяжи этот.",
        unavailable: "0x1 сейчас не отвечает. Ничего не списано; попробуй чуть позже.",
        not_sold: "Special за сиды сейчас не продаётся.",
        confirm: "Оплатить %<price>s ₴€£ из кошелька %<bond>s за %<name>s?",
        confirm_button: "Оплатить %<price>s ₴€£", back: "‹ Назад", home: "⌂ Главная",
        pending: "Заказ создан. 0x1 списывает с кошелька…", refresh: "↻ Обновить", cancel: "Отменить заказ",
        paid: "Оплачено ✅ %<name>s — твоя.\n\nxPing летит в 0xda-market за покупкой. " \
              "Если отменишь полёт, покупка останется «Оплачено» и будет ждать в любой точке 0xda-market.",
        cancelled: "Заказ отменён. Ничего не списано.",
        expired: "Заказ не подтвердился вовремя. Ничего не списано.",
        rejected: "0x1 не принял оплату (%<reason>s). Ничего не списано.",
        reasons: { "insufficient_seeds" => "недостаточно сидов", "special_active" => "Special уже активна",
                   "account_unlinked" => "этот Telegram больше не привязан",
                   "recipient_mismatch" => "привязанный Bond изменился" }
      },
      "fr_FR" => {
        bond: "Bond 0x1 : %<bond>s", balance: "Solde : %<seeds>s ₴€£", price: "Prix : %<price>s ₴€£",
        buy: "Acheter pour %<price>s ₴€£", not_enough: "Pas assez de seeds (%<seeds>s ₴€£)",
        held: "Special est déjà à vous jusqu'au %<until>s. Un nouvel achat sera possible à son terme.",
        held_short: "Special est déjà actif",
        sign_in: "Associez ce compte Telegram à votre Bond 0x1 pour payer en seeds.",
        sign_in_button: "Se connecter à 0x1", check: "C'est fait · vérifier",
        other_telegram: "Votre Bond 0x1 est déjà associé à un autre compte Telegram. " \
                        "Achetez depuis ce compte, ou dissociez-le dans 0x1 et associez celui-ci.",
        unavailable: "0x1 ne répond pas. Rien n'a été débité ; réessayez dans un instant.",
        not_sold: "Special en seeds n'est pas en vente pour le moment.",
        confirm: "Payer %<price>s ₴€£ depuis le portefeuille de %<bond>s pour %<name>s ?",
        confirm_button: "Payer %<price>s ₴€£", back: "‹ Retour", home: "⌂ Accueil",
        pending: "Commande créée. 0x1 débite le portefeuille…", refresh: "↻ Actualiser", cancel: "Annuler la commande",
        paid: "Payé ✅ %<name>s est à vous.\n\nxPing vole vers 0xda-market pour la récupérer. " \
              "Si vous annulez le vol, l'achat reste « Payé » et attend dans n'importe quel point 0xda-market.",
        cancelled: "Commande annulée. Rien n'a été débité.",
        expired: "La commande n'a pas été confirmée à temps. Rien n'a été débité.",
        rejected: "0x1 a refusé le paiement (%<reason>s). Rien n'a été débité.",
        reasons: {}
      },
      "es_ES" => {
        bond: "Bond 0x1: %<bond>s", balance: "Saldo: %<seeds>s ₴€£", price: "Precio: %<price>s ₴€£",
        buy: "Comprar por %<price>s ₴€£", not_enough: "No hay suficientes seeds (%<seeds>s ₴€£)",
        held: "Special ya es tuyo hasta el %<until>s. Podrás comprarlo de nuevo cuando termine.",
        held_short: "Special ya está activo",
        sign_in: "Vincula esta cuenta de Telegram a tu Bond de 0x1 para pagar con seeds.",
        sign_in_button: "Iniciar sesión en 0x1", check: "Ya la vinculé · comprobar",
        other_telegram: "Tu Bond de 0x1 ya está vinculado a otra cuenta de Telegram. " \
                        "Compra desde esa cuenta, o desvincúlala en 0x1 y vincula esta.",
        unavailable: "0x1 no responde ahora. No se cobró nada; inténtalo en un momento.",
        not_sold: "Special con seeds no está a la venta ahora.",
        confirm: "¿Pagar %<price>s ₴€£ de la billetera de %<bond>s por %<name>s?",
        confirm_button: "Pagar %<price>s ₴€£", back: "‹ Volver", home: "⌂ Inicio",
        pending: "Pedido creado. 0x1 está cobrando de la billetera…", refresh: "↻ Actualizar", cancel: "Cancelar pedido",
        paid: "Pagado ✅ %<name>s es tuyo.\n\nxPing vuela a 0xda-market a recogerlo. " \
              "Si cancelas el vuelo, la compra sigue «Pagada» y espera en cualquier punto de 0xda-market.",
        cancelled: "Pedido cancelado. No se cobró nada.",
        expired: "El pedido no se confirmó a tiempo. No se cobró nada.",
        rejected: "0x1 no aceptó el pago (%<reason>s). No se cobró nada.",
        reasons: {}
      },
      "de_DE" => {
        bond: "0x1-Bond: %<bond>s", balance: "Guthaben: %<seeds>s ₴€£", price: "Preis: %<price>s ₴€£",
        buy: "Für %<price>s ₴€£ kaufen", not_enough: "Nicht genug Seeds (%<seeds>s ₴€£)",
        held: "Special gehört dir bereits bis %<until>s. Ein neuer Kauf ist danach möglich.",
        held_short: "Special ist bereits aktiv",
        sign_in: "Verbinde dieses Telegram-Konto mit deinem 0x1-Bond, um mit Seeds zu zahlen.",
        sign_in_button: "Bei 0x1 anmelden", check: "Verbunden · prüfen",
        other_telegram: "Dein 0x1-Bond ist bereits mit einem anderen Telegram-Konto verbunden. " \
                        "Kaufe mit diesem Konto oder trenne es in 0x1 und verbinde dieses.",
        unavailable: "0x1 antwortet gerade nicht. Nichts wurde abgebucht; versuche es gleich noch einmal.",
        not_sold: "Special für Seeds ist gerade nicht im Verkauf.",
        confirm: "%<price>s ₴€£ aus der Wallet von %<bond>s für %<name>s zahlen?",
        confirm_button: "%<price>s ₴€£ zahlen", back: "‹ Zurück", home: "⌂ Start",
        pending: "Bestellung erstellt. 0x1 bucht von der Wallet ab…", refresh: "↻ Aktualisieren",
        cancel: "Bestellung stornieren",
        paid: "Bezahlt ✅ %<name>s gehört dir.\n\nxPing fliegt zu 0xda-market, um den Kauf abzuholen. " \
              "Brichst du den Flug ab, bleibt der Kauf „Bezahlt“ und wartet an jedem 0xda-market-Punkt.",
        cancelled: "Bestellung storniert. Nichts wurde abgebucht.",
        expired: "Die Bestellung wurde nicht rechtzeitig bestätigt. Nichts wurde abgebucht.",
        rejected: "0x1 hat die Zahlung abgelehnt (%<reason>s). Nichts wurde abgebucht.",
        reasons: {}
      }
    }.freeze

    module_function

    def copy(locale)
      COPY.fetch(Locale.normalize(locale))
    end

    def text(key, locale:, **values)
      format(copy(locale).fetch(key), **values)
    end

    def nav(sku, locale)
      [{ text: text(:back, locale: locale), callback_data: "c:b:#{sku}" },
       { text: text(:home, locale: locale), callback_data: "h:b" }]
    end

    # The offer for a linked Bond: balance, price and the one Buy action, or
    # why there is none.
    def offer(name:, sku:, account:, price:, locale:)
      lines = [name, "", text(:bond, locale: locale, bond: account.pub_dress),
               text(:balance, locale: locale, seeds: account.seeds)]
      rows = []
      if !account.purchase_open
        lines << "" << held_text(account, locale)
        rows << [{ text: text(:held_short, locale: locale), callback_data: "n" }]
      elsif price.nil?
        lines << "" << text(:not_sold, locale: locale)
      else
        lines << text(:price, locale: locale, price: price)
        rows << if account.seeds >= price
                  [{ text: text(:buy, locale: locale, price: price), callback_data: "x:#{sku}" }]
                else
                  [{ text: text(:not_enough, locale: locale, seeds: account.seeds), callback_data: "n" }]
                end
      end
      Screen.new(text: lines.join("\n"), reply_markup: { inline_keyboard: rows << nav(sku, locale) })
    end

    def sign_in(name:, sku:, account:, link_url:, locale:)
      body = account.link_refusal == "provider_type_already_linked" ? :other_telegram : :sign_in
      rows = []
      rows << [{ text: text(:sign_in_button, locale: locale), url: link_url }] if link_url
      rows << [{ text: text(:check, locale: locale), callback_data: "v:#{sku}" }]
      rows << nav(sku, locale)
      Screen.new(text: "#{name}\n\n#{text(body, locale: locale)}", reply_markup: { inline_keyboard: rows })
    end

    def unavailable(sku:, locale:)
      Screen.new(text: text(:unavailable, locale: locale),
                 reply_markup: { inline_keyboard: [[{ text: text(:refresh, locale: locale),
                                                      callback_data: "v:#{sku}" }], nav(sku, locale)] })
    end

    def confirm(name:, sku:, account:, price:, locale:, nonce:)
      Screen.new(
        text: text(:confirm, locale: locale, price: price, bond: account.pub_dress, name: name),
        reply_markup: { inline_keyboard: [
          [{ text: text(:confirm_button, locale: locale, price: price), callback_data: "k:#{sku}:#{nonce}" }],
          [{ text: text(:back, locale: locale), callback_data: "v:#{sku}" }]
        ] }
      )
    end

    # An issuer order as Market reports it. "Paid" only for `fulfilled`.
    def order(order:, name:, locale:)
      attributes = order.fetch("attributes")
      id = order.fetch("id")
      sku = attributes.fetch("sku")
      case attributes.fetch("status")
      when "pending", "processing"
        rows = [[{ text: text(:refresh, locale: locale), callback_data: "w:#{id}" }]]
        if attributes.fetch("status") == "pending"
          rows << [{ text: text(:cancel, locale: locale), callback_data: "u:#{id}" }]
        end
        Screen.new(text: "#{name}\n\n#{text(:pending, locale: locale)}", reply_markup: { inline_keyboard: rows })
      when "fulfilled"
        Screen.new(text: text(:paid, locale: locale, name: name),
                   reply_markup: { inline_keyboard: [[{ text: text(:home, locale: locale), callback_data: "h:b" }]] })
      else
        Screen.new(text: "#{name}\n\n#{ended(attributes, locale)}",
                   reply_markup: { inline_keyboard: [nav(sku, locale)] })
      end
    end

    def ended(attributes, locale)
      return text(:cancelled, locale: locale) if attributes.fetch("status") == "cancelled"

      code = attributes["rejection_code"].to_s
      return text(:expired, locale: locale) if code == "authorization_expired"

      reason = copy(locale).fetch(:reasons)[code] || COPY.fetch("en_US").fetch(:reasons)[code] || code
      text(:rejected, locale: locale, reason: reason)
    end

    def held_text(account, locale)
      return text(:held_short, locale: locale) unless account.special_ends_at

      text(:held, locale: locale, until: account.special_ends_at.strftime("%Y-%m-%d"))
    end
  end
end
