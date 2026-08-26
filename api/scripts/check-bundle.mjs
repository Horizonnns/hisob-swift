/**
 * Проверяет точку входа так же, как её готовит Vercel.
 *
 * Платформа не бандлит проект: она транспилирует TypeScript в отдельные
 * `.js`-файлы с сохранением ESM-синтаксиса и запускает их обычным Node.
 * Локальный `tsx` этого не воспроизводит — он резолвит модули на лету,
 * поэтому ошибки формата модулей и экспорта видны только в проде.
 *
 * Проверяем два условия, на которых деплой уже падал:
 *   1. транспилированные файлы загружаются как ESM;
 *   2. default-экспорт — функция-обработчик, а не объект Hono.
 *
 * Запуск: npm run check:bundle
 */
import { execFileSync } from 'node:child_process'
import { cpSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const workDir = mkdtempSync(join(tmpdir(), 'hisob-check-'))

try {
	// Проверяем поле явно, а не через попытку запуска: свежий Node сам
	// перечитывает файл как ESM, лишь предупредив, а рантайм Vercel
	// бросает SyntaxError. Полагаться на поведение локального Node нельзя.
	const manifest = JSON.parse(readFileSync('package.json', 'utf8'))
	if (manifest.type !== 'module') {
		throw new Error(
			'В package.json должно быть "type": "module" — Vercel транспилирует ' +
			'исходники в .js с сохранением import-синтаксиса и запускает их как ESM.'
		)
	}

	execFileSync(
		'npx',
		[
			'esbuild',
			'src/index.ts', 'src/app.ts', 'src/server.ts',
			'src/lib/dto.ts', 'src/lib/http.ts', 'src/lib/money.ts',
			'src/lib/prisma.ts', 'src/lib/schemas.ts',
			'src/middleware/auth.ts', 'src/middleware/validate.ts',
			'--format=esm', '--platform=node',
			`--outdir=${workDir}`, '--outbase=src'
		],
		{ stdio: 'pipe' }
	)

	// package.json задаёт `type: module`, node_modules нужен для резолва.
	cpSync('package.json', join(workDir, 'package.json'))
	symlinkSync(resolve('node_modules'), join(workDir, 'node_modules'), 'dir')

	const entry = await import(pathToFileURL(join(workDir, 'index.js')).href)
	const handler = entry.default

	if (typeof handler !== 'function') {
		throw new Error(
			`default-экспорт должен быть функцией-обработчиком, получено: ${typeof handler}. ` +
			'Оберните приложение в handle() из hono/vercel.'
		)
	}

	const response = await handler(new Request('https://check.local/api/health'))
	if (response.status !== 200) {
		throw new Error(`/api/health вернул ${response.status}, ожидался 200`)
	}

	console.log('Точка входа загружается как ESM и отдаёт обработчик — деплой не упадёт на старте.')
} catch (cause) {
	const message = cause?.stderr?.toString() || cause?.message || String(cause)
	console.error('Проверка не прошла:\n' + message)
	process.exit(1)
} finally {
	rmSync(workDir, { recursive: true, force: true })
}
