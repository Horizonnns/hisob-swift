import { sourceToDTO } from '@/lib/dto'
import { error, json, withAuth } from '@/lib/http'
import { dateFromString, moneyFromString } from '@/lib/money'
import { prisma } from '@/lib/prisma'
import { incomeSourceSchema } from '@/lib/schemas'

export const dynamic = 'force-dynamic'

type Context = { params: Promise<{ id: string }> }

/**
 * Создание или обновление источника вместе с историей оклада.
 *
 * PUT, а не PATCH: история оклада редактируется в приложении целиком, и
 * клиент присылает её окончательный вид.
 */
export const PUT = withAuth(async (request, context: Context) => {
	const { id } = await context.params
	const parsed = incomeSourceSchema.safeParse(await request.json().catch(() => null))
	if (!parsed.success) {
		return error(parsed.error.issues[0]?.message ?? 'Invalid body', 400)
	}
	const input = parsed.data
	if (input.id !== id) return error('Body id does not match path id', 400)

	const fields = {
		name: input.name,
		role: input.role,
		endedAt: input.endedAt
	}

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

	return json(sourceToDTO(upserted))
})

/**
 * Удаление источника. Траты остаются: привязка к работе была лишь пометкой,
 * и обнуляется она через `onDelete: SetNull` в схеме.
 */
export const DELETE = withAuth(async (_request, context: Context) => {
	const { id } = await context.params
	const removed = await prisma.incomeSource.deleteMany({ where: { id } })
	if (removed.count === 0) return error('Income source not found', 404)
	return json({ ok: true })
})
