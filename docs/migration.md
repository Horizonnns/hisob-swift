# Перенос данных из прода

Источник — Postgres (Neon) веб-версии. Таблицы: `Project`, `SalaryEntry`,
`Expense`, `ExpenseItem`.

## Выгрузка

```sql
SELECT jsonb_pretty(jsonb_agg(payload))
FROM (
  SELECT jsonb_build_object(
    'slug',     p.slug,
    'role',     p.role,
    'currency', p.currency,
    'salaries', (
      SELECT coalesce(jsonb_agg(
        jsonb_build_object(
          'from',   s."from",
          'amount', (s.amount::numeric)::text
        ) ORDER BY s."from"
      ), '[]'::jsonb)
      FROM "SalaryEntry" s WHERE s."projectId" = p.id
    ),
    'expenses', (
      SELECT coalesce(jsonb_agg(
        jsonb_build_object(
          'id',       e.id,
          'date',     e.date,
          'category', e.category,
          'title',    e.description,
          'amount',   (e.amount::numeric)::text,
          'items',    (
            SELECT coalesce(jsonb_agg(
              jsonb_build_object(
                'amount', (i.amount::numeric)::text,
                'title',  i.description
              )
            ), '[]'::jsonb)
            FROM "ExpenseItem" i WHERE i."expenseId" = e.id
          )
        ) ORDER BY e.date
      ), '[]'::jsonb)
      FROM "Expense" e WHERE e."projectId" = p.id
    )
  ) AS payload
  FROM "Project" p
) t;
```

Суммы выгружаются **строками** (`::numeric)::text`), а не числами. В базе они
объявлены как `Float`; если отдать их числом, JSON-декодер прочитает их в
`Double` и двоичная погрешность приедет вместе с данными. Строка разбирается
через `Money.parse(_:)` точно.

## Правила преобразования

| Прод | Hisob |
|---|---|
| `Project` | `IncomeSource` (`name` = slug, `role` = role) |
| `SalaryEntry.from` | `SalaryEntry.effectiveFrom` |
| `Expense.description` | `Expense.title` |
| `Expense.category` («Еда») | `ExpenseCategory(legacyName:)` → `.food` |
| `Expense` без позиций | `.single(amount)` |
| `Expense` с позициями | `.group(items)`, сумма пересчитывается из позиций |
| `Expense.projectId` | отбрасывается — трата становится личной |
| `Project.currency` | `Ledger.currency`, одна на все источники |

## Импорт

Готовый скрипт: [`../api/scripts/import-legacy.ts`](../api/scripts/import-legacy.ts).
Он делает всё из таблицы выше, проставляет `endedAt` и выводит контрольные
цифры. Идентификаторы выводятся из содержимого, поэтому повторный запуск
на том же файле дублей не создаёт.

```bash
cd api && npx tsx scripts/import-legacy.ts ../legacy-export.json
```

## Ручные правки после импорта

1. `asrmall.endedAt = 2026-07` — работа завершена в июле 2026. Уже прописано
   в скрипте импорта (таблица `ENDED_AT`).
2. `OD.endedAt = nil` — текущая работа.
3. Проверить перекрытие июнь–июль 2026: оклад OD действует с 10 июня, значит
   в эти два месяца доход шёл с обоих источников. Если фактически это не так —
   сдвинуть `endedAt` asrmall.
4. Сверить контрольные цифры за август 2026: доход 10 120, потрачено 9 862,92,
   остаток 257,08 (значения с текущего экрана веб-версии).

Пункт 4 важен: после объединения цепочки переноса в одну **«Перенос» и «Остаток»
за месяцы OD изменятся** — теперь в них входит период asrmall. Это ожидаемо,
но проверить стоит именно «Потрачено» и «Оклад», которые меняться не должны.
