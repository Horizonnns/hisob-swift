/**
 * Общие ответы об ошибках.
 *
 * Текст исключения Prisma наружу не отдаётся: он раскрывает структуру базы.
 */
export const ERROR_MESSAGES = {
	internal: 'Internal error',
	unauthorized: 'Unauthorized',
	tokenNotConfigured: 'HISOB_API_TOKEN is not configured',
	invalidBody: 'Invalid body'
} as const
