import { handle } from 'hono/vercel'
import { app } from './server/app.js'

/**
 * Единственная точка входа для платформы.
 *
 * В корне `src/` намеренно нет других файлов: Vercel считает точкой входа
 * каждый файл верхнего уровня и требует от него default-экспорт в виде
 * функции. Раньше рядом лежал `app.ts` с одним лишь именованным экспортом —
 * платформа отвечала `Invalid export found in module ".../src/app.js"` и
 * падала с `FUNCTION_INVOCATION_FAILED` на любом запросе.
 *
 * `handle(app)` оборачивает приложение в `(req) => app.fetch(req)` —
 * рантайм ждёт функцию, а не экземпляр Hono.
 */
export default handle(app)
