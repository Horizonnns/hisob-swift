import Foundation

/// Запись, не доехавшая до сервера.
///
/// Хранится на диске и повторяется при появлении связи. Порядок операций
/// сохраняется: правка после создания должна применяться именно в этом
/// порядке, иначе сервер получит правку несуществующей записи.
public enum PendingOperation: Codable, Hashable, Sendable {
    case addExpense(Expense)
    case updateExpense(Expense)
    case deleteExpense(Expense.ID)
    case addReceipt(Receipt)
    case updateReceipt(Receipt)
    case deleteReceipt(Receipt.ID)
    case saveSource(IncomeSource)
    case deleteSource(IncomeSource.ID)
    case setCurrency(CurrencyCode)
}

extension PendingOperation {
    /// Применяет операцию к локальному состоянию — чтобы после перезапуска
    /// приложение показывало то же, что показывало до него.
    public func apply(to ledger: inout Ledger) {
        switch self {
        case .addExpense(let expense):
            if let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) {
                ledger.expenses[index] = expense
            } else {
                ledger.expenses.append(expense)
            }

        case .updateExpense(let expense):
            guard let index = ledger.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
            ledger.expenses[index] = expense

        case .deleteExpense(let id):
            ledger.expenses.removeAll { $0.id == id }

        case .addReceipt(let receipt):
            if let index = ledger.receipts.firstIndex(where: { $0.id == receipt.id }) {
                ledger.receipts[index] = receipt
            } else {
                ledger.receipts.append(receipt)
            }

        case .updateReceipt(let receipt):
            guard let index = ledger.receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
            ledger.receipts[index] = receipt

        case .deleteReceipt(let id):
            ledger.receipts.removeAll { $0.id == id }

        case .saveSource(let source):
            if let index = ledger.sources.firstIndex(where: { $0.id == source.id }) {
                ledger.sources[index] = source
            } else {
                ledger.sources.append(source)
            }

        case .deleteSource(let id):
            ledger.sources.removeAll { $0.id == id }
            for index in ledger.expenses.indices where ledger.expenses[index].incomeSourceID == id {
                ledger.expenses[index].incomeSourceID = nil
            }

        case .setCurrency(let currency):
            ledger.currency = currency
        }
    }

    /// Отправляет операцию на сервер.
    func send(to repository: any LedgerRepository) async throws {
        switch self {
        case .addExpense(let expense): try await repository.add(expense)
        case .updateExpense(let expense): try await repository.update(expense)
        case .deleteExpense(let id): try await repository.delete(expenseID: id)
        case .addReceipt(let receipt): try await repository.add(receipt)
        case .updateReceipt(let receipt): try await repository.update(receipt)
        case .deleteReceipt(let id): try await repository.delete(receiptID: id)
        case .saveSource(let source): try await repository.save(source)
        case .deleteSource(let id): try await repository.delete(sourceID: id)
        case .setCurrency(let currency): try await repository.setCurrency(currency)
        }
    }
}

extension Array where Element == PendingOperation {
    /// Схлопывает очередь, убирая заведомо лишнее.
    ///
    /// Правка записи, ещё не уехавшей на сервер, заменяет её создание.
    /// Удаление такой записи снимает обе операции — серверу о ней знать
    /// незачем. Смена валюты нужна только последняя.
    public func collapsed() -> [PendingOperation] {
        var result: [PendingOperation] = []

        for operation in self {
            switch operation {
            case .updateExpense(let expense):
                if let index = result.lastIndex(where: { $0.touchesExpense(expense.id) }) {
                    // Создание остаётся созданием, но уже с новым содержимым.
                    result[index] = result[index].isAdd
                        ? .addExpense(expense)
                        : .updateExpense(expense)
                } else {
                    result.append(operation)
                }

            case .deleteExpense(let id):
                let hadUnsentAdd = result.contains { $0.isAdd && $0.touchesExpense(id) }
                result.removeAll { $0.touchesExpense(id) }
                if !hadUnsentAdd { result.append(operation) }

            case .updateReceipt(let receipt):
                if let index = result.lastIndex(where: { $0.touchesReceipt(receipt.id) }) {
                    result[index] = result[index].isAddReceipt
                        ? .addReceipt(receipt)
                        : .updateReceipt(receipt)
                } else {
                    result.append(operation)
                }

            case .deleteReceipt(let id):
                let hadUnsentAdd = result.contains { $0.isAddReceipt && $0.touchesReceipt(id) }
                result.removeAll { $0.touchesReceipt(id) }
                if !hadUnsentAdd { result.append(operation) }

            case .saveSource(let source):
                result.removeAll { $0.touchesSource(source.id) }
                result.append(operation)

            case .deleteSource(let id):
                result.removeAll { $0.touchesSource(id) }
                result.append(operation)

            case .setCurrency:
                result.removeAll(where: \.isCurrency)
                result.append(operation)

            case .addExpense, .addReceipt:
                result.append(operation)
            }
        }

        return result
    }
}

private extension PendingOperation {
    var isAdd: Bool {
        if case .addExpense = self { return true }
        return false
    }

    var isAddReceipt: Bool {
        if case .addReceipt = self { return true }
        return false
    }

    var isCurrency: Bool {
        if case .setCurrency = self { return true }
        return false
    }

    func touchesExpense(_ id: Expense.ID) -> Bool {
        switch self {
        case .addExpense(let expense), .updateExpense(let expense): expense.id == id
        case .deleteExpense(let target): target == id
        default: false
        }
    }

    func touchesReceipt(_ id: Receipt.ID) -> Bool {
        switch self {
        case .addReceipt(let receipt), .updateReceipt(let receipt): receipt.id == id
        case .deleteReceipt(let target): target == id
        default: false
        }
    }

    func touchesSource(_ id: IncomeSource.ID) -> Bool {
        switch self {
        case .saveSource(let source): source.id == id
        case .deleteSource(let target): target == id
        default: false
        }
    }
}
