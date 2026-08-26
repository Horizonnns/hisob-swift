import { NextResponse } from 'next/server'
import { checkAuth } from './auth'

export function json(data: unknown, status = 200) {
	return NextResponse.json(data, { status })
}

export function error(message: string, status: number) {
	return NextResponse.json({ error: message }, { status })
}

/**
 * Оборачивает обработчик: проверяет токен и превращает исключения в 500.
 *
 * Наружу отдаётся общее сообщение — текст исключения Prisma раскрывает
 * структуру базы и в ответ попадать не должен.
 */
export function withAuth<T extends unknown[]>(
	handler: (request: Request, ...args: T) => Promise<Response>
) {
	return async (request: Request, ...args: T): Promise<Response> => {
		const failure = checkAuth(request)
		if (failure) return error(failure.error, failure.status)

		try {
			return await handler(request, ...args)
		} catch (cause) {
			console.error('API error:', cause)
			return error('Internal error', 500)
		}
	}
}
