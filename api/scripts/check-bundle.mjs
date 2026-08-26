/**
 * Проверяет, что точка входа переживает сборку бандлером.
 *
 * Vercel не запускает `tsx`, а собирает `src/index.ts` в один файл. Локально
 * этого не видно: `tsx` резолвит модули на лету, и несовместимости CommonJS
 * с ESM не проявляются. Один раз мы уже потеряли на этом деплой —
 * `@prisma/client` внутри CommonJS, и в ESM-бандле его `require` падал
 * с «Dynamic require of "node:fs" is not supported».
 *
 * Запуск: npm run check:bundle
 */
import { execFileSync } from 'node:child_process'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createRequire } from 'node:module'

const workDir = mkdtempSync(join(tmpdir(), 'hisob-bundle-'))
const outFile = join(workDir, 'bundle.cjs')

try {
	execFileSync(
		'npx',
		['esbuild', 'src/index.ts', '--bundle', '--platform=node', `--outfile=${outFile}`],
		{ stdio: 'pipe' }
	)

	const require = createRequire(import.meta.url)
	const bundled = require(outFile)
	const app = bundled.default ?? bundled

	if (typeof app?.fetch !== 'function') {
		throw new Error('Собранная точка входа не экспортирует приложение Hono')
	}

	console.log('Бандл собирается и импортируется — деплой не упадёт на старте.')
} catch (cause) {
	const message = cause?.stderr?.toString() || cause?.message || String(cause)
	console.error('Проверка бандла не прошла:\n' + message)
	process.exit(1)
} finally {
	rmSync(workDir, { recursive: true, force: true })
}
