import { getRequestListener } from '@hono/node-server'
import { Hono } from 'hono'
import { registerRoutes } from './server/routes.js'

/**
 * Единственная точка входа для платформы.
 *
 * Требования, каждое из которых уже роняло деплой:
 *
 * 1. Файл лежит в корне `src/` и импортирует `hono` — по этому признаку
 *    платформа находит точку входа. Иначе сборка обрывается с
 *    `No entrypoint found which imports hono`.
 * 2. В корне `src/` больше ничего нет: каждый файл оттуда тоже считается
 *    точкой входа и обязан иметь подходящий default-экспорт.
 * 3. Default-экспорт — обработчик в стиле Node: `(req, res)`. Рантайм зовёт
 *    его именно так. Веб-обработчик `(Request) => Response` из `hono/vercel`
 *    получает `(IncomingMessage, ServerResponse)`, в `res` никто не пишет,
 *    и запрос висит до `FUNCTION_INVOCATION_TIMEOUT`.
 *
 * `getRequestListener` переводит `app.fetch` в нодовское соглашение.
 */
const app = registerRoutes(new Hono())

export default getRequestListener(app.fetch)
