/**
 * Разовый перенос данных из веб-версии Worklog Dashboard.
 *
 * На вход — JSON, выгруженный из старой базы запросом из `docs/migration.md`.
 *
 *   npm run import:legacy -- ../legacy-export.json --dry-run   # только показать
 *   npm run import:legacy -- ../legacy-export.json             # записать
 *
 * Скрипт идемпотентен: идентификаторы выводятся из содержимого, повторный
 * запуск на том же файле обновляет те же записи, а не создаёт дубли.
 *
 * Само преобразование живёт в src/server/lib/legacy.ts и покрыто проверками
 * (`npm run check:legacy`) — в боевые данные должен попадать проверенный код.
 */
import { readFileSync } from 'node:fs'
import { Prisma, PrismaClient } from '@prisma/client'
import {
	mapExpense,
	mapSource,
	pickCurrency,
	type LegacyProject
} from '../src/server/lib/legacy.js'

const prisma = new PrismaClient()

function readExport(path: string): LegacyProject[] {
	const projects = JSON.parse(readFileSync(path, 'utf8')) as LegacyProject[]
	if (!Array.isArray(projects) || projects.length === 0) {
		throw new Error('Выгрузка пуста или не является массивом проектов')
	}
	return projects
}

/** Показывает, что будет записано, ничего не меняя. */
function preview(projects: LegacyProject[]): void {
	console.log(`Валюта: ${pickCurrency(projects)}\n`)

	for (const project of projects) {
		const source = mapSource(project)
		const expenses = project.expenses.map(mapExpense)
		const groups = expenses.filter(e => e.amount === null)

		console.log(`Источник «${source.name}» — ${source.role || 'должность не указана'}`)
		console.log(`   завершён: ${source.endedAt ?? 'нет, работа продолжается'}`)
		console.log(`   записей оклада: ${source.salaries.length}`)
		console.log(`   трат: ${expenses.length} (из них групповых: ${groups.length})`)

		const byCategory = new Map<string, number>()
		for (const expense of expenses) {
			byCategory.set(expense.category, (byCategory.get(expense.category) ?? 0) + 1)
		}
		const categories = [...byCategory.entries()]
			.sort((a, b) => b[1] - a[1])
			.map(([name, count]) => `${name}×${count}`)
			.join(', ')
		if (categories) console.log(`   категории: ${categories}`)

		const months = expenses.map(e => e.date.toISOString().slice(0, 7)).sort()
		if (months.length > 0) {
			console.log(`   период трат: ${months[0]} … ${months[months.length - 1]}`)
		}
		console.log()
	}
}

async function write(projects: LegacyProject[]): Promise<void> {
	const currency = pickCurrency(projects)
	await prisma.settings.upsert({
		where: { id: 'singleton' },
		create: { id: 'singleton', currency },
		update: { currency }
	})

	let sourceCount = 0
	let expenseCount = 0
	let itemCount = 0

	for (const project of projects) {
		const source = mapSource(project)

		await prisma.incomeSource.upsert({
			where: { id: source.id },
			create: { id: source.id, name: source.name, role: source.role, endedAt: source.endedAt },
			update: { name: source.name, role: source.role, endedAt: source.endedAt }
		})

		await prisma.salaryEntry.deleteMany({ where: { sourceId: source.id } })
		if (source.salaries.length > 0) {
			await prisma.salaryEntry.createMany({
				data: source.salaries.map(entry => ({
					id: entry.id,
					sourceId: source.id,
					effectiveFrom: entry.effectiveFrom,
					amount: new Prisma.Decimal(entry.amount)
				}))
			})
		}
		sourceCount += 1

		for (const legacyExpense of project.expenses) {
			const expense = mapExpense(legacyExpense)
			// Траты перестают принадлежать источнику: они личные.
			const fields = {
				date: expense.date,
				category: expense.category,
				title: expense.title,
				amount: expense.amount === null ? null : new Prisma.Decimal(expense.amount),
				incomeSourceId: null
			}

			await prisma.expense.upsert({
				where: { id: expense.id },
				create: { id: expense.id, ...fields },
				update: fields
			})

			await prisma.expenseItem.deleteMany({ where: { expenseId: expense.id } })
			if (expense.items.length > 0) {
				await prisma.expenseItem.createMany({
					data: expense.items.map(item => ({
						id: item.id,
						expenseId: expense.id,
						amount: new Prisma.Decimal(item.amount),
						title: item.title
					}))
				})
				itemCount += expense.items.length
			}
			expenseCount += 1
		}
	}

	console.log(`Перенесено: источников ${sourceCount}, трат ${expenseCount}, позиций ${itemCount}`)
	console.log(`Валюта: ${currency}`)
	console.log('\nСверьте контрольные цифры за август 2026 в приложении:')
	console.log('  «Оклад» и «Потрачено» меняться не должны;')
	console.log('  «Перенос» и «Остаток» изменятся — цепочка стала сквозной.')
}

async function main() {
	const args = process.argv.slice(2)
	const path = args.find(arg => !arg.startsWith('--'))
	const isDryRun = args.includes('--dry-run')

	if (!path) {
		console.error(
			'Укажите путь к файлу выгрузки:\n' +
			'  npm run import:legacy -- ../legacy-export.json --dry-run\n' +
			'  npm run import:legacy -- ../legacy-export.json'
		)
		process.exit(1)
	}

	const projects = readExport(path)
	preview(projects)

	if (isDryRun) {
		console.log('Это предпросмотр — в базу ничего не записано.')
		console.log('Уберите --dry-run, чтобы выполнить импорт.')
		return
	}

	await write(projects)
}

main()
	.catch(error => {
		console.error(error instanceof Error ? error.message : error)
		process.exit(1)
	})
	.finally(() => prisma.$disconnect())
