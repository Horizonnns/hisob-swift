import { z } from 'zod'

/** «2026-08-02» */
const dayString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Ожидается дата вида 2026-08-02')

/** «2026-07» */
const monthString = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Ожидается месяц вида 2026-07')

/** Неотрицательная сумма строкой, максимум два знака после точки. */
const moneyString = z
	.string()
	.regex(/^\d{1,12}(\.\d{1,2})?$/, 'Ожидается сумма вида 1923.63')

const uuid = z.string().uuid()

export const expenseItemSchema = z.object({
	id: uuid,
	amount: moneyString,
	title: z.string().max(200)
})

/**
 * Трата — ровно одно из двух: либо сумма, либо непустой список позиций.
 *
 * Ограничение выражено в схеме, а не проверками по коду: в веб-версии
 * `amount` и `items` жили рядом и разъезжались.
 */
export const expenseSchema = z
	.object({
		id: uuid,
		date: dayString,
		category: z.string().min(1).max(64),
		title: z.string().max(200).default(''),
		amount: moneyString.nullable().default(null),
		items: z.array(expenseItemSchema).default([]),
		incomeSourceId: uuid.nullable().default(null)
	})
	.refine(
		value => (value.amount === null) !== (value.items.length === 0),
		{ message: 'Укажите либо amount, либо непустой items — но не оба и не ни одного' }
	)

export const salaryEntrySchema = z.object({
	id: uuid,
	effectiveFrom: dayString,
	amount: moneyString
})

export const incomeSourceSchema = z.object({
	id: uuid,
	name: z.string().min(1).max(120),
	role: z.string().max(120).default(''),
	endedAt: monthString.nullable().default(null),
	salaries: z.array(salaryEntrySchema).default([])
})

export const settingsSchema = z.object({
	currency: z.string().length(3)
})

export type ExpenseInput = z.infer<typeof expenseSchema>
export type IncomeSourceInput = z.infer<typeof incomeSourceSchema>
