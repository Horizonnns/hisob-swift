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

    enum Common {
        static let delete = "Удалить"
        static let edit = "Изменить"
        static let comingSoon = "Скоро"
    }
}
