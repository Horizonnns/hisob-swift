import { expenseToDTO, sourceToDTO } from '@/lib/dto'
import { json, withAuth } from '@/lib/http'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

/**
 * Полный срез данных.
 *
 * Отдаётся целиком, а не по месяцам: расчёт переноса остатка требует всей
 * истории трат. Объём для одного пользователя за годы — сотни килобайт,
 * приложение забирает его один раз и дальше живёт на локальном кэше.
 */
export const GET = withAuth(async () => {
	const [settings, sources, expenses] = await Promise.all([
		prisma.settings.findUnique({ where: { id: 'singleton' } }),
		prisma.incomeSource.findMany({
			include: { salaries: true },
			orderBy: { name: 'asc' }
		}),
		prisma.expense.findMany({
			include: { items: true },
			orderBy: { date: 'asc' }
		})
	])

	return json({
		currency: settings?.currency ?? 'TJS',
		sources: sources.map(sourceToDTO),
		expenses: expenses.map(expenseToDTO)
	})
})
