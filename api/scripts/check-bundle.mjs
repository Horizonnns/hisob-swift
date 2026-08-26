/**
 * Проверяет исходники так же, как их готовит Vercel.
 *
 * Платформа не бандлит проект: она транспилирует TypeScript в отдельные
 * `.js` с сохранением ESM-синтаксиса, а **каждый файл в корне `src/`**
 * считает точкой входа и требует от него default-экспорт в виде функции.
 * Локальный `tsx` этого не воспроизводит совсем.
 *
 * Три условия, на которых деплой уже падал:
 *   1. `"type": "module"` — иначе Node читает транспилированные `.js`
 *      как CommonJS и спотыкается на первом `import`;
 *   2. точка входа импортирует `hono` — по этому признаку платформа её
 *      и находит, иначе сборка обрывается ещё до запуска;
 *   3. в корне `src/` нет файлов, кроме точек входа;
 *   4. каждая такая точка экспортирует по умолчанию функцию-обработчик
 *      в нодовском соглашении `(req, res)` — проверяем настоящим запросом
 *      через `http.createServer`, а не вызовом с `Request`: именно на этом
 *      различии функция висела до таймаута, а проверка молчала.
 *
 * Запуск: npm run check:bundle
 */
import { execFileSync } from 'node:child_process'
import http from 'node:http'
import { cpSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

/** Все `.ts` в дереве — рекурсивно. */
function collectSources(directory) {
	return readdirSync(directory, { withFileTypes: true }).flatMap(item => {
		const path = join(directory, item.name)
		if (item.isDirectory()) return collectSources(path)
		return item.name.endsWith('.ts') ? [path] : []
	})
}

const workDir = mkdtempSync(join(tmpdir(), 'hisob-check-'))

try {
	// 1. Формат модулей. Проверяем поле явно, а не через попытку запуска:
	// свежий Node сам перечитывает файл как ESM, лишь предупредив, а рантайм
	// Vercel бросает SyntaxError — на локальное поведение полагаться нельзя.
	const manifest = JSON.parse(readFileSync('package.json', 'utf8'))
	if (manifest.type !== 'module') {
		throw new Error(
			'В package.json должно быть "type": "module" — Vercel транспилирует ' +
			'исходники в .js с сохранением import-синтаксиса и запускает их как ESM.'
		)
	}

	// 2. Что платформа увидит как точки входа.
	const entryNames = readdirSync('src', { withFileTypes: true })
		.filter(item => item.isFile() && item.name.endsWith('.ts'))
		.map(item => item.name)

	if (entryNames.length === 0) {
		throw new Error('В корне src/ нет ни одной точки входа')
	}

	// Платформа находит точку входа по импорту `hono`. Проверяем по тексту:
	// после транспиляции этот импорт уже неотличим от прочих.
	const importsHono = entryNames.some(name => {
		const source = readFileSync(join('src', name), 'utf8')
		return /from\s+['"]hono['"]/.test(source)
	})

	if (!importsHono) {
		throw new Error(
			'Ни одна точка входа в src/ не импортирует "hono". Платформа находит ' +
			'её именно по этому признаку и иначе обрывает сборку с ' +
			'"No entrypoint found which imports hono". Создавайте new Hono() ' +
			'в точке входа, а не в отдельном модуле.'
		)
	}

	// Транспилируем всё дерево пофайлово — как платформа.
	// Список файлов собираем сами: на раскрытие глоба шеллом полагаться нельзя.
	const sources = collectSources('src')
	execFileSync(
		'npx',
		[
			'esbuild', ...sources,
			'--format=esm', '--platform=node',
			`--outdir=${workDir}`, '--outbase=src'
		],
		{ stdio: 'pipe' }
	)

	cpSync('package.json', join(workDir, 'package.json'))
	symlinkSync(resolve('node_modules'), join(workDir, 'node_modules'), 'dir')

	// 3. Каждая точка входа должна отдавать функцию-обработчик.
	for (const name of entryNames) {
		const jsName = name.replace(/\.ts$/, '.js')
		const module = await import(pathToFileURL(join(workDir, jsName)).href)
		const handler = module.default

		if (typeof handler !== 'function') {
			throw new Error(
				`src/${name}: default-экспорт должен быть функцией-обработчиком, ` +
				`получено: ${typeof handler}. Либо оберните приложение в handle() ` +
				'из hono/vercel, либо унесите файл из корня src/ — платформа ' +
				'считает точкой входа каждый файл верхнего уровня.'
			)
		}
	}

	// Точка входа должна отвечать на настоящий HTTP-запрос.
	// Поднимаем обычный http-сервер поверх экспорта — так же его вызывает
	// рантайм. Вызов вида `handler(new Request(...))` тут не годится: он
	// проходит и на веб-обработчике, который в проде висит до таймаута.
	const entry = await import(pathToFileURL(join(workDir, 'index.js')).href)
	const server = http.createServer(entry.default)
	await new Promise(resolve => server.listen(0, resolve))
	const { port } = server.address()

	try {
		const controller = new AbortController()
		const timer = setTimeout(() => controller.abort(), 5000)
		let response
		try {
			response = await fetch(`http://127.0.0.1:${port}/api/health`, {
				signal: controller.signal
			})
		} catch (cause) {
			if (cause?.name === 'AbortError') {
				throw new Error(
					'Точка входа не ответила за 5 секунд. Скорее всего default-экспорт — ' +
					'веб-обработчик (Request) => Response, а рантайм зовёт его как (req, res). ' +
					'Используйте getRequestListener из @hono/node-server.'
				)
			}
			throw cause
		} finally {
			clearTimeout(timer)
		}

		if (response.status !== 200) {
			throw new Error(`/api/health вернул ${response.status}, ожидался 200`)
		}
	} finally {
		server.close()
	}

	console.log(
		`Точек входа в src/: ${entryNames.join(', ')} — все отдают обработчик, ` +
		'/api/health отвечает 200.'
	)
} catch (cause) {
	const message = cause?.stderr?.toString() || cause?.message || String(cause)
	console.error('Проверка не прошла:\n' + message)
	process.exit(1)
} finally {
	rmSync(workDir, { recursive: true, force: true })
}
