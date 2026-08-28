/**
 * Полностью очищает базу.
 *
 * Разрушительно и необратимо. Требует явного `--yes`, чтобы случайный
 * запуск не стёр данные. Перед запуском сделайте `npm run db:backup`.
 *
 * Запуск: npm run db:reset -- --yes
 */
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
	if (!process.argv.includes('--yes')) {
		console.error(
			'Это сотрёт все данные. Сначала сделайте копию:\n' +
			'  npm run db:backup -- ../backup.json\n' +
			'Затем повторите с подтверждением:\n' +
			'  npm run db:reset -- --yes'
		)
		process.exit(1)
	}

	const before = {
		sources: await prisma.incomeSource.count(),
		expenses: await prisma.expense.count(),
		receipts: await prisma.receipt.count()
	}

	// Порядок важен: сначала зависимые записи.
	await prisma.receipt.deleteMany()
	await prisma.expenseItem.deleteMany()
	await prisma.expense.deleteMany()
	await prisma.salaryEntry.deleteMany()
	await prisma.incomeSource.deleteMany()
	await prisma.settings.deleteMany()

	console.log(
		`Удалено: источников ${before.sources}, трат ${before.expenses}, ` +
		`поступлений ${before.receipts}. База пуста.`
	)
}

main()
	.catch(error => { console.error(error instanceof Error ? error.message : error); process.exit(1) })
	.finally(() => prisma.$disconnect())
