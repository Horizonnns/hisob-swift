# Hisob API

Тонкий REST-слой между приложением и Postgres (Neon).

**Hono + Prisma.** Ни фронтенд-фреймворка, ни сборщика, ни рендеринга —
только роутер и обработчики. Запускается как обычный процесс Node
(`npm start`) или разворачивается на Vercel, Cloudflare Workers, Deno,
Bun — приложение работает по HTTP и о платформе ничего не знает.

## Эндпоинты

Все, кроме `/api/health`, требуют заголовок `Authorization: Bearer <HISOB_API_TOKEN>`.

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/api/health` | проверка живости, публичный |
| GET | `/api/diagnostics` | что из настройки не готово: переменные, база, миграции |
| GET | `/api/ledger` | полный срез: валюта, источники, траты |
| POST | `/api/expenses` | создать трату (`id` присылает клиент) |
| PATCH | `/api/expenses/:id` | изменить трату |
| DELETE | `/api/expenses/:id` | удалить трату |
| PUT | `/api/sources/:id` | создать/обновить источник вместе с историей оклада |
| DELETE | `/api/sources/:id` | удалить источник (траты остаются) |
| PATCH | `/api/settings` | сменить валюту |

Особенности:

- **Суммы — строки** (`"1923.63"`). JSON-число клиент прочитал бы в `Double`,
  и двоичная погрешность приехала бы вместе с данными.
- **`id` генерирует клиент.** Приложение создаёт запись оптимистично и должно
  знать идентификатор до ответа сервера.
- **Трата — либо `amount`, либо непустой `items`.** Оба поля сразу или ни
  одного отвергаются с 400.
- **Без токена в окружении API отвечает 503** и не пускает никого. Молчаливого
  запасного значения нет намеренно.

## Устройство

```
src/
├── index.ts            default-экспорт app — точка входа для Vercel
├── server.ts           локальный запуск обычным Node
├── app.ts              все роуты
├── middleware/
│   ├── auth.ts         проверка Bearer-токена, сравнение константное по времени
│   └── validate.ts     zod-валидация с нашей формой ошибки
└── lib/                схемы, маппинг DTO, работа с деньгами, клиент Prisma
```

## Переменные окружения

```
POSTGRES_PRISMA_URL       # пулер, рантайм
POSTGRES_URL_NON_POOLING  # прямое подключение, миграции
HISOB_API_TOKEN           # openssl rand -base64 32
```

## Локальный запуск

```bash
npm install
npx prisma generate
npm run dev          # tsx watch, порт 3200 (или PORT)
```

## Развёртывание

**Vercel** — фреймворк-пресет Hono, точка входа `src/index.ts`,
Root Directory = `api`.

Порядок:

1. Импортировать репозиторий, Root Directory = `api`, пресет Hono.
2. Storage → подключить базу Neon. Переменные подставятся автоматически.
   **Сверьте имена** в Environment Variables: схема ожидает
   `POSTGRES_PRISMA_URL` и `POSTGRES_URL_NON_POOLING`. Если интеграция
   назвала их иначе — добавьте переменные с нужными именами.
3. Добавить `HISOB_API_TOKEN` вручную (`openssl rand -base64 32`).
4. **Передеплоить** — переменные подхватываются только новой сборкой.
5. Применить миграции со своей машины.

   `vercel env pull --environment=production` **не подходит**: Vercel не
   выгружает секреты production и пишет вместо них `[SENSITIVE]`, а Prisma
   отвечает на это невнятной `P1013`. Строки берите в консоли Neon
   (Vercel → Storage → база → Open in Neon → Connection Details) и впишите
   в `api/.env` вручную:

```
POSTGRES_PRISMA_URL="postgresql://…-pooler…?sslmode=require&pgbouncer=true"
POSTGRES_URL_NON_POOLING="postgresql://…?sslmode=require"
```

   Пулерная строка — с `-pooler` в хосте, прямая — без. Затем:

```bash
npm run db:deploy
```

   Перед миграцией прогоняется `db:check`: он отличает заглушку, отсутствие
   переменной и перепутанные местами строки — вместо `P1013` будет понятный
   текст.

Миграции запускаются отдельно от сборки намеренно: откат деплоя не должен
оставлять базу в изменённом состоянии.

6. Проверить: `curl https://<домен>/api/health` → `{"ok":true}`,
   затем диагностику:

```bash
curl -H "Authorization: Bearer <токен>" https://<домен>/api/diagnostics
```

Готовое состояние выглядит так:

```json
{
  "env": { "POSTGRES_PRISMA_URL": true, "POSTGRES_URL_NON_POOLING": true, "HISOB_API_TOKEN": true },
  "database": "connected",
  "migrations": "applied"
}
```

Что означают отклонения:

| Признак | Что делать |
|---|---|
| `POSTGRES_*: false` | переменные не заданы или названы иначе — добавить с нужными именами |
| `database: "unreachable"` | неверные учётные данные или недоступен хост |
| `migrations: "missing"` | соединение есть, таблиц нет — выполнить `prisma migrate deploy` |

Ответы самих роутов: 503 — переменная токена не задана либо база недоступна,
401 — токен не совпал, 200 — всё готово.

### Точка входа

Vercel не бандлит проект: он транспилирует TypeScript в отдельные `.js`
с сохранением ESM-синтаксиса. Точку входа он **ищет по импорту `hono`**
среди файлов в корне `src/`, и каждый файл оттуда считает кандидатом.

Отсюда устройство каталога:

```
src/
├── index.ts        единственный файл в корне: new Hono() + export default handle(app)
└── server/         routes.ts, lib/, middleware/
scripts/serve.ts    локальный запуск, тоже вне src/
```

Четыре требования, на каждом из которых деплой уже падал:

1. **`"type": "module"`** — иначе Node читает транспилированные `.js`
   как CommonJS: `SyntaxError: Cannot use import statement outside a module`.
2. **Точка входа импортирует `hono` и создаёт `new Hono()`.** Если приложение
   собирается в другом модуле, сборка обрывается с
   `No entrypoint found which imports hono`.
3. **В корне `src/` нет ничего, кроме точки входа.** Пока рядом лежал
   `app.ts`, платформа выбирала его и отвечала
   `Invalid export found in module ".../src/app.js"`.
4. **Default-экспорт — обработчик в стиле Node `(req, res)`.** Рантайм зовёт
   его именно так. Веб-обработчик `(Request) => Response` из `hono/vercel`
   молча не пишет ответ, и запрос висит до `FUNCTION_INVOCATION_TIMEOUT`.
   Перевод делает `getRequestListener` из `@hono/node-server`.

Нарушения 1 и 3 дают `FUNCTION_INVOCATION_FAILED` на любом запросе — по коду
их не различить, причину показывают Runtime Logs. Нарушение 2 видно в Build
Logs. Нарушение 4 — это `FUNCTION_INVOCATION_TIMEOUT`, и в логах при нём
не будет вообще ничего: код отработал, просто ответ не записан.

Локальный `tsx` не воспроизводит ничего из этого. Перед деплоем:

```bash
npm run check:bundle
```

Проверка транспилирует дерево как платформа и проверяет все четыре условия.
Обработчик она поднимает настоящим `http.createServer` и делает по нему
запрос: вызов вида `handler(new Request(...))` проходит и на веб-обработчике,
который в проде висит до таймаута.

### Генерация клиента Prisma

`postinstall: prisma generate` обязателен. Пресет Hono не выполняет
Build Command, и без этого хука клиент не генерируется — функция падает
с `FUNCTION_INVOCATION_FAILED` на любом запросе, включая `/api/health`,
потому что импорт `@prisma/client` не проходит.

**Свой сервер** — без всякой платформы:

```bash
npm start            # tsx src/server.ts
```

## Перенос данных из веб-версии

1. Выгрузите старую базу запросом из [`../docs/migration.md`](../docs/migration.md).
2. Примените миграции на новой базе.
3. Запустите импорт:

```bash
npm run import:legacy -- ../legacy-export.json
```

Скрипт идемпотентен: идентификаторы выводятся из содержимого, повторный запуск
дублей не создаёт.
