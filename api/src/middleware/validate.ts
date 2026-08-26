import { zValidator } from '@hono/zod-validator'
import type { ZodType } from 'zod'
import { ERROR_MESSAGES } from '../lib/http.js'

/**
 * `zValidator` с нашей формой ошибки: `{ error: "<первая проблема>" }` и 400.
 *
 * Обёртка нужна, чтобы форма ответа не зависела от версии валидатора —
 * по ней клиент показывает пользователю текст.
 */
export function validateJSON<T extends ZodType>(schema: T) {
	return zValidator('json', schema, (result, c) => {
		if (!result.success) {
			const message = result.error.issues[0]?.message ?? ERROR_MESSAGES.invalidBody
			return c.json({ error: message }, 400)
		}
	})
}
