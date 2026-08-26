/**
 * Проверяет преобразование выгрузки из веб-версии.
 *
 * Импорт пишет в боевые данные, поэтому маппинг проверяется отдельно
 * и без обращений к базе.
 *
 * Запуск: npm run check:legacy
 */
import assert from 'node:assert/strict'
import {
	CATEGORY_KEYS,
	day,
	mapExpense,
	mapSource,
	pickCurrency,
	stableUUID,
	type LegacyProject
} from '../src/server/lib/legacy.js'

const checks: [string, () => void][] = []
function check(name: string, body: () => void) {
	checks.push([name, body])
}

// Образец в точности той формы, которую отдаёт запрос из docs/migration.md.
const asrmall: LegacyProject = {
	slug: 'asrmall',
	role: 'Frontend Engineer',
	currency: 'TJS',
	salaries: [
		{ from: '2026-03-10', amount: '6000.00' },
		{ from: '2026-04-01', amount: '8000.00' },
		{ from: '2026-07-01', amount: '1.00' }
	],
	expenses: [
		{
			id: 'clx1', date: '2026-07-01', category: 'Гигиена',
			title: 'айна (3кг)', amount: '75.00', items: []
		},
		{
			id: 'clx2', date: '2026-07-01', category: 'Еда',
			title: 'перекус', amount: '40.00',
			items: [
				{ amount: '25.00', title: 'самса' },
				{ amount: '15.00', title: 'чай' }
			]
		}
	]
}

check('Категории переводятся в стабильные ключи', () => {
	assert.equal(mapExpense(asrmall.expenses[0]!).category, 'hygiene')
	assert.equal(mapExpense(asrmall.expenses[1]!).category, 'food')
})

check('Все 16 категорий веб-версии покрыты', () => {
	const legacy = [
		'Еда', 'Транспорт', 'Аренда', 'Коммуналка', 'Связь/Интернет', 'Здоровье',
		'Гигиена', 'Косметика', 'Одежда', 'Развлечения', 'Образование', 'Подарки',
		'Благотворительность', 'Кредит', 'Сбережения', 'Прочее'
	]
	assert.equal(Object.keys(CATEGORY_KEYS).length, legacy.length)
	for (const name of legacy) {
		assert.ok(CATEGORY_KEYS[name], `не распознана категория: ${name}`)
	}
})

check('Незнакомая категория переносится как есть, а не теряется', () => {
	const custom = { ...asrmall.expenses[0]!, category: 'Своя категория' }
	assert.equal(mapExpense(custom).category, 'Своя категория')
})

check('Одиночная трата сохраняет сумму', () => {
	const mapped = mapExpense(asrmall.expenses[0]!)
	assert.equal(mapped.amount, '75.00')
	assert.equal(mapped.items.length, 0)
})

check('У группы сумма не хранится — только позиции', () => {
	const mapped = mapExpense(asrmall.expenses[1]!)
	assert.equal(mapped.amount, null, 'сумма группы должна быть null')
	assert.equal(mapped.items.length, 2)
	assert.deepEqual(mapped.items.map(i => i.amount), ['25.00', '15.00'])
	// Сумма позиций совпадает с прежним amount — данные не теряются.
	const total = mapped.items.reduce((sum, i) => sum + Number(i.amount), 0)
	assert.equal(total, Number(asrmall.expenses[1]!.amount))
})

check('Повторный импорт даёт те же идентификаторы', () => {
	assert.equal(mapExpense(asrmall.expenses[0]!).id, mapExpense(asrmall.expenses[0]!).id)
	assert.equal(mapSource(asrmall).id, mapSource(asrmall).id)
	// И они действительно UUID — API принимает только их.
	assert.match(mapSource(asrmall).id, /^[0-9a-f-]{36}$/)
})

check('Разные записи получают разные идентификаторы', () => {
	assert.notEqual(stableUUID('expense:clx1'), stableUUID('expense:clx2'))
	assert.notEqual(stableUUID('item:clx2:0'), stableUUID('item:clx2:1'))
})

check('asrmall помечается завершённым в июле 2026', () => {
	assert.equal(mapSource(asrmall).endedAt, '2026-07')
})

check('Действующий источник остаётся без даты завершения', () => {
	const od: LegacyProject = { ...asrmall, slug: 'OD', expenses: [], salaries: [] }
	assert.equal(mapSource(od).endedAt, null)
})

check('История оклада переносится целиком и по порядку', () => {
	const mapped = mapSource(asrmall)
	assert.equal(mapped.salaries.length, 3)
	assert.deepEqual(mapped.salaries.map(s => s.amount), ['6000.00', '8000.00', '1.00'])
})

check('Дата не уезжает на соседний день из-за часового пояса', () => {
	// Полночь UTC для пояса западнее Гринвича дала бы 30 июня.
	assert.equal(day('2026-07-01').toISOString().slice(0, 10), '2026-07-01')
	assert.equal(day('2026-07-01T00:00:00Z').toISOString().slice(0, 10), '2026-07-01')
})

check('Валюта берётся из первого проекта, где она задана', () => {
	assert.equal(pickCurrency([{ ...asrmall, currency: '' }, asrmall]), 'TJS')
	assert.equal(pickCurrency([]), 'TJS')
})

let failed = 0
for (const [name, body] of checks) {
	try {
		body()
		console.log(`  ✓ ${name}`)
	} catch (cause) {
		failed += 1
		console.error(`  ✗ ${name}\n    ${(cause as Error).message.split('\n')[0]}`)
	}
}

console.log(failed === 0
	? `\nПреобразование выгрузки: ${checks.length} проверок пройдено.`
	: `\nНе пройдено: ${failed} из ${checks.length}.`)

process.exit(failed === 0 ? 0 : 1)
