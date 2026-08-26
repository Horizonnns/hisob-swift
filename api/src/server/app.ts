import { Hono } from 'hono'
import { expenseToDTO, sourceToDTO } from './lib/dto.js'
import { ERROR_MESSAGES } from './lib/http.js'
import { dateFromString, moneyFromString } from './lib/money.js'
import { prisma } from './lib/prisma.js'
import { expenseSchema, incomeSourceSchema, settingsSchema } from './lib/schemas.js'
import { requireToken } from './middleware/auth.js'
import { validateJSON } from './middleware/validate.js'

export const app = new Hono()

/** Единственный публичный роут: проверка, что деплой жив. Данных не отдаёт. */
app.get('/api/health', c => c.json({ ok: true }))

// Всё остальное — только с токеном.
app.use('/api/*', requireToken)

/**
 * Полный срез данных.
 *
 * Отдаётся целиком, а не по месяцам: расчёт переноса остатка требует всей
 * истории трат. Объём для одного пользователя за годы — сотни килобайт,
 * приложение забирает его один раз и дальше живёт на локальном снимке.
 */
app.get('/api/ledger', async c => {
	const [settings, sources, expenses] = await Promise.all([
		prisma.settings.findUnique({ where: { id: 'singleton' } }),
		prisma.incomeSource.findMany({ include: { salaries: true }, orderBy: { name: 'asc' } }),
		prisma.expense.findMany({ include: { items: true }, orderBy: { date: 'asc' } })
	])

	return c.json({
		currency: settings?.currency ?? 'TJS',
		sources: sources.map(sourceToDTO),
		expenses: expenses.map(expenseToDTO)
	})
})

/**
 * Создание траты.
 *
 * `id` приходит от клиента: приложение создаёт запись оптимистично и должно
 * знать её идентификатор до ответа сервера.
 */
app.post('/api/expenses', validateJSON(expenseSchema), async c => {
	const input = c.req.valid('json')

	const existing = await prisma.expense.findUnique({
		where: { id: input.id },
		select: { id: true }
	})
	if (existing) return c.json({ error: 'Expense already exists' }, 409)

	const created = await prisma.expense.create({
		data: {
			id: input.id,
			date: dateFromString(input.date),
			category: input.category,
			title: input.title,
			amount: input.amount === null ? null : moneyFromString(input.amount),
			incomeSourceId: input.incomeSourceId,
			items: {
				create: input.items.map(item => ({
					id: item.id,
					amount: moneyFromString(item.amount),
					title: item.title
				}))
			}
		},
		include: { items: true }
	})

	return c.json(expenseToDTO(created), 201)
})

app.patch('/api/expenses/:id', validateJSON(expenseSchema), async c => {
	const id = c.req.param('id')
	const input = c.req.valid('json')
	if (input.id !== id) return c.json({ error: 'Body id does not match path id' }, 400)

	const existing = await prisma.expense.findUnique({ where: { id }, select: { id: true } })
	if (!existing) return c.json({ error: 'Expense not found' }, 404)

	// Позиции пересоздаются целиком: их немного, а согласованность важнее
	// экономии на паре запросов. Массивная форма транзакции — требование
	// PgBouncer в режиме пулинга транзакций.
	const [, , updated] = await prisma.$transaction([
		prisma.expenseItem.deleteMany({ where: { expenseId: id } }),
		prisma.expenseItem.createMany({
			data: input.items.map(item => ({
				id: item.id,
				expenseId: id,
				amount: moneyFromString(item.amount),
				title: item.title
			}))
		}),
		prisma.expense.update({
			where: { id },
			data: {
				date: dateFromString(input.date),
				category: input.category,
				title: input.title,
				amount: input.amount === null ? null : moneyFromString(input.amount),
				incomeSourceId: input.incomeSourceId
			},
			include: { items: true }
		})
	])

	return c.json(expenseToDTO(updated))
})

app.delete('/api/expenses/:id', async c => {
	const removed = await prisma.expense.deleteMany({ where: { id: c.req.param('id') } })
	if (removed.count === 0) return c.json({ error: 'Expense not found' }, 404)
	return c.json({ ok: true })
})

/**
 * Создание или обновление источника вместе с историей оклада.
 *
 * PUT, а не PATCH: история оклада редактируется в приложении целиком, и
 * клиент присылает её окончательный вид.
 */
app.put('/api/sources/:id', validateJSON(incomeSourceSchema), async c => {
	const id = c.req.param('id')
	const input = c.req.valid('json')
	if (input.id !== id) return c.json({ error: 'Body id does not match path id' }, 400)

	const fields = { name: input.name, role: input.role, endedAt: input.endedAt }

	const [, , upserted] = await prisma.$transaction([
		prisma.incomeSource.upsert({
			where: { id },
			create: { id, ...fields },
			update: fields
		}),
		prisma.salaryEntry.deleteMany({ where: { sourceId: id } }),
		prisma.incomeSource.update({
			where: { id },
			data: {
				salaries: {
					create: input.salaries.map(entry => ({
						id: entry.id,
						effectiveFrom: dateFromString(entry.effectiveFrom),
						amount: moneyFromString(entry.amount)
					}))
				}
			},
			include: { salaries: true }
		})
	])

	return c.json(sourceToDTO(upserted))
})

/**
 * Удаление источника. Траты остаются: привязка к работе была лишь пометкой,
 * и обнуляется она через `onDelete: SetNull` в схеме.
 */
app.delete('/api/sources/:id', async c => {
	const removed = await prisma.incomeSource.deleteMany({ where: { id: c.req.param('id') } })
	if (removed.count === 0) return c.json({ error: 'Income source not found' }, 404)
	return c.json({ ok: true })
})

app.patch('/api/settings', validateJSON(settingsSchema), async c => {
	const { currency } = c.req.valid('json')
	const settings = await prisma.settings.upsert({
		where: { id: 'singleton' },
		create: { id: 'singleton', currency },
		update: { currency }
	})
	return c.json({ currency: settings.currency })
})

app.onError((cause, c) => {
	console.error('API error:', cause)
	return c.json({ error: ERROR_MESSAGES.internal }, 500)
})

app.notFound(c => c.json({ error: 'Not found' }, 404))
