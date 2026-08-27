import Foundation

/// Все пользовательские тексты. Во вью строк быть не должно.
enum L {
    enum Tab {
        static let month = "Месяц"
        static let analytics = "Аналитика"
        static let settings = "Настройки"
    }

    enum Month {
        static let title = "Месяц"
        static let currentMonth = "Текущий месяц"
        static let previousMonth = "Предыдущий месяц"
        static let nextMonth = "Следующий месяц"
        static let goToCurrent = "К текущему"
        static let income = "Доход"
        static let carryover = "Перенос"
        static let spent = "Потрачено"
        static let remaining = "Остаток"
        static let expenses = "Траты"
        static let search = "Поиск"
        static let resetFilters = "Сбросить"
        static let addExpense = "Добавить расход"
        static let positions = "поз."
        static let expandGroup = "Показать позиции"
        static let collapseGroup = "Скрыть позиции"
    }

    enum Analytics {
        static let byCategory = "Расходы по категориям"
        static let byMonth = "Расходы по месяцам"
        static let incomeSources = "Доход по источникам"
        static let total = "Всего"
        static let amount = "Сумма"
        static let month = "Месяц"
        static let emptyTitle = "Нет данных за месяц"
        static let emptyMessage = "Добавьте траты — здесь появится разбивка по категориям."
    }

    enum Sources {
        static let title = "Источники дохода"
        static let subtitle = "Места работы, с которых приходит оклад"
        static let add = "Добавить источник"
        static let name = "Название"
        static let namePlaceholder = "Например, OD"
        static let role = "Должность"
        static let rolePlaceholder = "Например, Frontend-разработчик"
        static let salaryHistory = "История оклада"
        static let addSalary = "Добавить оклад"
        static let effectiveFrom = "Действует с"
        static let amount = "Сумма"
        static let ended = "Работа завершена"
        static let endedAt = "Последний месяц"
        static let endedBadge = "Завершён"
        static let endingBadge = "По"
        static let currentSalary = "Текущий оклад"
        static let noSalary = "Оклад не задан"
        static let lastSalary = "последний"
        static let emptyTitle = "Источников пока нет"
        static let emptyMessage = "Добавьте место работы и историю оклада — из них считается доход месяца."
        static let deleteExplanation = "Траты сохранятся: они личные и к работе не привязаны."
        static let newSource = "Новый источник"
        static let editSource = "Источник"  // короткий: между двумя кнопками тулбара длинный обрезается
        static let save = "Сохранить"
        static let salaryFooter = "Оклад действует с указанного месяца до следующей записи."
        static let endedFooter = "После этого месяца источник перестаёт приносить доход. Без даты завершения оклад начислялся бы бесконечно."
    }

    enum Settings {
        static let currency = "Валюта"
        static let connection = "Подключение"
        static let connected = "Подключено"
        static let notConnected = "Демо-режим"
        static let demoNotice = "Подключение не настроено — показаны демонстрационные данные, они не сохраняются. Укажите адрес сервера и токен, чтобы работать с реальной базой."
        static let connectedNotice = "Данные хранятся на сервере. Последняя загрузка сохраняется на устройстве и показывается без сети."
        static let export = "Экспорт данных"
        static let exportSubtitle = "Выгрузить всё в файл"
        static let exportFooter = "Копия, не зависящая ни от сервера, ни от устройства. Держите её где-нибудь отдельно."
        static let pendingChanges = "Не отправлено"
        static let pendingChangesFooter = "Сохранено на устройстве. Нажмите, чтобы отправить сейчас."
        static let pendingRetry = "Отправить сейчас"
    }

    enum Connection {
        static let title = "Подключение"
        static let urlPlaceholder = "hisob-api.vercel.app"
        static let tokenPlaceholder = "Токен доступа"
        static let footer = "Адрес развёрнутого API и токен из переменной HISOB_API_TOKEN. Токен хранится в Keychain устройства."
        static let check = "Проверить связь"
        static let disconnect = "Отключить"
        static let disconnectFooter = "Данные на сервере останутся. Приложение вернётся к демонстрационному режиму."
    }

    enum Expense {
        static let editTitle = "Трата"
        static let kind = "Вид"
        static let singleKind = "Одна сумма"
        static let groupKind = "Несколько позиций"
        static let groupTitle = "Название"
        static let groupTitlePlaceholder = "Например, продукты"
        static let items = "Позиции"
        static let itemTitle = "Что"
        static let addItem = "Добавить позицию"
        static let groupFooter = "Сумма группы считается из позиций — отдельно её вводить не нужно."
    }

    enum Empty {
        static let noExpensesTitle = "Трат пока нет"
        static let noExpensesMessage = "Добавьте первую трату — она появится в списке и в статистике месяца."
        static let noMatchesTitle = "Ничего не найдено"
        static let noMatchesMessage = "Попробуйте изменить запрос или сбросить фильтры."
    }

    enum Error {
        static let title = "Не удалось загрузить"
        static let retry = "Повторить"
        static let saveFailed = "Не удалось сохранить"
    }

    enum AddExpense {
        static let title = "Новая трата"
        static let amount = "Сумма"
        static let category = "Категория"
        static let date = "Дата"
        static let description = "Описание"
        static let descriptionPlaceholder = "На что потратили"
        static let save = "Добавить"
        static let cancel = "Отмена"
    }

    enum Lock {
        static let title = "Приложение заперто"
        static let subtitle = "Подтвердите, что это вы, чтобы увидеть свои финансы."
        static let reason = "Разблокировать Hisob"
        static let cancel = "Отмена"
        static let passcode = "Код-пароль"
        static let settingsTitle = "Вход по биометрии"
        static let settingsSubtitle = "Спрашивать при запуске и возврате из фона"
        static let unavailable = "На этом устройстве недоступно"
        static let failed = "Не удалось подтвердить личность. Попробуйте ещё раз."
        static let turnedOff = "Биометрия стала недоступна — вход по биометрии выключен."
    }

    enum Common {
        static let delete = "Удалить"
        static let edit = "Изменить"
        static let comingSoon = "Скоро"
    }
}
