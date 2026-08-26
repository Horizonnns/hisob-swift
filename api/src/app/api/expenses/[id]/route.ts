import { expenseToDTO } from '@/lib/dto'
import { error, json, withAuth } from '@/lib/http'
import { dateFromString, moneyFromString } from '@/lib/money'
import { prisma } from '@/lib/prisma'
import { expenseSchema } from '@/lib/schemas'

export const dynamic = 'force-dynamic'

type Context = { params: Promise<{ id: string }> }

export const PATCH = withAuth(async (request, context: Context) => {
	const { id } = await context.params
	const parsed = expenseSchema.safeParse(await request.json().catch(() => null))
	if (!parsed.success) {
		return error(parsed.error.issues[0]?.message ?? 'Invalid body', 400)
	}
	const input = parsed.data
	if (input.id !== id) return error('Body id does not match path id', 400)

	const existing = await prisma.expense.findUnique({
		where: { id },
		select: { id: true }
	})
	if (!existing) return error('Expense not found', 404)

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

	return json(expenseToDTO(updated))
})

export const DELETE = withAuth(async (_request, context: Context) => {
	const { id } = await context.params
	const removed = await prisma.expense.deleteMany({ where: { id } })
	if (removed.count === 0) return error('Expense not found', 404)
	return json({ ok: true })
})
