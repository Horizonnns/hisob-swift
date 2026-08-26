import { timingSafeEqual } from 'node:crypto'
import { createMiddleware } from 'hono/factory'
import { ERROR_MESSAGES } from '../lib/http.js'

/**
 * Проверяет заголовок `Authorization: Bearer <token>`.
 *
 * Если `HISOB_API_TOKEN` не задан — 503, и не пускаем никого. Молчаливого
 * запасного значения здесь нет намеренно: незаданная переменная на проде
 * не должна превращаться в открытый доступ.
 */
export const requireToken = createMiddleware(async (c, next) => {
	const expected = process.env.HISOB_API_TOKEN

	if (!expected) {
		return c.json({ error: ERROR_MESSAGES.tokenNotConfigured }, 503)
	}

	const header = c.req.header('authorization') ?? ''
	const prefix = 'Bearer '
	if (!header.startsWith(prefix)) {
		return c.json({ error: ERROR_MESSAGES.unauthorized }, 401)
	}

	if (!constantTimeEquals(header.slice(prefix.length), expected)) {
		return c.json({ error: ERROR_MESSAGES.unauthorized }, 401)
	}

	await next()
})

/** Сравнение без утечки длины и позиции первого различия. */
function constantTimeEquals(a: string, b: string): boolean {
	const left = Buffer.from(a, 'utf8')
	const right = Buffer.from(b, 'utf8')
	if (left.length !== right.length) {
		// timingSafeEqual требует равной длины; сравниваем с самим собой,
		// чтобы затраты времени не зависели от длины присланного токена.
		timingSafeEqual(left, left)
		return false
	}
	return timingSafeEqual(left, right)
}
