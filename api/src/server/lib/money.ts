import { Prisma } from '@prisma/client'

/**
 * Суммы ходят по сети строками.
 *
 * JSON-числа читаются клиентом как `Double`, и двоичная погрешность приезжает
 * вместе с данными. На стороне Swift сумма разбирается в `Decimal` из строки.
 */
export function moneyToString(value: Prisma.Decimal): string {
	return value.toFixed(2)
}

export function moneyFromString(value: string): Prisma.Decimal {
	return new Prisma.Decimal(value)
}

/** Дата хранится как календарный день без времени: «2026-08-02». */
export function dateToString(value: Date): string {
	return value.toISOString().slice(0, 10)
}

/** Полдень UTC, чтобы сдвиг часового пояса не увёл день на соседний. */
export function dateFromString(value: string): Date {
	return new Date(`${value}T12:00:00.000Z`)
}
