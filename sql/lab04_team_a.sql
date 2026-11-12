-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 4. ЛАБОРАТОРНАЯ РАБОТА: «Группирование и агрегирование данных»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab04_team_a.sql
-- Исполнители: Команда А «Финансы и продажи»
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Дата среза данных: 31.12.2025
-- ============================================================================

SET search_path TO pitanie, public;

-- ============================================================================
-- ОБЩАЯ ЧАСТЬ: ЕДИНЫЕ БИЗНЕС-ФОРМУЛЫ КОМАНДЫ
-- ============================================================================
/*
1. Выручка строки заказа (без отменённых):
   oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)
   Условие фильтрации: WHERE o.status <> 'Отменён'

2. Сумма скидки строки заказа (в рублях):
   oi.quantity * oi.unit_price * oi.discount_pct / 100.0

3. Взвешенная средняя скидка (%):
   100.0 * SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0) / NULLIF(SUM(oi.quantity * oi.unit_price), 0)

4. Процент брака (для Команды Б):
   100.0 * SUM(defect_qty) / SUM(produced_qty)

5. Коэффициент перерасхода сырья (для Команды Б):
   SUM(mc.quantity) / SUM(r.qty_per_unit * b.produced_qty)
*/


-- ============================================================================
-- ВАРИАНТ 1 — КОМАНДА А «ФИНАНСЫ И ПРОДАЖИ»
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Задание А1. Скидки по менеджерам
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка результата = один менеджер по продажам (orders.employee_id).
-- Проверка: 9 менеджеров; после HAVING — 1 строка;
-- у лидера скидок на 38,78 млн руб.; «сверх политики» — 17,27 млн руб.

-- 1. Полный рейтинг менеджеров по продажам (9 строк):
SELECT 
    e.employee_id,
    e.full_name AS manager_name,
    COUNT(DISTINCT o.order_id) AS orders_count,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) / 1e6, 2) AS revenue_mln,
    ROUND(SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0) / 1e6, 2) AS discount_mln,
    ROUND(AVG(oi.discount_pct), 2) AS avg_simple_discount_pct,
    ROUND(100.0 * SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0) 
          / NULLIF(SUM(oi.quantity * oi.unit_price), 0), 2) AS avg_weighted_discount_pct,
    MAX(oi.discount_pct) AS max_discount_pct,
    COUNT(*) FILTER (WHERE oi.discount_pct > 10) AS violations_count
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN employees e ON o.employee_id = e.employee_id
WHERE o.status <> 'Отменён'
GROUP BY e.employee_id, e.full_name
ORDER BY discount_mln DESC;

-- 2. Менеджеры со средней скидкой свыше регламентных 10% (HAVING):
SELECT 
    e.employee_id,
    e.full_name AS manager_name,
    ROUND(AVG(oi.discount_pct), 2) AS avg_simple_discount_pct,
    ROUND(SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0) / 1e6, 2) AS discount_mln
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN employees e ON o.employee_id = e.employee_id
WHERE o.status <> 'Отменён'
GROUP BY e.employee_id, e.full_name
HAVING AVG(oi.discount_pct) > 10;
-- Результат: 1 строка — Соколов Игорь Андреевич (средняя скидка 18,01 %, сумма скидок 38,78 млн руб.).

-- 3. Прямые потери «деньги сверх политики» (часть скидки > 10 %):
SELECT 
    ROUND(SUM(oi.quantity * oi.unit_price * (oi.discount_pct - 10) / 100.0) / 1e6, 2) AS over_policy_mln,
    ROUND(SUM(oi.quantity * oi.unit_price * (oi.discount_pct - 10) / 100.0), 2) AS over_policy_rub
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status <> 'Отменён'
  AND oi.discount_pct > 10;
-- Результат: 17,27 млн руб. (точно 17 265 607,09 руб.).

/*
Ответ на вопросы для размышления к А1:
1. Почему у Морозовой выручка больше (207,23 млн руб.), а скидок вчетверо меньше (10,32 млн руб. против 38,78 млн у Соколова)?
   Морозова Е. П. продает в рамках корпоративной политики (макс. скидка 10 %, взвешенная средняя 4,75 %),
   сохраняя высокую маржу, тогда как Соколов И. А. стимулирует объемы за счет демпинга до 25 %, теряя выручку.
2. Что такое «справедливая» средняя скидка?
   Справедливая средняя скидка — это ВЗВЕШЕННАЯ по сумме скидка: SUM(скидка в руб) / SUM(валовая сумма без скидки),
   поскольку простая средняя AVG(discount_pct) приравнивает мелкий заказ на 100 руб. к крупному на 1 млн руб.
*/


-- ----------------------------------------------------------------------------
-- Задание А2. Дебиторская задолженность vs кредитный лимит
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка результата = один клиент (customers.customer_id).
-- Проверка: 1 клиент; долг 6 907 600,45 руб.; просроченный — 5 367 300,18 руб.

-- 1. Клиенты с долгом, превышающим кредитный лимит (HAVING):
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(i.invoice_id) AS invoices_count,
    SUM(i.amount) AS total_invoiced_rub,
    SUM(COALESCE(pay.paid, 0)) AS total_paid_rub,
    SUM(i.amount - COALESCE(pay.paid, 0)) AS total_debt_rub,
    SUM(i.amount - COALESCE(pay.paid, 0)) FILTER (WHERE i.due_date < DATE '2026-01-01') AS overdue_debt_rub,
    c.credit_limit,
    ROUND(SUM(i.amount - COALESCE(pay.paid, 0)) / NULLIF(c.credit_limit, 0), 2) AS debt_to_limit_ratio
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN invoices i ON o.order_id = i.order_id
LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS paid
    FROM payments
    GROUP BY invoice_id
) AS pay ON pay.invoice_id = i.invoice_id
GROUP BY c.customer_id, c.customer_name, c.credit_limit
HAVING SUM(i.amount - COALESCE(pay.paid, 0)) > c.credit_limit;
-- Результат: 1 клиент — ООО "Торговый дом Вектор" (долг 6 907 600,45 руб., просроченный 5 367 300,18 руб., лимит 3 000 000 руб.).

-- 2. Топ-5 клиентов по просроченному долгу (без HAVING):
SELECT 
    c.customer_id,
    c.customer_name,
    SUM(i.amount - COALESCE(pay.paid, 0)) AS total_debt_rub,
    SUM(i.amount - COALESCE(pay.paid, 0)) FILTER (WHERE i.due_date < DATE '2026-01-01') AS overdue_debt_rub,
    c.credit_limit
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN invoices i ON o.order_id = i.order_id
LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS paid
    FROM payments
    GROUP BY invoice_id
) AS pay ON pay.invoice_id = i.invoice_id
GROUP BY c.customer_id, c.customer_name, c.credit_limit
ORDER BY overdue_debt_rub DESC NULLS LAST
LIMIT 5;


-- ----------------------------------------------------------------------------
-- Задание А3. Возвраты по регионам и продуктам
-- ----------------------------------------------------------------------------
-- Проверка: 1) 7 строк, в Сибирском ФО 181 возврат, из них 171 — истёк срок;
-- 2) 10 строк, все — продукты со сроком годности 7–10 дней.

-- 1. Гранулярность: одна строка = один федеральный округ (7 строк):
SELECT 
    COALESCE(r.federal_district, 'не указан') AS federal_district,
    COUNT(*) AS returns_count,
    SUM(ret.quantity) AS total_units_returned,
    COUNT(*) FILTER (WHERE ret.reason = 'Истёк срок годности') AS expired_returns_count
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
GROUP BY COALESCE(r.federal_district, 'не указан')
ORDER BY returns_count DESC;
-- Результат: 7 строк; Сибирский ФО — 181 возврат (23 732 ед.), из них 171 по причине «Истёк срок годности».

-- 2. Гранулярность: одна строка = (регион × продукт) с числом возвратов >= 10 (10 строк):
SELECT 
    COALESCE(r.region_name, 'не указан') AS region_name,
    p.product_name,
    p.shelf_life_days,
    COUNT(*) AS returns_count,
    SUM(ret.quantity) AS total_units,
    ROUND(SUM(ret.quantity * p.base_price), 2) AS estimated_loss_rub
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
JOIN products p ON ret.product_id = p.product_id
GROUP BY COALESCE(r.region_name, 'не указан'), p.product_name, p.shelf_life_days
HAVING COUNT(*) >= 10
ORDER BY estimated_loss_rub DESC;
-- Результат: ровно 10 строк (Новосибирская обл. и Красноярский край), все товары со сроком 7–10 дней.

-- 3. Оценка общих потерь в рублях по возвратам с истекшим сроком годности:
SELECT 
    ROUND(SUM(ret.quantity * p.base_price), 2) AS total_expired_loss_rub,
    ROUND(SUM(ret.quantity * p.base_price) FILTER (WHERE r.federal_district = 'Сибирский'), 2) AS siberia_expired_loss_rub
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
JOIN products p ON ret.product_id = p.product_id
WHERE ret.reason = 'Истёк срок годности';
-- Результат: 2 012 865,00 руб. по всей компании (в т.ч. 1 800 894,00 руб. в Сибирском ФО).


-- ----------------------------------------------------------------------------
-- Задание А4. Выручка по кварталам с ROLLUP
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка = (год × квартал), подытог года или общий итог (11 строк).
-- Проверка: 11 строк; 2024 — 384,01; 2025 — 445,11; всего — 829,12 млн руб.

SELECT 
    CASE WHEN GROUPING(EXTRACT(YEAR FROM o.order_date)::int) = 1 THEN 'ВСЕГО'
         ELSE EXTRACT(YEAR FROM o.order_date)::int::text END AS order_year,
    CASE WHEN GROUPING(EXTRACT(YEAR FROM o.order_date)::int) = 1 THEN ''
         WHEN GROUPING(EXTRACT(QUARTER FROM o.order_date)::int) = 1 THEN 'Итого за год'
         ELSE 'Q' || EXTRACT(QUARTER FROM o.order_date)::int::text END AS order_quarter,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) / 1e6, 2) AS revenue_mln
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status <> 'Отменён'
GROUP BY ROLLUP (
    EXTRACT(YEAR FROM o.order_date)::int,
    EXTRACT(QUARTER FROM o.order_date)::int
)
ORDER BY 
    EXTRACT(YEAR FROM o.order_date)::int NULLS LAST,
    EXTRACT(QUARTER FROM o.order_date)::int NULLS LAST;
-- Результат: 11 строк; 2024 = 384,01 млн; 2025 = 445,11 млн; ВСЕГО = 829,12 млн руб.


-- ----------------------------------------------------------------------------
-- Задание А5. План / факт по категориям
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка = (категория верхнего уровня × год × полугодие) (12 строк).
-- План и факт агрегируются раздельно до одной гранулярности перед JOIN.
-- Проверка: 12 строк; худшая ячейка — 80,0 % выполнения, остальные >= 93 %.

WITH fact_agg AS (
    SELECT 
        pc_top.category_id,
        pc_top.category_name,
        EXTRACT(YEAR FROM o.order_date)::int AS yr,
        CASE WHEN EXTRACT(MONTH FROM o.order_date) <= 6 THEN 1 ELSE 2 END AS half_yr,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS fact_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_categories pc_sub ON p.category_id = pc_sub.category_id
    JOIN product_categories pc_top ON pc_sub.parent_category_id = pc_top.category_id
    WHERE o.status <> 'Отменён'
    GROUP BY 
        pc_top.category_id, 
        pc_top.category_name, 
        EXTRACT(YEAR FROM o.order_date)::int, 
        CASE WHEN EXTRACT(MONTH FROM o.order_date) <= 6 THEN 1 ELSE 2 END
),
plan_agg AS (
    SELECT 
        sp.category_id,
        sp.plan_year AS yr,
        CASE WHEN sp.plan_month <= 6 THEN 1 ELSE 2 END AS half_yr,
        SUM(sp.plan_amount) AS plan_rub
    FROM sales_plan sp
    GROUP BY 
        sp.category_id, 
        sp.plan_year, 
        CASE WHEN sp.plan_month <= 6 THEN 1 ELSE 2 END
)
SELECT 
    f.category_name,
    f.yr,
    f.half_yr,
    ROUND(p.plan_rub / 1e6, 2) AS plan_mln,
    ROUND(f.fact_rub / 1e6, 2) AS fact_mln,
    ROUND(f.fact_rub - p.plan_rub, 2) AS deviation_rub,
    ROUND(100.0 * f.fact_rub / NULLIF(p.plan_rub, 0), 1) AS fulfillment_pct
FROM fact_agg f
JOIN plan_agg p ON f.category_id = p.category_id 
               AND f.yr = p.yr 
               AND f.half_yr = p.half_yr
ORDER BY fulfillment_pct ASC;
/*
Результат: 12 строк. Худшая ячейка — Кондитерские изделия, 2025 г., 2-е полугодие:
план 97,39 млн, факт 77,91 млн (80,0 % выполнения, недовыполнение -19 477 631,86 руб.).
Ответ на вопрос: Кто «виноват» — продажи или план?
Во 2-м полугодии 2024 г. продажи категории составляли 64,73 млн руб., а во 2-м полугодии 2025 г.
они выросли до 77,91 млн руб. (+20,4 % год к году!). Срыв связан с нереалистичным завышением плана
руководством сразу на +50 % к базе 2024 г. (до 97,39 млн руб.).
*/


-- ----------------------------------------------------------------------------
-- Задание А6. Маркетинг vs выручка по кварталам
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка = (год × квартал) (8 строк).
-- Проверка: 8 строк; в IV кв. 2025 доля маркетинга — 5,62 % (в 2024 г. — 1,6–1,8 %).

WITH rev_q AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_date)::int AS yr,
        EXTRACT(QUARTER FROM o.order_date)::int AS qtr,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS rev_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'Отменён'
    GROUP BY EXTRACT(YEAR FROM o.order_date)::int, EXTRACT(QUARTER FROM o.order_date)::int
),
mkt_q AS (
    SELECT 
        EXTRACT(YEAR FROM ex.expense_date)::int AS yr,
        EXTRACT(QUARTER FROM ex.expense_date)::int AS qtr,
        SUM(ex.amount) AS mkt_rub
    FROM expenses ex
    WHERE ex.expense_category = 'Маркетинг'
    GROUP BY EXTRACT(YEAR FROM ex.expense_date)::int, EXTRACT(QUARTER FROM ex.expense_date)::int
)
SELECT 
    r.yr,
    r.qtr,
    ROUND(m.mkt_rub / 1e6, 2) AS marketing_mln,
    ROUND(r.rev_rub / 1e6, 2) AS revenue_mln,
    ROUND(100.0 * m.mkt_rub / NULLIF(r.rev_rub, 0), 2) AS marketing_share_pct,
    ROUND(m.mkt_rub, 2) AS marketing_rub
FROM rev_q r
JOIN mkt_q m ON r.yr = m.yr AND r.qtr = m.qtr
ORDER BY r.yr, r.qtr;
/*
Результат: 8 строк. В IV кв. 2025 г. маркетинг вырос в 4,08 раза (с 1,73 млн до 7,06 млн руб.),
доля в выручке подскочила до 5,62 %. Выручка выросла на +20,38 % (с 104,41 млн до 125,69 млн руб.).
Учитывая, что в I полугодии 2025 г. бизнес уже рос на +13..30 % без резких трат на маркетинг,
а в III кв. удвоение бюджета дало рост лишь +1,7 %, кампания Q4 имеет сомнительную окупаемость (перерасход ~5,33 млн руб.).
*/


-- ----------------------------------------------------------------------------
-- Задание А7. Дубли клиентов
-- ----------------------------------------------------------------------------
-- Гранулярность: одна строка = один уникальный ИНН с числом карточек > 1 (3 строки).
-- Проверка: 3 ИНН, 7 карточек.

SELECT 
    inn,
    STRING_AGG(customer_name, ' | ' ORDER BY customer_id) AS customer_names,
    ARRAY_AGG(customer_id ORDER BY customer_id) AS customer_ids,
    COUNT(*) AS cards_count,
    COUNT(DISTINCT manager_id) AS distinct_managers_count
FROM customers
GROUP BY inn
HAVING COUNT(*) > 1
ORDER BY cards_count DESC, inn;
-- Результат: 3 ИНН (562810604315 — 2 карты, 7924695572 — 3 карты, 8423916122 — 2 карты), итого 7 карточек.


-- ----------------------------------------------------------------------------
-- Задание А8. Отчёт GROUPING SETS по каналам
-- ----------------------------------------------------------------------------
-- Гранулярность: итоги по (канал, год), (канал), (год) и общий итог (15 строк).
-- Проверка: 15 строк по выручке; расходы канала «Маркетплейс»: 19,94 -> 29,76 млн руб.

-- 1. Выручка в разрезе каналов и годов (GROUPING SETS — 15 строк):
SELECT 
    CASE WHEN GROUPING(o.channel) = 1 THEN 'Все каналы' ELSE o.channel END AS channel,
    CASE WHEN GROUPING(EXTRACT(YEAR FROM o.order_date)::int) = 1 THEN 'Все годы' 
         ELSE EXTRACT(YEAR FROM o.order_date)::int::text END AS yr,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) / 1e6, 2) AS revenue_mln,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS revenue_rub
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status <> 'Отменён'
GROUP BY GROUPING SETS (
    (o.channel, EXTRACT(YEAR FROM o.order_date)::int),
    (o.channel),
    (EXTRACT(YEAR FROM o.order_date)::int),
    ()
)
ORDER BY 
    GROUPING(o.channel), 
    o.channel, 
    GROUPING(EXTRACT(YEAR FROM o.order_date)::int), 
    yr;

-- 2. Прямые расходы каналов по годам:
SELECT 
    sales_channel,
    EXTRACT(YEAR FROM expense_date)::int AS yr,
    ROUND(SUM(amount) / 1e6, 2) AS expense_mln,
    ROUND(SUM(amount), 2) AS expense_rub
FROM expenses
WHERE sales_channel IS NOT NULL
GROUP BY sales_channel, EXTRACT(YEAR FROM expense_date)::int
ORDER BY sales_channel, yr;
/*
Результат по каналу «Маркетплейс»:
- 2024 г.: выручка 7,89 млн руб. при расходах 19,94 млн руб. -> операционный убыток -12,05 млн руб.
- 2025 г.: выручка 11,74 млн руб. (11 737 915,32 руб.) при расходах 29,76 млн руб. (29 755 241,06 руб.)
           -> прямой убыток без учета себестоимости товара: -18 017 325,74 руб.!
Коммерческому директору: канал «Маркетплейс» системно сжигает деньги (-30,06 млн руб. за 2 года без учета COGS).
Необходимо срочно пересмотреть матрицу комиссий/логистики или закрыть убыточное направление.
*/


-- ----------------------------------------------------------------------------
-- Задание А9*. CUBE «тип клиента × канал» (2025 г.)
-- ----------------------------------------------------------------------------
-- Гранулярность: все 2^2 комбинации подытогов (тип клиента × канал) (18 строк).
-- Проверка: 18 строк.

SELECT 
    CASE WHEN GROUPING(c.customer_type) = 1 THEN 'Итого по типам' ELSE c.customer_type END AS customer_type,
    CASE WHEN GROUPING(o.channel) = 1 THEN 'Итого по каналам' ELSE o.channel END AS channel,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) / 1e6, 2) AS revenue_mln,
    ROUND(100.0 * SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0) 
          / NULLIF(SUM(oi.quantity * oi.unit_price), 0), 2) AS weighted_avg_discount_pct,
    ROUND(AVG(oi.discount_pct), 2) AS simple_avg_discount_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status <> 'Отменён'
  AND o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
GROUP BY CUBE (c.customer_type, o.channel)
ORDER BY 
    GROUPING(c.customer_type), 
    c.customer_type, 
    GROUPING(o.channel), 
    o.channel;
-- Результат: ровно 18 строк. Итог 2025 г. = 445,11 млн руб., взвешенная скидка = 7,50 %.


-- ============================================================================
-- ВОПРОСЫ ДЛЯ ЗАЩИТЫ РАБОТЫ (КОМАНДА А)
-- ============================================================================
/*
1. Где в вашей работе условие стоит в HAVING, а где — в WHERE, и почему?
   - WHERE фильтрует исходные строки ДО группировки (status <> 'Отменён', discount_pct > 10 для перерасхода,
     expense_category = 'Маркетинг', sales_channel IS NOT NULL). Это отсекает лишний шум и ускоряет группировку.
   - HAVING фильтрует сформированные группы ПОСЛЕ расчета агрегатных функций (AVG(discount_pct) > 10 в А1,
     SUM(debt) > credit_limit в А2, COUNT(*) >= 10 в А3, COUNT(*) > 1 в А7). Использовать агрегаты в WHERE запрещено.

2. Покажите запрос, в котором без предварительной агрегации в подзапросе получилась бы неверная сумма.
   - Запрос А2 (invoices и payments): один счет оплачивается несколькими частичными платежами (1:N). Без подзапроса
     SUM(amount) GROUP BY invoice_id каждый счет дублировался бы по числу платежей, завышая сумму долга в разы.
   - Запрос А5 (план и факт): таблица sales_plan имеет гранулярность месяца, а order_items — позиции заказа.
     Без раздельных CTE/подзапросов возникло бы декартово размножение M × N.
   - Запрос А6 (расходы на маркетинг и выручка по кварталам).

3. Чем отличается результат ROLLUP (a, b) от CUBE (a, b) в вашем отчёте?
   - ROLLUP (год, квартал) в А4 строит строгую иерархию итогов слева направо: (год, квартал), (год), ().
   - CUBE (тип_клиента, канал) в А9 строит все 2^2 = 4 возможные комбинации: (тип, канал), (тип), (канал), ().
     Дополнительно появляются итоговые разрезы по каждому каналу независимо от типа клиента.

4. Какая находка вашей команды связана с находкой другой команды?
   - Массовые возвраты скоропортящейся продукции (йогурты 7 дней, кефир 10 дней) в Сибирском ФО на 1,80 млн руб. (А3)
     и недовыполнение плана по кондитерским изделиям на -19,48 млн руб. (А5) могут быть напрямую связаны с проблемами
     производственных мощностей, простоями линий, задержками отгрузки или нехваткой сырья, которые исследует Команда Б.
*/
