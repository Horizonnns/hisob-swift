import { getRequestListener } from '@hono/node-server'
import { Hono } from 'hono'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { Readable } from 'node:stream'
import { registerRoutes } from './server/routes.js'

/**
 * Единственная точка входа для платформы.
 *
 * Требования, каждое из которых уже роняло деплой:
 *
 * 1. Файл лежит в корне `src/` и импортирует `hono` — по этому признаку
 *    платформа находит точку входа.
 * 2. В корне `src/` больше ничего нет: каждый файл оттуда тоже считается
 *    точкой входа.
 * 3. Default-экспорт — обработчик в стиле Node `(req, res)`.
 * 4. Тело запроса приходится подкладывать обратно (см. ниже).
 */
const app = registerRoutes(new Hono())
const listener = getRequestListener(app.fetch)

/** Запрос платформы: тело может быть уже прочитано за нас. */
type PlatformRequest = IncomingMessage & { body?: unknown }

export default function handler(request: PlatformRequest, response: ServerResponse) {
	const replayed = replayBody(request)
	return listener(replayed, response)
}

/**
 * Возвращает тело запроса в поток, если платформа прочитала его раньше нас.
 *
 * Vercel разбирает тело и кладёт результат в `req.body`, а исходный поток
 * при этом остаётся пустым и закрытым. Hono читает тело именно из потока
 * и ждёт данных, которых больше не будет, — запрос висит до
 * `FUNCTION_INVOCATION_TIMEOUT`. Заметно это только на POST/PUT/PATCH:
 * запросы без тела проходят нормально.
 */
function replayBody(request: PlatformRequest): IncomingMessage {
	const body = request.body
	if (body === undefined || body === null) return request

	const raw = Buffer.isBuffer(body)
		? body
		: typeof body === 'string'
			? Buffer.from(body, 'utf8')
			: Buffer.from(JSON.stringify(body), 'utf8')

	const headers = { ...request.headers, 'content-length': String(raw.byteLength) }

	// `@hono/node-server` собирает заголовки из `rawHeaders` — плоского
	// списка вида [имя, значение, имя, значение]. Без него запрос падает
	// на чтении длины.
	const rawHeaders: string[] = []
	for (const [name, value] of Object.entries(headers)) {
		if (value === undefined) continue
		for (const single of Array.isArray(value) ? value : [value]) {
			rawHeaders.push(name, single)
		}
	}

	const stream = Readable.from([raw]) as unknown as IncomingMessage
	Object.defineProperties(stream, {
		headers: { value: headers, enumerable: true },
		rawHeaders: { value: rawHeaders, enumerable: true },
		method: { value: request.method, enumerable: true },
		url: { value: request.url, enumerable: true },
		httpVersion: { value: request.httpVersion ?? '1.1', enumerable: true },
		httpVersionMajor: { value: request.httpVersionMajor ?? 1, enumerable: true },
		httpVersionMinor: { value: request.httpVersionMinor ?? 1, enumerable: true },
		complete: { value: true, enumerable: true },
		socket: { value: request.socket, enumerable: true }
	})
	return stream
}
