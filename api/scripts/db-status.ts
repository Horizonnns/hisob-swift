/**
 * Показывает, что сейчас лежит в базе.
 *
 * Нужен, чтобы отличать «структура создана, но пуста» от «данные на месте»:
 * `prisma migrate deploy` создаёт таблицы, а наполняет их только импорт,
 * и по пустому экрану приложения эти два состояния неразличимы.
 *
 * Запуск: npm run db:status
 */
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
	const [settings, sources, salaries, expenses, items] = await Promise.all([
		prisma.settings.findUnique({ where: { id: 'singleton' } }),
		prisma.incomeSource.findMany({ include: { _count: { select: { salaries: true } } } }),
		prisma.salaryEntry.count(),
		prisma.expense.count(),
		prisma.expenseItem.count()
	])

	console.log(`Валюта: ${settings?.currency ?? '(не задана)'}`)
	console.log(`Источников: ${sources.length}, записей оклада: ${salaries}`)
	console.log(`Трат: ${expenses}, позиций в группах: ${items}\n`)

	for (const source of sources) {
		const ended = source.endedAt ? `завершён ${source.endedAt}` : 'работа продолжается'
		console.log(`  ${source.name} — ${ended}, окладов: ${source._count.salaries}`)
	}

	if (expenses === 0) {
		console.log('\nТаблицы есть, но данных нет — импорт ещё не выполнялся.')
	}
}

main()
	.catch(error => {
		console.error(error instanceof Error ? error.message : error)
		process.exit(1)
	})
	.finally(() => prisma.$disconnect())
