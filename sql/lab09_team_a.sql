-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 9. ЛАБОРАТОРНАЯ РАБОТА:
-- «Витрины аналитика: представления, CTE и табличные функции»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab09_shkredov.sql
-- Исполнитель: Шкредов Сергей (Команда А «Финансы и продажи»)
-- Личная схема: stud_shkredov (все объекты создаются строго в ней)
-- Источник данных: схема pitanie (Read-Only)
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ПОДГОТОВИТЕЛЬНАЯ ЧАСТЬ: УСТАНОВКА ПУТИ ПОИСКА
-- ----------------------------------------------------------------------------
-- Устанавливаем путь поиска: первой идет личная схема stud_shkredov, затем pitanie
SET search_path TO stud_shkredov, pitanie, public;

-- Проверка активной схемы сессии:
SELECT current_schema();  -- Должно вернуть: stud_shkredov


-- ============================================================================
-- ЗАДАНИЕ А1. ПРЕДСТАВЛЕНИЕ v_sales_lines (БАЗОВАЯ ВИТРИНА ПРОДАЖ)
-- ============================================================================
-- Задача: Создать базовую витрину «одна строка = одна позиция заказа» (без отменённых заказов)
-- со столбцами: order_item_id, order_id, order_date, customer_id, employee_id, channel,
-- product_id, category_id, top_category_id, quantity, unit_price, discount_pct, standard_cost,
-- gross_amount, discount_amount, net_amount, cost_amount, margin.
-- Денежные столбцы округлены до 2 знаков.

CREATE OR REPLACE VIEW stud_shkredov.v_sales_lines AS
SELECT 
    oi.order_item_id,
    o.order_id,
    o.order_date,
    o.customer_id,
    o.employee_id,
    o.channel,
    p.product_id,
    p.category_id,
    pc.parent_category_id AS top_category_id,
    oi.quantity,
    oi.unit_price,
    oi.discount_pct,
    p.standard_cost,
    ROUND(oi.quantity * oi.unit_price, 2) AS gross_amount,
    ROUND(oi.quantity * oi.unit_price * oi.discount_pct / 100.0, 2) AS discount_amount,
    ROUND(oi.quantity * oi.unit_price * (1.0 - oi.discount_pct / 100.0), 2) AS net_amount,
    ROUND(oi.quantity * p.standard_cost, 2) AS cost_amount,
    ROUND(oi.quantity * oi.unit_price * (1.0 - oi.discount_pct / 100.0) - oi.quantity * p.standard_cost, 2) AS margin
FROM pitanie.orders o
JOIN pitanie.order_items oi ON o.order_id = oi.order_id
JOIN pitanie.products p ON oi.product_id = p.product_id
JOIN pitanie.product_categories pc ON p.category_id = pc.category_id
WHERE o.status <> 'Отменён';

COMMENT ON VIEW stud_shkredov.v_sales_lines IS 'Базовая аналитическая витрина продаж: одна строка = одна позиция неотмененного заказа с расчетом выручки, скидки, себестоимости и маржи';

-- Контрольная проверка задания А1:
-- Ожидается: 16 923 строки, выручка ≈ 829,1 млн, маржа ≈ 229,2 млн.
SELECT 
    COUNT(*) AS total_rows,
    ROUND(SUM(net_amount), 2) AS total_revenue_rub,
    ROUND(SUM(margin), 2) AS total_margin_rub
FROM stud_shkredov.v_sales_lines;

-- Дополнительно: поиск товаров с отрицательной маржой (строки с прямым убытком):
-- Ожидается: ровно 2 товара (Масло 82.5% и Масло 72.5%).
SELECT 
    sl.product_id,
    p.product_name,
    COUNT(*) AS negative_margin_lines,
    SUM(sl.quantity) AS total_qty_sold,
    ROUND(SUM(sl.margin), 2) AS total_loss_rub
FROM stud_shkredov.v_sales_lines sl
JOIN pitanie.products p ON sl.product_id = p.product_id
WHERE sl.margin < 0
GROUP BY sl.product_id, p.product_name
ORDER BY sl.product_id;


-- ============================================================================
-- ЗАДАНИЕ А2. ПРЕДСТАВЛЕНИЕ v_receivables (ДЕБИТОРКА НА 31.12.2025)
-- ============================================================================
-- Задача: Создать витрину дебиторской задолженности на дату среза 31.12.2025.
-- Столбцы: customer_id, customer_name, credit_limit, payment_terms_days, invoiced, paid, debt,
-- overdue_debt, overdue_invoices, over_limit.
-- Внутри используется CTE inv со счетами и коррелированным подзапросом к payments на дату среза.

CREATE OR REPLACE VIEW stud_shkredov.v_receivables AS
WITH inv AS (
    SELECT 
        i.invoice_id,
        o.customer_id,
        i.invoice_date,
        i.due_date,
        i.amount,
        COALESCE((
            SELECT SUM(p.amount) 
            FROM pitanie.payments p 
            WHERE p.invoice_id = i.invoice_id 
              AND p.payment_date <= DATE '2025-12-31'
        ), 0.00) AS paid_amount
    FROM pitanie.invoices i
    JOIN pitanie.orders o ON i.order_id = o.order_id
    WHERE i.invoice_date <= DATE '2025-12-31'
)
SELECT 
    c.customer_id,
    c.customer_name,
    c.credit_limit,
    c.payment_terms_days,
    ROUND(SUM(inv.amount), 2) AS invoiced,
    ROUND(SUM(inv.paid_amount), 2) AS paid,
    ROUND(SUM(inv.amount - inv.paid_amount), 2) AS debt,
    ROUND(SUM(CASE WHEN inv.due_date < DATE '2025-12-31' THEN (inv.amount - inv.paid_amount) ELSE 0 END), 2) AS overdue_debt,
    COUNT(*) FILTER (WHERE inv.due_date < DATE '2025-12-31' AND (inv.amount - inv.paid_amount) > 0) AS overdue_invoices,
    (SUM(inv.amount - inv.paid_amount) > c.credit_limit) AS over_limit
FROM pitanie.customers c
JOIN inv ON c.customer_id = inv.customer_id
GROUP BY c.customer_id, c.customer_name, c.credit_limit, c.payment_terms_days;

COMMENT ON VIEW stud_shkredov.v_receivables IS 'Витрина дебиторской задолженности на срез 31.12.2025: начисления, оплаты, текущий и просроченный долг, флаг превышения кредитного лимита';

-- Контрольная проверка задания А2:
-- Ожидается: общий долг ≈ 55,9 млн; клиентов с превышением лимита — 1.
SELECT 
    COUNT(*) AS total_clients,
    ROUND(SUM(invoiced), 2) AS total_invoiced,
    ROUND(SUM(paid), 2) AS total_paid,
    ROUND(SUM(debt), 2) AS total_debt,
    ROUND(SUM(overdue_debt), 2) AS total_overdue_debt,
    COUNT(*) FILTER (WHERE over_limit) AS over_limit_clients
FROM stud_shkredov.v_receivables;

-- Кто клиент с превышением лимита?
-- Ожидается: ООО «Торговый дом Вектор», долг 6 907 600.45 руб. при лимите 3 000 000 руб., 39 просроченных счетов.
SELECT 
    customer_id,
    customer_name,
    credit_limit,
    debt,
    overdue_debt,
    overdue_invoices,
    over_limit
FROM stud_shkredov.v_receivables
WHERE over_limit = TRUE;


-- ============================================================================
-- ЗАДАНИЕ А3. CTE-ОТЧЁТ «ПЛАН / ФАКТ 2025»
-- ============================================================================
-- Задача: Построить цепочку CTE (fact -> plan -> pf) выполнения плана 2025 г.
-- по месяцам и категориям верхнего уровня на основе v_sales_lines.
-- Вывести только месяцы с выполнением ниже 85 %.

WITH fact AS (
    SELECT 
        EXTRACT(MONTH FROM order_date)::INT AS mon,
        top_category_id,
        SUM(net_amount) AS fact_amount
    FROM stud_shkredov.v_sales_lines
    WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'
    GROUP BY EXTRACT(MONTH FROM order_date), top_category_id
),
plan AS (
    SELECT 
        plan_month AS mon,
        category_id AS top_category_id,
        plan_amount
    FROM pitanie.sales_plan
    WHERE plan_year = 2025
),
pf AS (
    SELECT 
        pl.mon,
        pl.top_category_id,
        pc.category_name AS top_category_name,
        pl.plan_amount,
        COALESCE(f.fact_amount, 0.00) AS fact_amount,
        ROUND(100.0 * COALESCE(f.fact_amount, 0.00) / pl.plan_amount, 2) AS exec_pct,
        ROUND(pl.plan_amount - COALESCE(f.fact_amount, 0.00), 2) AS shortfall_amount
    FROM plan pl
    LEFT JOIN fact f ON pl.mon = f.mon AND pl.top_category_id = f.top_category_id
    LEFT JOIN pitanie.product_categories pc ON pl.top_category_id = pc.category_id
)
SELECT 
    mon,
    top_category_id,
    top_category_name,
    plan_amount,
    fact_amount,
    exec_pct,
    shortfall_amount
FROM pf
WHERE exec_pct < 85.0
ORDER BY mon, top_category_id;

-- Подсчет суммарного недобора по проблемным периодам:
-- Ожидается: 6 строк (месяцы 7–12, категория «Кондитерские изделия»), недобор ≈ 19,5 млн руб.
WITH fact AS (
    SELECT 
        EXTRACT(MONTH FROM order_date)::INT AS mon,
        top_category_id,
        SUM(net_amount) AS fact_amount
    FROM stud_shkredov.v_sales_lines
    WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'
    GROUP BY EXTRACT(MONTH FROM order_date), top_category_id
),
plan AS (
    SELECT 
        plan_month AS mon,
        category_id AS top_category_id,
        plan_amount
    FROM pitanie.sales_plan
    WHERE plan_year = 2025
),
pf AS (
    SELECT 
        pl.mon,
        pl.top_category_id,
        pl.plan_amount,
        COALESCE(f.fact_amount, 0.00) AS fact_amount,
        100.0 * COALESCE(f.fact_amount, 0.00) / pl.plan_amount AS exec_pct,
        (pl.plan_amount - COALESCE(f.fact_amount, 0.00)) AS shortfall_amount
    FROM plan pl
    LEFT JOIN fact f ON pl.mon = f.mon AND pl.top_category_id = f.top_category_id
)
SELECT 
    COUNT(*) AS low_exec_count,
    ROUND(SUM(shortfall_amount), 2) AS total_shortfall_rub
FROM pf
WHERE exec_pct < 85.0;


-- ============================================================================
-- ЗАДАНИЕ А4. РЕКУРСИВНЫЙ CTE «ВСЯ КОМАНДА КОММЕРЧЕСКОГО ДИРЕКТОРА»
-- ============================================================================
-- Задача: Вывести всех подчиненных коммерческого директора (employee_id = 3)
-- с глубиной (depth), путем (path) и показателями выручки, скидок и нарушений.
-- Проверка: 11 строк.

WITH RECURSIVE team AS (
    -- Якорь рекурсии: коммерческий директор Громов А. И. (employee_id = 3)
    SELECT 
        e.employee_id,
        e.full_name,
        e.position,
        e.manager_id,
        0 AS depth,
        ARRAY[e.employee_id] AS path,
        e.full_name::TEXT AS tree_name
    FROM pitanie.employees e
    WHERE e.employee_id = 3

    UNION ALL

    -- Рекурсивный шаг: все уровни подчинения
    SELECT 
        e.employee_id,
        e.full_name,
        e.position,
        e.manager_id,
        t.depth + 1,
        t.path || e.employee_id,
        REPEAT('  ', t.depth + 1) || e.full_name AS tree_name
    FROM pitanie.employees e
    JOIN team t ON e.manager_id = t.employee_id
),
mgr_stats AS (
    SELECT 
        sl.employee_id,
        ROUND(SUM(sl.net_amount), 2) AS total_revenue,
        ROUND(SUM(sl.discount_amount), 2) AS total_discounts,
        COUNT(*) AS total_lines,
        COUNT(*) FILTER (WHERE sl.discount_pct > 10) AS over_discount_lines,
        ROUND(100.0 * COUNT(*) FILTER (WHERE sl.discount_pct > 10) / COUNT(*), 1) AS over_discount_pct
    FROM stud_shkredov.v_sales_lines sl
    GROUP BY sl.employee_id
)
SELECT 
    t.employee_id,
    t.tree_name,
    t.position,
    t.depth,
    COALESCE(s.total_revenue, 0.00) AS revenue,
    COALESCE(s.total_discounts, 0.00) AS discounts,
    COALESCE(s.total_lines, 0) AS total_lines,
    COALESCE(s.over_discount_lines, 0) AS over_discount_lines,
    COALESCE(s.over_discount_pct, 0.0) AS over_discount_pct
FROM team t
LEFT JOIN mgr_stats s ON t.employee_id = s.employee_id
ORDER BY t.path;

-- ОТВЕТЫ НА ВОПРОСЫ К ЗАДАНИЮ А4:
-- 1. У кого число строк сверх политики скидок не равно нулю?
--    У Соколова Игоря Андреевича (4 167 строк) и Попова Станислава Игоревича (53 строки).
-- 2. Какую долю своих строк он продал со скидкой больше 10 %?
--    Соколов И. А. продал ровно 100.0 % своих позиций (4 167 из 4 167) со скидкой выше лимита!
--    Попов С. И. продал 39.8 % позиций с нарушением лимита (53 из 133).


-- ============================================================================
-- ЗАДАНИЕ А5. ТАБЛИЧНАЯ ФУНКЦИЯ fn_customer_debt(p_date date)
-- ============================================================================
-- Задача: Обобщить расчет дебиторской задолженности на любую дату p_date.
-- LANGUAGE sql STABLE, RETURNS TABLE (...). Учитываются счета и оплаты на дату p_date.

CREATE OR REPLACE FUNCTION stud_shkredov.fn_customer_debt(p_date date)
RETURNS TABLE (
    customer_id int,
    customer_name varchar,
    credit_limit numeric,
    invoiced numeric,
    paid numeric,
    debt numeric,
    overdue_debt numeric
) 
LANGUAGE sql STABLE
AS $$
    WITH inv AS (
        SELECT 
            i.invoice_id,
            o.customer_id,
            i.amount,
            i.due_date,
            COALESCE((
                SELECT SUM(p.amount) 
                FROM pitanie.payments p 
                WHERE p.invoice_id = i.invoice_id 
                  AND p.payment_date <= p_date
            ), 0.00) AS paid_amount
        FROM pitanie.invoices i
        JOIN pitanie.orders o ON i.order_id = o.order_id
        WHERE i.invoice_date <= p_date
    )
    SELECT 
        c.customer_id,
        c.customer_name,
        c.credit_limit,
        ROUND(SUM(inv.amount), 2) AS invoiced,
        ROUND(SUM(inv.paid_amount), 2) AS paid,
        ROUND(SUM(inv.amount - inv.paid_amount), 2) AS debt,
        ROUND(SUM(CASE WHEN inv.due_date < p_date THEN (inv.amount - inv.paid_amount) ELSE 0 END), 2) AS overdue_debt
    FROM pitanie.customers c
    JOIN inv ON c.customer_id = inv.customer_id
    GROUP BY c.customer_id, c.customer_name, c.credit_limit;
$$;

COMMENT ON FUNCTION stud_shkredov.fn_customer_debt(date) IS 'Табличная функция расчета задолженности клиентов (начислено, оплачено, общий и просроченный долг) на произвольную дату с учетом счетов и оплат';

-- Проверка 1: на 2025-12-31 совпадает с v_receivables (долг 6 907 600.45 руб.)
SELECT customer_id, customer_name, debt, overdue_debt
FROM stud_shkredov.fn_customer_debt(DATE '2025-12-31')
ORDER BY debt DESC
LIMIT 1;

-- Проверка 2: CROSS JOIN LATERAL по контрольным датам (33.2 -> 47.1 -> 55.9 млн руб.)
SELECT 
    d.check_date,
    ROUND(SUM(f.debt) / 1e6, 1) AS total_debt_mln
FROM (VALUES (DATE '2024-06-30'), (DATE '2025-06-30'), (DATE '2025-12-31')) AS d(check_date)
CROSS JOIN LATERAL stud_shkredov.fn_customer_debt(d.check_date) f
GROUP BY d.check_date
ORDER BY d.check_date;


-- ============================================================================
-- ЗАДАНИЕ А6. ТАБЛИЧНАЯ ФУНКЦИЯ fn_manager_discount_violations
-- ============================================================================
-- Задача: Выявить менеджеров с превышением скидочного лимита p_limit (по умолчанию 10%).
-- Рассчитать сумму скидки сверх лимита в рублях (excess_discount).

CREATE OR REPLACE FUNCTION stud_shkredov.fn_manager_discount_violations(
    p_from date DEFAULT DATE '2024-01-01',
    p_to date DEFAULT DATE '2025-12-31',
    p_limit numeric DEFAULT 10
)
RETURNS TABLE (
    employee_id int,
    full_name varchar,
    lines_total bigint,
    lines_over_limit bigint,
    avg_discount_pct numeric,
    excess_discount numeric
)
LANGUAGE sql STABLE
AS $$
    SELECT 
        e.employee_id,
        e.full_name,
        COUNT(*) AS lines_total,
        COUNT(*) FILTER (WHERE oi.discount_pct > p_limit) AS lines_over_limit,
        ROUND(AVG(oi.discount_pct), 2) AS avg_discount_pct,
        ROUND(SUM(
            CASE 
                WHEN oi.discount_pct > p_limit 
                THEN oi.quantity * oi.unit_price * (oi.discount_pct - p_limit) / 100.0 
                ELSE 0.00 
            END
        ), 2) AS excess_discount
    FROM pitanie.orders o
    JOIN pitanie.order_items oi ON o.order_id = oi.order_id
    JOIN pitanie.employees e ON o.employee_id = e.employee_id
    WHERE o.status <> 'Отменён'
      AND o.order_date >= p_from 
      AND o.order_date <= p_to
    GROUP BY e.employee_id, e.full_name
    HAVING COUNT(*) FILTER (WHERE oi.discount_pct > p_limit) > 0
    ORDER BY excess_discount DESC;
$$;

COMMENT ON FUNCTION stud_shkredov.fn_manager_discount_violations(date, date, numeric) IS 'Табличная функция выявления менеджеров-нарушителей регламента скидок за период с расчетом суммы скидок сверх установленного лимита (excess_discount)';

-- Проверка 1: весь период, лимит 10 % -> 2 строки, у Соколова excess_discount ≈ 17.2 млн руб.
SELECT * FROM stud_shkredov.fn_manager_discount_violations(DATE '2024-01-01', DATE '2025-12-31', 10);

-- Проверка 2: 2025 год, лимит 15 % -> 1 строка, 1 270 позиций.
SELECT * FROM stud_shkredov.fn_manager_discount_violations(DATE '2025-01-01', DATE '2025-12-31', 15);

-- ОТВЕТ НА АНАЛИТИЧЕСКИЙ ВОПРОС:
-- Кто второй нарушитель и почему его нарушения прекратились в середине 2024 года?
-- Ответ: Попов Станислав Игоревич (employee_id = 60). Его последний заказ оформлен 28.06.2024,
-- после чего он был уволен из компании за регулярные превышения скидочной политики.


-- ============================================================================
-- ЗАДАНИЕ А7. ДИНАМИКА ДОЛГА ПРОБЛЕМНОГО КЛИЕНТА (LATERAL)
-- ============================================================================
-- Задача: Построить помесячную динамику долга ООО «ТД Вектор» на конец каждого месяца 2025 г.
-- через generate_series и CROSS JOIN LATERAL fn_customer_debt.

WITH months AS (
    SELECT 
        (d + INTERVAL '1 month - 1 day')::DATE AS month_end
    FROM generate_series(DATE '2025-01-01', DATE '2025-12-01', INTERVAL '1 month') AS d
)
SELECT 
    m.month_end,
    d.customer_id,
    d.customer_name,
    d.credit_limit,
    d.debt,
    d.overdue_debt,
    ROUND(d.debt / 1e6, 2) AS debt_mln,
    (d.debt > d.credit_limit) AS is_over_limit
FROM months m
CROSS JOIN LATERAL stud_shkredov.fn_customer_debt(m.month_end) d
WHERE d.customer_id = 1
ORDER BY m.month_end;

-- Подсчет счетов и выручки заказов, отгруженных после превышения лимита:
-- Ожидается: 22 счета / заказа на сумму ≈ 4,11 млн руб.
SELECT 
    COUNT(*) AS invoices_cnt,
    ROUND(SUM(amount), 2) AS invoices_amount
FROM pitanie.invoices i
JOIN pitanie.orders o ON i.order_id = o.order_id
WHERE o.customer_id = 1
  AND i.invoice_date >= DATE '2025-07-03';

-- Анализ закрепленного менеджера клиента 1:
SELECT 
    c.customer_id,
    c.customer_name,
    c.manager_id,
    e.full_name AS manager_name,
    e.position
FROM pitanie.customers c
LEFT JOIN pitanie.employees e ON c.manager_id = e.employee_id
WHERE c.customer_id = 1;


-- ============================================================================
-- ЗАДАНИЕ А8. «ВЫВОД ДЛЯ РУКОВОДСТВА» (ТАБЛИЦА НАХОДОК В МЛН РУБ.)
-- ============================================================================
-- Задача: Одним запросом (CTE + UNION ALL) собрать сводную таблицу финансовых потерь
-- компании из созданных витрин и функций.

WITH finding1 AS (
    -- 1. Скидки сверх политики (> 10%)
    SELECT 
        '1. Скидки сверх корпоративной политики (> 10%)' AS finding_name,
        ROUND(SUM(excess_discount) / 1e6, 2) AS amount_mln,
        'Суммарный объем демпинговых скидок сверх допустимого лимита 10% (Соколов + Попов)' AS description
    FROM stud_shkredov.fn_manager_discount_violations(DATE '2024-01-01', DATE '2025-12-31', 10)
),
finding2 AS (
    -- 2. Долг сверх лимита
    SELECT 
        '2. Дефолтный долг сверх лимита (ООО «ТД Вектор»)' AS finding_name,
        ROUND(SUM(debt - credit_limit) / 1e6, 2) AS amount_mln,
        'Превышение кредитного лимита 3,0 млн руб. ключевым должником (долг 6,91 млн руб.)' AS description
    FROM stud_shkredov.v_receivables
    WHERE over_limit = TRUE
),
finding3 AS (
    -- 3. Убыток от продаж ниже себестоимости
    SELECT 
        '3. Прямой убыток от продаж ниже себестоимости' AS finding_name,
        ROUND(ABS(SUM(margin)) / 1e6, 2) AS amount_mln,
        'Финансовые потери от отрицательной маржи сливочного масла 82.5% и 72.5% за 2024–2025 гг.' AS description
    FROM stud_shkredov.v_sales_lines
    WHERE margin < 0
),
finding4 AS (
    -- 4. Недовыполнение годового плана продаж 2025 г.
    SELECT 
        '4. Недовыполнение годового плана продаж 2025 г.' AS finding_name,
        ROUND((477546000.00 - SUM(net_amount)) / 1e6, 2) AS amount_mln,
        'Недобор фактической выручки к утвержденному бюджету продаж 2025 года' AS description
    FROM stud_shkredov.v_sales_lines
    WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'
)
SELECT * FROM finding1
UNION ALL
SELECT * FROM finding2
UNION ALL
SELECT * FROM finding3
UNION ALL
SELECT * FROM finding4;


-- ============================================================================
-- ЗАДАНИЯ СО ЗВЁЗДОЧКОЙ (А*)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Задание А*1 (★). Материализованное представление mv_receivables_monthly
-- Помесячная задолженность всех клиентов за 2024–2025 гг. с уникальным индексом
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS stud_shkredov.mv_receivables_monthly;

CREATE MATERIALIZED VIEW stud_shkredov.mv_receivables_monthly AS
WITH months AS (
    SELECT (d + INTERVAL '1 month - 1 day')::DATE AS month_end
    FROM generate_series(DATE '2024-01-01', DATE '2025-12-01', INTERVAL '1 month') AS d
)
SELECT 
    m.month_end,
    d.customer_id,
    d.customer_name,
    d.credit_limit,
    d.invoiced,
    d.paid,
    d.debt,
    d.overdue_debt
FROM months m
CROSS JOIN LATERAL stud_shkredov.fn_customer_debt(m.month_end) d;

CREATE UNIQUE INDEX ux_mv_receivables_monthly ON stud_shkredov.mv_receivables_monthly (month_end, customer_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY stud_shkredov.mv_receivables_monthly;

COMMENT ON MATERIALIZED VIEW stud_shkredov.mv_receivables_monthly IS 'Материализованная витрина помесячной дебиторской задолженности клиентов за 2024–2025 гг. с поддержкой конкурентного обновления';

-- Контрольная проверка (1 700 строк, 24 месяца, 72 клиента):
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT month_end) AS months_cnt, COUNT(DISTINCT customer_id) AS clients_cnt
FROM stud_shkredov.mv_receivables_monthly;


-- ----------------------------------------------------------------------------
-- Задание А*2 (★). Представление для отдела продаж v_sales_public
-- Скрывает себестоимость и маржу, доступна только выручка и скидки
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW stud_shkredov.v_sales_public AS
SELECT 
    order_item_id,
    order_id,
    order_date,
    customer_id,
    employee_id,
    channel,
    product_id,
    category_id,
    quantity,
    unit_price,
    discount_pct,
    gross_amount,
    discount_amount,
    net_amount
FROM stud_shkredov.v_sales_lines;

COMMENT ON VIEW stud_shkredov.v_sales_public IS 'Ограниченная витрина продаж для менеджеров: исключены данные о себестоимости (standard_cost, cost_amount) и маржинальности (margin)';

-- Проверка обновляемости в information_schema.views:
SELECT table_name, is_updatable, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'stud_shkredov' AND table_name = 'v_sales_public';
-- Вывод: is_updatable = NO. Представление построено на базе v_sales_lines, содержащего JOIN 4 таблиц
-- и вычисляемые выражения, поэтому оно не является автоматически обновляемым по стандарту SQL.


-- ----------------------------------------------------------------------------
-- Задание А*3 (★★). Функция fn_customer_orders_after_limit
-- Возвращает все отгруженные заказы клиента, оформленные при превышении лимита
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stud_shkredov.fn_customer_orders_after_limit(p_customer_id int)
RETURNS TABLE (
    order_id int,
    order_number varchar,
    order_date date,
    status varchar,
    order_revenue numeric,
    debt_on_order_date numeric,
    credit_limit numeric
)
LANGUAGE sql STABLE
AS $$
    SELECT 
        o.order_id,
        o.order_number,
        o.order_date,
        o.status,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)), 2) AS order_revenue,
        d.debt AS debt_on_order_date,
        d.credit_limit
    FROM pitanie.orders o
    JOIN pitanie.order_items oi ON o.order_id = oi.order_id
    CROSS JOIN LATERAL stud_shkredov.fn_customer_debt(o.order_date) d
    WHERE o.customer_id = p_customer_id
      AND d.customer_id = p_customer_id
      AND o.status IN ('Отгружен', 'Доставлен')
      AND d.debt > d.credit_limit
    GROUP BY o.order_id, o.order_number, o.order_date, o.status, d.debt, d.credit_limit
    ORDER BY o.order_date, o.order_id;
$$;

COMMENT ON FUNCTION stud_shkredov.fn_customer_orders_after_limit(int) IS 'Табличная функция выявления всех отгруженных заказов клиента, на момент оформления/отгрузки которых его долг уже превышал установленный кредитный лимит';

-- Проверка для ООО «ТД Вектор» (ровно 22 заказа):
SELECT * FROM stud_shkredov.fn_customer_orders_after_limit(1);
