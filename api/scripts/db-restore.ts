/**
 * Заливает в базу содержимое файла, снятого `npm run db:backup`.
 *
 * Пара к `db:reset`: без неё бэкап был тупиком — снять снимок можно, а
 * развернуть обратно нечем. `import:legacy` не подходит, он читает формат
 * выгрузки из веба, а не наш.
 *
 * По умолчанию отказывается работать на непустой базе: восстановление поверх
 * существующих записей либо упало бы на совпадении идентификаторов, либо
 * молча смешало бы два состояния. Сначала `db:reset`, потом `db:restore`.
 *
 * Запуск: npm run db:restore -- ../backup-2026-09-01.json
 */
import { readFileSync } from 'node:fs'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

/** Дата в базе — `@db.Date`, время не хранится. Полдень UTC защищает от
 *  сдвига на сутки в часовых поясах западнее нуля. */
function day(value: string): Date {
	return new Date(`${value}T12:00:00.000Z`)
}

type Backup = {
	savedAt?: string
	currency?: string
	sources?: Array<{
		id: string
		name: string
		role?: string
		endedAt?: string | null
		salaries?: Array<{ id: string; effectiveFrom: string; amount: string }>
	}>
	expenses?: Array<{
		id: string
		date: string
		category: string
		title?: string
		amount?: string | null
		incomeSourceId?: string | null
		items?: Array<{ id: string; amount: string; title: string }>
	}>
	receipts?: Array<{ id: string; date: string; kind: string; title?: string; amount: string }>
}

function parse(path: string): Backup {
	const raw = JSON.parse(readFileSync(path, 'utf8'))
	if (Array.isArray(raw) || typeof raw !== 'object' || raw === null) {
		throw new Error(
			'Это не файл бэкапа. Ожидается объект с полями sources/expenses/receipts.\n' +
			'Похоже на выгрузку из веба — для неё есть npm run import:legacy.'
		)
	}
	const hasKnownFields = ['sources', 'expenses', 'receipts'].some(key => key in raw)
	if (!hasKnownFields) {
		throw new Error(
			'В файле нет ни sources, ни expenses, ни receipts — восстанавливать нечего.'
		)
	}

	return raw as Backup
}

async function main() {
	const path = process.argv.find(arg => arg.endsWith('.json'))
	if (!path) {
		console.error('Укажите файл: npm run db:restore -- ../backup.json')
		process.exit(1)
	}

	const backup = parse(path)
	const sources = backup.sources ?? []
	const expenses = backup.expenses ?? []
	const receipts = backup.receipts ?? []

	const existing = {
		sources: await prisma.incomeSource.count(),
		expenses: await prisma.expense.count(),
		receipts: await prisma.receipt.count()
	}
	const isEmpty = existing.sources + existing.expenses + existing.receipts === 0

	if (!isEmpty && !process.argv.includes('--force')) {
		console.error(
			`База не пуста: источников ${existing.sources}, трат ${existing.expenses}, ` +
			`поступлений ${existing.receipts}.\n` +
			'Восстановление поверх смешает два состояния. Сначала очистите:\n' +
			'  npm run db:reset -- --yes\n' +
			'Либо, если понимаете последствия, повторите с --force.'
		)
		process.exit(1)
	}

	// Пакетами, а не по записи: 433 траты по отдельному запросу — это 433
	// обращения к удалённой базе, и транзакция не доживала до конца
	// («Transaction not found»). Здесь запросов шесть, и все в одной
	// транзакции: половины восстановленной базы не бывает.
	//
	// `createMany` не умеет вложенные записи, поэтому дети вставляются
	// отдельным запросом со ссылкой на родителя.
	const salaries = sources.flatMap(source =>
		(source.salaries ?? []).map(entry => ({
			id: entry.id,
			sourceId: source.id,
			effectiveFrom: day(entry.effectiveFrom),
			amount: entry.amount
		}))
	)

	const items = expenses.flatMap(expense =>
		(expense.items ?? []).map(item => ({
			id: item.id,
			expenseId: expense.id,
			amount: item.amount,
			title: item.title
		}))
	)

	const currency = backup.currency ?? 'TJS'

	await prisma.$transaction([
		prisma.settings.upsert({
			where: { id: 'singleton' },
			update: { currency },
			create: { id: 'singleton', currency }
		}),
		prisma.incomeSource.createMany({
			data: sources.map(source => ({
				id: source.id,
				name: source.name,
				role: source.role ?? '',
				endedAt: source.endedAt ?? null
			}))
		}),
		prisma.salaryEntry.createMany({ data: salaries }),
		prisma.expense.createMany({
			data: expenses.map(expense => ({
				id: expense.id,
				date: day(expense.date),
				category: expense.category,
				title: expense.title ?? '',
				amount: expense.amount ?? null,
				incomeSourceId: expense.incomeSourceId ?? null
			}))
		}),
		prisma.expenseItem.createMany({ data: items }),
		prisma.receipt.createMany({
			data: receipts.map(receipt => ({
				id: receipt.id,
				date: day(receipt.date),
				kind: receipt.kind,
				title: receipt.title ?? '',
				amount: receipt.amount
			}))
		})
	])

	console.log(
		`Восстановлено из ${path}` +
		(backup.savedAt ? ` (снимок от ${backup.savedAt})` : '') +
		`: источников ${sources.length}, трат ${expenses.length}, ` +
		`поступлений ${receipts.length}`
	)
}

main()
	.catch(error => { console.error(error instanceof Error ? error.message : error); process.exit(1) })
	.finally(() => prisma.$disconnect())
