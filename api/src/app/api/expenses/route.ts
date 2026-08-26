import { expenseToDTO } from '@/lib/dto'
import { error, json, withAuth } from '@/lib/http'
import { dateFromString, moneyFromString } from '@/lib/money'
import { prisma } from '@/lib/prisma'
import { expenseSchema } from '@/lib/schemas'

export const dynamic = 'force-dynamic'

/**
 * Создание траты.
 *
 * `id` приходит от клиента: приложение создаёт запись оптимистично и должно
 * знать её идентификатор до ответа сервера.
 */
export const POST = withAuth(async request => {
	const parsed = expenseSchema.safeParse(await request.json().catch(() => null))
	if (!parsed.success) {
		return error(parsed.error.issues[0]?.message ?? 'Invalid body', 400)
	}
	const input = parsed.data

	const existing = await prisma.expense.findUnique({
		where: { id: input.id },
		select: { id: true }
	})
	if (existing) return error('Expense already exists', 409)

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

	return json(expenseToDTO(created), 201)
})
