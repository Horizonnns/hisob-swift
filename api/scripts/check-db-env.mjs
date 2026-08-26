/**
 * Проверяет строки подключения до запуска миграций.
 *
 * Prisma на неверном значении отвечает `P1013` или `P1001` с URL-кодированным
 * хостом (`%E2%80%A6` — это многоточие), по которым причина не читается.
 * Здесь ошибки называются словами.
 *
 * Запускается автоматически перед `npm run db:deploy`.
 */
const REQUIRED = {
	POSTGRES_PRISMA_URL: {
		purpose: 'пулерное подключение, рантайм',
		pooled: true
	},
	POSTGRES_URL_NON_POOLING: {
		purpose: 'прямое подключение, миграции',
		pooled: false
	}
}

/** Символы и слова, которые остаются от незаполненного шаблона. */
const PLACEHOLDERS = ['…', '...', '<', '>', 'USER', 'PASSWORD', 'HOST', 'example.com']

const problems = []

for (const [name, { purpose, pooled }] of Object.entries(REQUIRED)) {
	const value = process.env[name]

	if (!value) {
		problems.push(`${name} не задана — ${purpose}`)
		continue
	}

	if (value === '[SENSITIVE]') {
		problems.push(
			`${name} равна "[SENSITIVE]" — заглушка от \`vercel env pull\`. Секреты ` +
			'production через CLI не выгружаются: возьмите строку в консоли Neon.'
		)
		continue
	}

	const leftover = PLACEHOLDERS.filter(mark => value.includes(mark))
	if (leftover.length > 0) {
		problems.push(
			`${name} содержит незаполненные места (${leftover.join(', ')}) — это шаблон ` +
			'из документации, а не настоящая строка. Скопируйте её целиком в консоли Neon.'
		)
		continue
	}

	if (!/^postgres(ql)?:\/\//.test(value)) {
		problems.push(`${name} не начинается с postgresql:// — ${purpose}`)
		continue
	}

	// Настоящая строка Neon содержит учётные данные и доменный хост.
	const match = value.match(/^postgres(?:ql)?:\/\/([^:]+):([^@]+)@([^/?]+)/)
	if (!match) {
		problems.push(
			`${name} без учётных данных. Ожидается вид ` +
			'postgresql://пользователь:пароль@хост/база?параметры'
		)
		continue
	}

	const host = match[3]
	if (!host.includes('.')) {
		problems.push(`${name}: "${host}" не похож на хост Neon`)
		continue
	}

	if (pooled && !host.includes('-pooler')) {
		problems.push(
			`${name} должна указывать на пулер — в хосте ожидается "-pooler". ` +
			`Сейчас: ${host}`
		)
	}
	if (!pooled && host.includes('-pooler')) {
		problems.push(
			`${name} указывает на пулер, а миграциям нужно прямое подключение — ` +
			`возьмите строку с хостом без "-pooler". Сейчас: ${host}`
		)
	}
}

if (problems.length > 0) {
	console.error('Строки подключения не готовы:\n' + problems.map(p => '  • ' + p).join('\n'))
	process.exit(1)
}

console.log('Строки подключения выглядят корректно.')
