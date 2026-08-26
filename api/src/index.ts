import { handle } from 'hono/vercel'
import { app } from './app.js'

/**
 * Точка входа для Vercel.
 *
 * Именно `handle(app)`, а не сам `app`: рантайм ожидает от default-экспорта
 * функцию-обработчик, а экземпляр Hono — объект. На объект платформа отвечает
 * `Invalid export` и падает с `FUNCTION_INVOCATION_FAILED` на любом запросе.
 * Адаптер оборачивает приложение в `(req) => app.fetch(req)`.
 */
export default handle(app)
