import { createHash } from 'node:crypto'

/**
 * Преобразование выгрузки из веб-версии в новую модель.
 *
 * Вынесено из скрипта импорта отдельно и без обращений к базе, чтобы
 * маппинг можно было проверить тестами: импорт пишет в боевые данные,
 * и ошибка в нём обнаружилась бы уже после записи.
 */

/** Форма выгрузки из старой базы — см. docs/migration.md. */
export type LegacyProject = {
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
}

export type MappedSource = {
	id: string
	name: string
	role: string
	endedAt: string | null
	salaries: { id: string; effectiveFrom: Date; amount: string }[]
}

export type MappedExpense = {
	id: string
	date: Date
	category: string
	title: string
	/** null — группа: сумма считается из позиций. */
	amount: string | null
	items: { id: string; amount: string; title: string }[]
}

/** Русские подписи категорий из старой базы → стабильные ключи. */
export const CATEGORY_KEYS: Record<string, string> = {
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
export const ENDED_AT: Record<string, string> = {
	asrmall: '2026-07'
}

/**
 * UUID из произвольного ключа.
 *
 * Идентификаторы выводятся из содержимого, поэтому повторный запуск импорта
 * на том же файле обновляет те же записи, а не создаёт дубли.
 */
export function stableUUID(seed: string): string {
	const hash = createHash('sha1').update(seed).digest('hex')
	return [
		hash.slice(0, 8),
		hash.slice(8, 12),
		'4' + hash.slice(13, 16),
		((parseInt(hash[16]!, 16) & 0x3) | 0x8).toString(16) + hash.slice(17, 20),
		hash.slice(20, 32)
	].join('-')
}

/** Полдень UTC, чтобы сдвиг часового пояса не увёл день на соседний. */
export function day(value: string): Date {
	return new Date(`${value.slice(0, 10)}T12:00:00.000Z`)
}

export function mapSource(project: LegacyProject): MappedSource {
	return {
		id: stableUUID(`source:${project.slug}`),
		name: project.slug,
		role: project.role ?? '',
		endedAt: ENDED_AT[project.slug] ?? null,
		salaries: project.salaries.map(entry => ({
			id: stableUUID(`salary:${project.slug}:${entry.from}`),
			effectiveFrom: day(entry.from),
			amount: entry.amount
		}))
	}
}

export function mapExpense(expense: LegacyProject['expenses'][number]): MappedExpense {
	const isGroup = expense.items.length > 0

	return {
		id: stableUUID(`expense:${expense.id}`),
		date: day(expense.date),
		category: CATEGORY_KEYS[expense.category] ?? expense.category,
		title: expense.title ?? '',
		// У группы сумма не хранится: она считается из позиций.
		amount: isGroup ? null : expense.amount,
		items: expense.items.map((item, index) => ({
			id: stableUUID(`item:${expense.id}:${index}`),
			amount: item.amount,
			title: item.title
		}))
	}
}

/**
 * Достаёт массив проектов из того, что отдал клиент базы.
 *
 * Запрос возвращает одну строку с одной колонкой, и разные клиенты
 * оборачивают её по-разному: Neon при выгрузке в JSON отдаёт
 * `[{ "jsonb_pretty": "[…]" }]`, где содержимое лежит строкой. Разворачиваем,
 * чтобы не заставлять руками чистить файл.
 */
export function unwrapExport(raw: unknown): LegacyProject[] {
	if (!Array.isArray(raw) || raw.length === 0) {
		throw new Error('Выгрузка пуста или не является массивом')
	}

	const first = raw[0]

	// Уже развёрнутый массив проектов.
	if (first && typeof first === 'object' && 'slug' in first) {
		return raw as LegacyProject[]
	}

	// Строка таблицы с единственной колонкой, внутри которой JSON строкой.
	if (first && typeof first === 'object') {
		const values = Object.values(first as Record<string, unknown>)
		if (values.length === 1 && typeof values[0] === 'string') {
			return unwrapExport(JSON.parse(values[0]))
		}
	}

	throw new Error(
		'Не удалось разобрать выгрузку. Ожидается массив проектов с полем "slug" ' +
		'либо результат запроса с единственной колонкой.'
	)
}

/** Проверяет, что в выгрузке есть всё, что нужно для переноса. */
export function validateExport(projects: LegacyProject[]): void {
	projects.forEach((project, index) => {
		if (!project.slug) {
			throw new Error(`Проект №${index + 1}: нет поля "slug"`)
		}
		if (!Array.isArray(project.expenses)) {
			throw new Error(`Проект «${project.slug}»: нет массива "expenses"`)
		}
		if (!Array.isArray(project.salaries)) {
			throw new Error(`Проект «${project.slug}»: нет массива "salaries"`)
		}
	})
}

/** Валюта одна на пользователя; берём у первого проекта, где она задана. */
export function pickCurrency(projects: LegacyProject[]): string {
	return projects.find(project => project.currency)?.currency ?? 'TJS'
}
