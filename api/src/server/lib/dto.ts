import type { Expense, ExpenseItem, IncomeSource, Receipt, SalaryEntry } from '@prisma/client'
import { dateToString, moneyToString } from './money.js'

type ExpenseRow = Expense & { items: ExpenseItem[] }
type SourceRow = IncomeSource & { salaries: SalaryEntry[] }

export function expenseToDTO(row: ExpenseRow) {
	return {
		id: row.id,
		date: dateToString(row.date),
		category: row.category,
		title: row.title,
		amount: row.amount === null ? null : moneyToString(row.amount),
		items: row.items.map(item => ({
			id: item.id,
			amount: moneyToString(item.amount),
			title: item.title
		})),
		incomeSourceId: row.incomeSourceId
	}
}

export function receiptToDTO(row: Receipt) {
	return {
		id: row.id,
		date: dateToString(row.date),
		kind: row.kind,
		title: row.title,
		amount: moneyToString(row.amount)
	}
}

export function sourceToDTO(row: SourceRow) {
	return {
		id: row.id,
		name: row.name,
		role: row.role,
		endedAt: row.endedAt,
		salaries: row.salaries
			.slice()
			.sort((a, b) => a.effectiveFrom.getTime() - b.effectiveFrom.getTime())
			.map(entry => ({
				id: entry.id,
				effectiveFrom: dateToString(entry.effectiveFrom),
				amount: moneyToString(entry.amount)
			}))
	}
}
