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
 *   2. в корне `src/` нет файлов, кроме точек входа;
 *   3. каждая такая точка экспортирует по умолчанию функцию-обработчик.
 *
 * Запуск: npm run check:bundle
 */
import { execFileSync } from 'node:child_process'
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

	// Точка входа должна ещё и отвечать.
	const entry = await import(pathToFileURL(join(workDir, 'index.js')).href)
	const response = await entry.default(new Request('https://check.local/api/health'))
	if (response.status !== 200) {
		throw new Error(`/api/health вернул ${response.status}, ожидался 200`)
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
