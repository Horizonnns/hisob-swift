import { timingSafeEqual } from 'node:crypto'

/**
 * Результат проверки доступа: либо всё в порядке, либо готовый ответ с ошибкой.
 */
export type AuthFailure = { status: number; error: string }

/**
 * Проверяет заголовок `Authorization: Bearer <token>`.
 *
 * Если `HISOB_API_TOKEN` не задан — API отвечает 503 и не пускает никого.
 * Молчаливого запасного значения здесь нет намеренно: незаданная переменная
 * на проде не должна превращаться в открытый доступ.
 */
export function checkAuth(request: Request): AuthFailure | null {
	const expected = process.env.HISOB_API_TOKEN

	if (!expected) {
		return { status: 503, error: 'HISOB_API_TOKEN is not configured' }
	}

	const header = request.headers.get('authorization') ?? ''
	const prefix = 'Bearer '
	if (!header.startsWith(prefix)) {
		return { status: 401, error: 'Unauthorized' }
	}

	const provided = header.slice(prefix.length)
	if (!constantTimeEquals(provided, expected)) {
		return { status: 401, error: 'Unauthorized' }
	}

	return null
}

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
