import { serve } from '@hono/node-server'
import { app } from './app.js'

/**
 * Локальный запуск обычным Node — без Vercel и вообще без платформы.
 * Тот же `app`, что уходит в деплой.
 */
const port = Number(process.env.PORT ?? 3200)

serve({ fetch: app.fetch, port }, info => {
	console.log(`Hisob API слушает http://localhost:${info.port}`)
})
