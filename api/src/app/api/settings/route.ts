import { json, error, withAuth } from '@/lib/http'
import { prisma } from '@/lib/prisma'
import { settingsSchema } from '@/lib/schemas'

export const dynamic = 'force-dynamic'

export const PATCH = withAuth(async request => {
	const parsed = settingsSchema.safeParse(await request.json().catch(() => null))
	if (!parsed.success) {
		return error(parsed.error.issues[0]?.message ?? 'Invalid body', 400)
	}

	const settings = await prisma.settings.upsert({
		where: { id: 'singleton' },
		create: { id: 'singleton', currency: parsed.data.currency },
		update: { currency: parsed.data.currency }
	})

	return json({ currency: settings.currency })
})
