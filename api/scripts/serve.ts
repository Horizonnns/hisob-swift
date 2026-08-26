import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { registerRoutes } from '../src/server/routes.js'

/**
 * Локальный запуск обычным Node — без Vercel и вообще без платформы.
 * Тот же `app`, что уходит в деплой.
 *
 * Лежит в `scripts/`, а не в `src/`: всё в корне `src/` платформа считает
 * точкой входа и требует default-экспорт функции.
 */
const app = registerRoutes(new Hono())
const port = Number(process.env.PORT ?? 3200)

serve({ fetch: app.fetch, port }, info => {
	console.log(`Hisob API слушает http://localhost:${info.port}`)
})
