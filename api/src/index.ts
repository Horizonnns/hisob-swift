import { Hono } from 'hono'
import { handle } from 'hono/vercel'
import { registerRoutes } from './server/routes.js'

/**
 * Единственная точка входа для платформы.
 *
 * Vercel ищет её по признаку «файл импортирует `hono`» — поэтому
 * `new Hono()` создаётся здесь, а не в модуле с роутами. Пока приложение
 * создавалось в `src/app.ts`, платформа выбирала точкой входа его и падала
 * на отсутствующем default-экспорте; после переноса кандидатов не осталось
 * вовсе, и сборка обрывалась с `No entrypoint found which imports hono`.
 *
 * В корне `src/` намеренно нет других файлов: каждый из них платформа
 * тоже считает точкой входа.
 *
 * `handle(app)` оборачивает приложение в `(req) => app.fetch(req)` —
 * рантайм ждёт функцию, а не экземпляр Hono.
 */
const app = registerRoutes(new Hono())

export default handle(app)
