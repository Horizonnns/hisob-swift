import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

/** Единственный публичный роут: проверка, что деплой жив. Данных не отдаёт. */
export function GET() {
	return NextResponse.json({ ok: true })
}
