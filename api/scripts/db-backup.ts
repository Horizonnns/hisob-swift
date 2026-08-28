/**
 * Выгружает текущее содержимое базы в файл.
 *
 * Страховка перед разрушительными операциями: снос базы, повторный импорт,
 * ручные правки. Формат — тот же, что у экспорта из приложения.
 *
 * Запуск: npm run db:backup -- ../backup.json
 */
import { writeFileSync } from 'node:fs'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
	const path = process.argv.find(arg => arg.endsWith('.json'))
	if (!path) {
		console.error('Укажите файл: npm run db:backup -- ../backup.json')
		process.exit(1)
	}

	const [settings, sources, expenses, receipts] = await Promise.all([
		prisma.settings.findUnique({ where: { id: 'singleton' } }),
		prisma.incomeSource.findMany({ include: { salaries: true } }),
		prisma.expense.findMany({ include: { items: true } }),
		prisma.receipt.findMany()
	])

	const payload = {
		savedAt: new Date().toISOString(),
		currency: settings?.currency ?? 'TJS',
		sources: sources.map(s => ({
			id: s.id, name: s.name, role: s.role, endedAt: s.endedAt,
			salaries: s.salaries.map(e => ({
				id: e.id,
				effectiveFrom: e.effectiveFrom.toISOString().slice(0, 10),
				amount: e.amount.toFixed(2)
			}))
		})),
		expenses: expenses.map(e => ({
			id: e.id,
			date: e.date.toISOString().slice(0, 10),
			category: e.category,
			title: e.title,
			amount: e.amount === null ? null : e.amount.toFixed(2),
			incomeSourceId: e.incomeSourceId,
			items: e.items.map(i => ({ id: i.id, amount: i.amount.toFixed(2), title: i.title }))
		})),
		receipts: receipts.map(r => ({
			id: r.id,
			date: r.date.toISOString().slice(0, 10),
			kind: r.kind,
			title: r.title,
			amount: r.amount.toFixed(2)
		}))
	}

	writeFileSync(path, JSON.stringify(payload, null, 2))
	console.log(
		`Сохранено в ${path}: источников ${payload.sources.length}, ` +
		`трат ${payload.expenses.length}, поступлений ${payload.receipts.length}`
	)
}

main()
	.catch(error => { console.error(error instanceof Error ? error.message : error); process.exit(1) })
	.finally(() => prisma.$disconnect())
