/**
 * Проверяет строки подключения до запуска миграций.
 *
 * Prisma на неверном значении отвечает `P1013: The scheme is not recognized`,
 * по которому непонятно, что именно не так. Самый частый случай:
 * `vercel env pull --environment=production` не отдаёт секреты и пишет
 * вместо них literal `[SENSITIVE]`.
 *
 * Запускается автоматически перед `npm run db:deploy`.
 */
const REQUIRED = {
	POSTGRES_PRISMA_URL: 'пулерное подключение (хост с "-pooler"), рантайм',
	POSTGRES_URL_NON_POOLING: 'прямое подключение (хост без "-pooler"), миграции'
}

const problems = []

for (const [name, purpose] of Object.entries(REQUIRED)) {
	const value = process.env[name]

	if (!value) {
		problems.push(`${name} не задана — ${purpose}`)
		continue
	}
	if (value === '[SENSITIVE]') {
		problems.push(
			`${name} равна "[SENSITIVE]" — это заглушка от \`vercel env pull\`. ` +
			'Секреты production через CLI не выгружаются: возьмите строку в консоли Neon ' +
			'и впишите её в .env вручную.'
		)
		continue
	}
	if (!/^postgres(ql)?:\/\//.test(value)) {
		problems.push(`${name} не похожа на строку подключения — ${purpose}`)
	}
}

// Перепутанные местами строки — миграции пойдут через пулер и упадут неявно.
const pooled = process.env.POSTGRES_PRISMA_URL ?? ''
const direct = process.env.POSTGRES_URL_NON_POOLING ?? ''
if (problems.length === 0) {
	if (!pooled.includes('-pooler')) {
		problems.push('POSTGRES_PRISMA_URL должна указывать на пулер — в хосте ожидается "-pooler"')
	}
	if (direct.includes('-pooler')) {
		problems.push(
			'POSTGRES_URL_NON_POOLING указывает на пулер. Миграции требуют прямого ' +
			'подключения — возьмите строку с хостом без "-pooler".'
		)
	}
}

if (problems.length > 0) {
	console.error('Строки подключения не готовы:\n' + problems.map(p => '  • ' + p).join('\n'))
	process.exit(1)
}

console.log('Строки подключения выглядят корректно.')
