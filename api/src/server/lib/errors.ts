/**
 * Отличает проблемы с подключением к базе от прочих ошибок.
 *
 * Общее `Internal error` наружу отдаётся намеренно — текст исключения Prisma
 * раскрывает структуру базы. Но недоступность самой базы ничего не
 * раскрывает, а различать «сервер сломан» и «база не подключена» на этапе
 * настройки критично: иначе единственный способ узнать причину — Runtime Logs.
 */
export function isDatabaseUnavailable(cause: unknown): boolean {
	if (typeof cause !== 'object' || cause === null) return false

	const error = cause as { name?: string; errorCode?: string; code?: string; message?: string }

	// Не заданы или неверны переменные подключения, недоступен хост.
	if (error.name === 'PrismaClientInitializationError') return true

	// P1000 — не прошла аутентификация, P1001 — хост недоступен,
	// P1002 — таймаут, P1003 — базы не существует, P1017 — сервер закрыл соединение.
	const code = error.errorCode ?? error.code
	if (code && ['P1000', 'P1001', 'P1002', 'P1003', 'P1017'].includes(code)) return true

	// Переменная окружения не найдена — Prisma сообщает об этом текстом.
	return typeof error.message === 'string'
		&& error.message.includes('Environment variable not found')
}
