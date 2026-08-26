/**
 * Разовый перенос данных из веб-версии Worklog Dashboard.
 *
 * На вход — JSON, выгруженный из старой базы запросом из `docs/migration.md`.
 * Запуск:
 *   npx tsx scripts/import-legacy.ts ../legacy-export.json
 *
 * Скрипт идемпотентен по идентификаторам: повторный запуск на том же файле
 * не создаёт дублей, потому что id выводятся из содержимого детерминированно.
 */
import { readFileSync } from 'node:fs'
import { createHash, randomUUID } from 'node:crypto'
import { Prisma, PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

/** Русские подписи категорий из старой базы → стабильные ключи. */
const CATEGORY_KEYS: Record<string, string> = {
	'Еда': 'food',
	'Транспорт': 'transport',
	'Аренда': 'rent',
	'Коммуналка': 'utilities',
	'Связь/Интернет': 'communication',
	'Здоровье': 'health',
	'Гигиена': 'hygiene',
	'Косметика': 'cosmetics',
	'Одежда': 'clothing',
	'Развлечения': 'entertainment',
	'Образование': 'education',
	'Подарки': 'gifts',
	'Благотворительность': 'charity',
	'Кредит': 'loan',
	'Сбережения': 'savings',
	'Прочее': 'other'
}

/**
 * Даты завершения работ. Проставляются вручную: в старой схеме окончания
 * у оклада не было, и вывести его из данных нельзя.
 */
const ENDED_AT: Record<string, string> = {
	asrmall: '2026-07'
}

type LegacyExport = {
	slug: string
	role: string
	currency: string
	salaries: { from: string; amount: string }[]
	expenses: {
		id: string
		date: string
		category: string
		title: string
		amount: string
		items: { amount: string; title: string }[]
	}[]
}[]

/** UUID из произвольного ключа — чтобы повторный импорт не плодил дубли. */
function stableUUID(seed: string): string {
	const hash = createHash('sha1').update(seed).digest('hex')
	return [
		hash.slice(0, 8),
		hash.slice(8, 12),
		'4' + hash.slice(13, 16),
		((parseInt(hash[16]!, 16) & 0x3) | 0x8).toString(16) + hash.slice(17, 20),
		hash.slice(20, 32)
	].join('-')
}

function day(value: string): Date {
	return new Date(`${value.slice(0, 10)}T12:00:00.000Z`)
}

async function main() {
	const path = process.argv[2]
	if (!path) {
		console.error('Укажите путь к файлу выгрузки: npx tsx scripts/import-legacy.ts export.json')
		process.exit(1)
	}

	const projects = JSON.parse(readFileSync(path, 'utf8')) as LegacyExport
	if (!Array.isArray(projects) || projects.length === 0) {
		console.error('Выгрузка пуста')
		process.exit(1)
	}

	// Валюта одна на пользователя; берём у первого проекта, где она задана.
	const currency = projects.find(p => p.currency)?.currency ?? 'TJS'
	await prisma.settings.upsert({
		where: { id: 'singleton' },
		create: { id: 'singleton', currency },
		update: { currency }
	})

	let sourceCount = 0
	let expenseCount = 0
	let itemCount = 0

	for (const project of projects) {
		const sourceId = stableUUID(`source:${project.slug}`)
		const endedAt = ENDED_AT[project.slug] ?? null

		await prisma.incomeSource.upsert({
			where: { id: sourceId },
			create: { id: sourceId, name: project.slug, role: project.role ?? '', endedAt },
			update: { name: project.slug, role: project.role ?? '', endedAt }
		})

		await prisma.salaryEntry.deleteMany({ where: { sourceId } })
		if (project.salaries.length > 0) {
			await prisma.salaryEntry.createMany({
				data: project.salaries.map(entry => ({
					id: stableUUID(`salary:${project.slug}:${entry.from}`),
					sourceId,
					effectiveFrom: day(entry.from),
					amount: new Prisma.Decimal(entry.amount)
				}))
			})
		}
		sourceCount += 1

		for (const expense of project.expenses) {
			// Траты перестают принадлежать проекту: они личные.
			const id = stableUUID(`expense:${expense.id}`)
			const isGroup = expense.items.length > 0

			await prisma.expense.upsert({
				where: { id },
				create: {
					id,
					date: day(expense.date),
					category: CATEGORY_KEYS[expense.category] ?? expense.category,
					title: expense.title ?? '',
					amount: isGroup ? null : new Prisma.Decimal(expense.amount),
					incomeSourceId: null
				},
				update: {
					date: day(expense.date),
					category: CATEGORY_KEYS[expense.category] ?? expense.category,
					title: expense.title ?? '',
					amount: isGroup ? null : new Prisma.Decimal(expense.amount)
				}
			})

			await prisma.expenseItem.deleteMany({ where: { expenseId: id } })
			if (isGroup) {
				await prisma.expenseItem.createMany({
					data: expense.items.map((item, index) => ({
						id: stableUUID(`item:${expense.id}:${index}`),
						expenseId: id,
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
	for (const [slug, month] of Object.entries(ENDED_AT)) {
		console.log(`Источник «${slug}» помечен завершённым: последний месяц ${month}`)
	}
	console.log('\nСверьте контрольные цифры за август 2026 в приложении:')
	console.log('  «Оклад» и «Потрачено» меняться не должны;')
	console.log('  «Перенос» и «Остаток» изменятся — цепочка стала сквозной.')
}

main()
	.catch(error => {
		console.error(error)
		process.exit(1)
	})
	.finally(() => prisma.$disconnect())
