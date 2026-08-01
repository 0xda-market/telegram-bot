# frozen_string_literal: true

require_relative "namespace"

require_relative "locale"

module ZeroXDA::Market::TelegramBot
    module I18n
      TRANSLATIONS = {
        "en_US" => {
          server_starting: "Server is starting…",
          access_denied: "Access denied.",
          command_failed: "Could not complete the command. Please try again.",
          authorization_success: "Authorization successful ✅",
          assigned_admin_notice: "You have been assigned the admin role ✅",
          choose_product_to_buy: "Choose a product to buy:",
          selected_product: "Selected: %{name}",
          product_unavailable: "Product is unavailable",
          admin_format: "Format: /set_admin @username or Telegram ID",
          price_applied: "Price applied ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Currency price applied ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "format: /set_rate <currency> <USDT per unit>\nexample: /set_rate UAH 0.024",
          currency_not_found: "Currency %{currency} is not registered in the market catalog.",
          currency_prices_title: "💱 Currency prices",
          currency_price_missing: "price is not set",
          currency_price_hint: "Update one: /set_rate <currency> <USDT per unit>",
          server_status_title: "🖥️ Service status",
          refresh_status: "🔄 Refresh",
          active_users_title: "👥 Active users: %{count}",
          prices_title: "📦 Price application",
          base_currency: "Base: USDT",
          no_username: "no username",
          role_label: "Role: %{role}",
          update_single_price: "Update one: /apply_price <sku|position|name> <amount>",
          review_prices: "Review again: /apply_prices"
        },
        "uk_UA" => {
          server_starting: "Сервер запускається…",
          access_denied: "Доступ заборонено.",
          command_failed: "не вдалося виконати команду. спробуй ще раз.",
          authorization_success: "авторизація успішна ✅",
          assigned_admin_notice: "Вам призначено роль admin ✅",
          choose_product_to_buy: "обери продукт для купівлі:",
          selected_product: "обрано: %{name}",
          product_unavailable: "продукт недоступний",
          admin_format: "Формат: /set_admin @username або Telegram ID",
          price_applied: "Ціну застосовано ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Ціну валюти застосовано ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "формат: /set_rate <валюта> <USDT за одиницю>\nприклад: /set_rate UAH 0.024",
          currency_not_found: "Валюта %{currency} не зареєстрована в каталозі маркету.",
          currency_prices_title: "💱 Ціни валют",
          currency_price_missing: "ціну не встановлено",
          currency_price_hint: "Змінити одну: /set_rate <валюта> <USDT за одиницю>",
          server_status_title: "🖥️ Стан сервісів",
          refresh_status: "🔄 Оновити",
          active_users_title: "👥 Активні користувачі: %{count}",
          prices_title: "📦 Застосування цін",
          base_currency: "База: USDT",
          no_username: "без username",
          role_label: "Роль: %{role}",
          update_single_price: "Змінити одну: /apply_price <sku|позиція|назва> <сума>",
          review_prices: "Переглянути знову: /apply_prices"
        },
        "ru_RU" => {
          server_starting: "Сервер запускается…",
          access_denied: "Доступ запрещён.",
          command_failed: "Не удалось выполнить команду. Попробуйте ещё раз.",
          authorization_success: "Авторизация успешна ✅",
          assigned_admin_notice: "Вам назначена роль admin ✅",
          choose_product_to_buy: "Выберите продукт для покупки:",
          selected_product: "Выбрано: %{name}",
          product_unavailable: "Продукт недоступен",
          admin_format: "Формат: /set_admin @username или Telegram ID",
          price_applied: "Цена применена ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Цена валюты применена ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "формат: /set_rate <валюта> <USDT за единицу>\nпример: /set_rate UAH 0.024",
          currency_not_found: "Валюта %{currency} не зарегистрирована в каталоге маркета.",
          currency_prices_title: "💱 Цены валют",
          currency_price_missing: "цена не установлена",
          currency_price_hint: "Изменить одну: /set_rate <валюта> <USDT за единицу>",
          server_status_title: "🖥️ Состояние сервисов",
          refresh_status: "🔄 Обновить",
          active_users_title: "👥 Активные пользователи: %{count}",
          prices_title: "📦 Применение цен",
          base_currency: "База: USDT",
          no_username: "без username",
          role_label: "Роль: %{role}",
          update_single_price: "Изменить одну: /apply_price <sku|позиция|название> <сумма>",
          review_prices: "Проверить снова: /apply_prices"
        },
        "fr_FR" => {
          server_starting: "Le serveur démarre…",
          access_denied: "Accès refusé.",
          command_failed: "Impossible d’exécuter la commande. Réessayez.",
          authorization_success: "Autorisation réussie ✅",
          assigned_admin_notice: "Le rôle admin vous a été attribué ✅",
          choose_product_to_buy: "Choisissez un produit à acheter :",
          selected_product: "Sélectionné : %{name}",
          product_unavailable: "Produit indisponible",
          admin_format: "Format : /set_admin @username ou ID Telegram",
          price_applied: "Prix appliqué ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Prix de la devise appliqué ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "format : /set_rate <devise> <USDT par unité>\nexemple : /set_rate UAH 0.024",
          currency_not_found: "La devise %{currency} n’est pas enregistrée dans le catalogue du marché.",
          currency_prices_title: "💱 Prix des devises",
          currency_price_missing: "prix non défini",
          currency_price_hint: "Modifier un prix : /set_rate <devise> <USDT par unité>",
          server_status_title: "🖥️ État des services",
          refresh_status: "🔄 Actualiser",
          active_users_title: "👥 Utilisateurs actifs : %{count}",
          prices_title: "📦 Application des prix",
          base_currency: "Base : USDT",
          no_username: "sans username",
          role_label: "Rôle : %{role}",
          update_single_price: "Modifier un prix : /apply_price <sku|position|nom> <montant>",
          review_prices: "Revoir : /apply_prices"
        },
        "es_ES" => {
          server_starting: "El servidor se está iniciando…",
          access_denied: "Acceso denegado.",
          command_failed: "No se pudo completar el comando. Inténtalo de nuevo.",
          authorization_success: "Autorización completada ✅",
          assigned_admin_notice: "Se te ha asignado el rol admin ✅",
          choose_product_to_buy: "Elige un producto para comprar:",
          selected_product: "Seleccionado: %{name}",
          product_unavailable: "Producto no disponible",
          admin_format: "Formato: /set_admin @username o ID de Telegram",
          price_applied: "Precio aplicado ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Precio de moneda aplicado ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "formato: /set_rate <moneda> <USDT por unidad>\nejemplo: /set_rate UAH 0.024",
          currency_not_found: "La moneda %{currency} no está registrada en el catálogo del mercado.",
          currency_prices_title: "💱 Precios de monedas",
          currency_price_missing: "precio no establecido",
          currency_price_hint: "Cambiar uno: /set_rate <moneda> <USDT por unidad>",
          server_status_title: "🖥️ Estado de los servicios",
          refresh_status: "🔄 Actualizar",
          active_users_title: "👥 Usuarios activos: %{count}",
          prices_title: "📦 Aplicación de precios",
          base_currency: "Base: USDT",
          no_username: "sin username",
          role_label: "Rol: %{role}",
          update_single_price: "Cambiar uno: /apply_price <sku|posición|nombre> <importe>",
          review_prices: "Revisar de nuevo: /apply_prices"
        },
        "de_DE" => {
          server_starting: "Der Server wird gestartet…",
          access_denied: "Zugriff verweigert.",
          command_failed: "Der Befehl konnte nicht ausgeführt werden. Bitte erneut versuchen.",
          authorization_success: "Autorisierung erfolgreich ✅",
          assigned_admin_notice: "Dir wurde die Rolle admin zugewiesen ✅",
          choose_product_to_buy: "Wähle ein Produkt zum Kauf:",
          selected_product: "Ausgewählt: %{name}",
          product_unavailable: "Produkt ist nicht verfügbar",
          admin_format: "Format: /set_admin @username oder Telegram-ID",
          price_applied: "Preis übernommen ✅\n%{name} (%{sku})\n%{amount} USDT",
          currency_price_applied: "Währungspreis übernommen ✅\n1 %{currency} = %{amount} USDT",
          currency_price_format: "Format: /set_rate <Währung> <USDT pro Einheit>\nBeispiel: /set_rate UAH 0.024",
          currency_not_found: "Die Währung %{currency} ist nicht im Marktkatalog registriert.",
          currency_prices_title: "💱 Währungspreise",
          currency_price_missing: "Preis nicht festgelegt",
          currency_price_hint: "Einen Preis ändern: /set_rate <Währung> <USDT pro Einheit>",
          server_status_title: "🖥️ Dienststatus",
          refresh_status: "🔄 Aktualisieren",
          active_users_title: "👥 Aktive Nutzer: %{count}",
          prices_title: "📦 Preisübernahme",
          base_currency: "Basis: USDT",
          no_username: "ohne username",
          role_label: "Rolle: %{role}",
          update_single_price: "Einen Preis ändern: /apply_price <sku|position|name> <betrag>",
          review_prices: "Erneut prüfen: /apply_prices"
        }
      }.freeze

      DEFAULT_KEYS = TRANSLATIONS.fetch(Locale::DEFAULT).keys.freeze
      TRANSLATIONS.each do |locale, copy|
        missing = DEFAULT_KEYS - copy.keys
        extra = copy.keys - DEFAULT_KEYS
        next if missing.empty? && extra.empty?

        raise KeyError, "translation contract mismatch for #{locale}: missing=#{missing.inspect}, extra=#{extra.inspect}"
      end

      module_function

      def translate(key, locale: Locale::DEFAULT, **variables)
        normalized = Locale.normalize(locale)
        template = TRANSLATIONS.fetch(normalized).fetch(key) do
          TRANSLATIONS.fetch(Locale::DEFAULT).fetch(key)
        end
        format(template, variables)
      end

      def format(template, variables)
        return template if variables.empty?

        template % variables
      end

      module Helpers
        private

        def t(key, locale: current_locale, **variables)
          I18n.translate(key, locale: locale, **variables)
        end

        def current_locale
          @telegram_update_locale || Locale::DEFAULT
        end
      end
    end
end
