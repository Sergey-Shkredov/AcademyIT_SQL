-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 8. ЛАБОРАТОРНАЯ РАБОТА: «Динамика, рейтинги и ABC-анализ»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab08_team_a.sql
-- Исполнители: Команда А «Финансы и продажи»
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Рабочая схема: pitanie (только чтение)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ПОДГОТОВИТЕЛЬНАЯ ЧАСТЬ: УСТАНОВКА ПУТИ ПОИСКА
-- ----------------------------------------------------------------------------
SET search_path TO pitanie, public;

-- Проверка доступности данных схемы pitanie:
SELECT current_schema();  -- Должно быть: pitanie


-- ============================================================================
-- ЗАДАНИЕ А1. РЕЙТИНГ МЕНЕДЖЕРОВ ПО КВАРТАЛАМ (RANK, DENSE_RANK)
-- ============================================================================
-- Задача:
-- Для каждого квартала 2025 г. и каждого менеджера посчитать выручку и среднюю скидку.
-- Вывести два места: по выручке (RANK DESC) и по средней скидке (DENSE_RANK DESC) внутри квартала.
-- Правило выручки строки: oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100), статус <> 'Отменён'.
-- Проверка: 32 строки (8 менеджеров × 4 квартала).

WITH mgr_quarter AS (
    SELECT 
        EXTRACT(QUARTER FROM o.order_date)::INT AS qtr,
        e.employee_id,
        e.full_name AS manager_name,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)) AS revenue,
        AVG(oi.discount_pct) AS avg_discount_pct
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN employees e ON o.employee_id = e.employee_id
    WHERE o.status <> 'Отменён'
      AND o.order_date >= DATE '2025-01-01' AND o.order_date < DATE '2026-01-01'
    GROUP BY EXTRACT(QUARTER FROM o.order_date), e.employee_id, e.full_name
)
SELECT 
    qtr,
    manager_name,
    ROUND(revenue, 2) AS revenue,
    ROUND(avg_discount_pct, 2) AS avg_discount_pct,
    RANK() OVER (
        PARTITION BY qtr 
        ORDER BY revenue DESC
    ) AS rank_revenue,
    DENSE_RANK() OVER (
        PARTITION BY qtr 
        ORDER BY avg_discount_pct DESC
    ) AS rank_discount
FROM mgr_quarter
ORDER BY qtr, rank_revenue;

-- ОТВЕТЫ НА ВОПРОСЫ К ЗАДАНИЮ А1:
-- 1. Кто занимает 1-е место по скидке во всех кварталах?
--    Соколов Игорь Андреевич (во всех 4-х кварталах занимает стабильное 1-е место).
-- 2. Какая у него средняя скидка?
--    Квартал 1: 17.70 %
--    Квартал 2: 17.94 %
--    Квартал 3: 18.17 %
--    Квартал 4: 18.20 %
--    Среднегодовая скидка Соколова И. А. составляет 18.01 %, что в 3–7 раз превышает
--    показатели добросовестных коллег (у Морозовой Е. П. — 3.9 %, у Новиковой О. И. — 2.9 %).


-- ============================================================================
-- ЗАДАНИЕ А2. НАРАСТАЮЩАЯ ВЫРУЧКА И % ВЫПОЛНЕНИЯ ПЛАНА НАРАСТАЮЩИМ ИТОГОМ
-- ============================================================================
-- Задача:
-- 1. Посчитать факт выручки по месяцам 2024–2025 гг. и план по месяцам (sales_plan).
-- 2. Для каждого месяца вывести: факт, факт нарастающим итогом с начала года,
--    план нарастающим итогом, % выполнения нарастающим итогом.
-- Использовать именованное окно: WINDOW w AS (PARTITION BY yr ORDER BY mon ...).
-- Проверка: 24 строки; выполнение на декабрь: 2024 — 98.0 %, 2025 — 93.2 %.

WITH fact_monthly AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_date)::INT AS yr,
        EXTRACT(MONTH FROM o.order_date)::INT AS mon,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)) AS fact_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'Отменён'
      AND o.order_date >= DATE '2024-01-01' AND o.order_date < DATE '2026-01-01'
    GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
),
plan_monthly AS (
    SELECT 
        plan_year AS yr,
        plan_month AS mon,
        SUM(plan_amount) AS plan_revenue
    FROM sales_plan
    WHERE plan_year IN (2024, 2025)
    GROUP BY plan_year, plan_month
),
combined AS (
    SELECT 
        p.yr,
        p.mon,
        COALESCE(f.fact_revenue, 0) AS fact_revenue,
        p.plan_revenue
    FROM plan_monthly p
    LEFT JOIN fact_monthly f ON p.yr = f.yr AND p.mon = f.mon
)
SELECT 
    yr,
    mon,
    ROUND(fact_revenue, 2) AS fact_revenue,
    ROUND(SUM(fact_revenue) OVER w, 2) AS cum_fact,
    ROUND(SUM(plan_revenue) OVER w, 2) AS cum_plan,
    ROUND(100.0 * SUM(fact_revenue) OVER w / SUM(plan_revenue) OVER w, 2) AS cum_exec_pct
FROM combined
WINDOW w AS (
    PARTITION BY yr 
    ORDER BY mon 
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
ORDER BY yr, mon;

-- ОТВЕТЫ НА ВОПРОСЫ К ЗАДАНИЮ А2:
-- 1. С какого месяца 2025 г. показатель снижается без перерыва?
--    Показатель непрерывно падает начиная с апреля (месяц 4):
--    март (98.55 %) -> апрель (97.77 %) -> май (96.67 %) -> июнь (96.29 %) -> 
--    июль (95.23 %) -> август (94.79 %) -> сентябрь (93.83 %) -> октябрь (93.42 %) -> ноябрь (93.11 %).
-- 2. Сколько рублей недобрано к годовому плану 2025 года?
--    План года: 477 546 000.00 руб., Факт года: 445 107 013.09 руб.
--    Недобор составил 32 438 986.91 руб. (более 32.4 млн рублей недополученной выручки).


-- ============================================================================
-- ЗАДАНИЕ А3. ABC-АНАЛИЗ КЛИЕНТОВ (ДОЛЯ НАРАСТАЮЩИМ ИТОГОМ)
-- ============================================================================
-- Задача:
-- Для выручки 2025 г. по клиентам посчитать долю нарастающим итогом (по убыванию выручки).
-- Присвоить классы: A — до 80 % включительно, B — до 95 %, C — остальные.
-- Вывести сводку: класс, число клиентов, выручка, доля.
-- Проверка: 72 клиента; A — 33 клиента (79.8 %), B — 14 (14.4 %), C — 25 (5.8 %).

WITH cust_rev AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.status <> 'Отменён'
      AND o.order_date >= DATE '2025-01-01' AND o.order_date < DATE '2026-01-01'
    GROUP BY c.customer_id, c.customer_name
),
cust_shares AS (
    SELECT 
        customer_id,
        customer_name,
        revenue,
        100.0 * revenue / SUM(revenue) OVER () AS share_pct,
        100.0 * SUM(revenue) OVER (
            ORDER BY revenue DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(revenue) OVER () AS cum_share_pct
    FROM cust_rev
),
cust_classes AS (
    SELECT 
        customer_id,
        customer_name,
        revenue,
        share_pct,
        cum_share_pct,
        CASE 
            WHEN cum_share_pct <= 80.0 THEN 'A'
            WHEN cum_share_pct <= 95.0 THEN 'B'
            ELSE 'C'
        END AS abc_class
    FROM cust_shares
)
SELECT 
    abc_class,
    COUNT(*) AS customers_count,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM cust_rev), 2) AS revenue_share_pct
FROM cust_classes
GROUP BY abc_class
ORDER BY abc_class;

-- АНАЛИТИЧЕСКИЙ ВОПРОС:
-- В какой класс попадет ООО «Торговый дом Вектор»? Должен ли класс A автоматически означать «хороший клиент»?
-- Ответ:
-- ООО «ТД Вектор» занимает 20-е место с выручкой 8 143 865.27 руб. и нарастающей долей 60.18 %,
-- поэтому попадает в КЛАСС A.
-- Однако класс A НЕ ОЗНАЧАЕТ «хороший клиент»! ABC-анализ по валовой выручке слеп к платежной
-- дисциплине и кредитным рискам. Выбрав товара на 8.14 млн руб., «Вектор» накопил дефолтный долг
-- 6.91 млн руб., парализовав оборотные средства компании. Без наложения кредитного скоринга
-- ориентация только на ABC-класс создает иллюзию высокой надежности проблемного контрагента.


-- ============================================================================
-- ЗАДАНИЕ А4. ИЗМЕНЕНИЕ ВЫРУЧКИ К ПРЕДЫДУЩЕМУ МЕСЯЦУ И К ПРОШЛОМУ ГОДУ (LAG)
-- ============================================================================
-- Задача:
-- Для каждого месяца вывести выручку, изменение к предыдущему месяцу (%) (MoM)
-- и к тому же месяцу прошлого года (YoY, lag(revenue, 12)).
-- Проверка: 24 строки; сильнейшее падение MoM в 2025 г. — июль (-25.1 %);
-- это единственный месяц 2025 г. с падением год к году (-23.3 %).

WITH monthly_rev AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_date)::INT AS yr,
        EXTRACT(MONTH FROM o.order_date)::INT AS mon,
        TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status <> 'Отменён'
      AND o.order_date >= DATE '2024-01-01' AND o.order_date < DATE '2026-01-01'
    GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date), TO_CHAR(o.order_date, 'YYYY-MM')
),
calc_lag AS (
    SELECT 
        yr,
        mon,
        year_month,
        ROUND(revenue, 2) AS revenue,
        LAG(revenue, 1) OVER (ORDER BY yr, mon) AS prev_month_revenue,
        LAG(revenue, 12) OVER (ORDER BY yr, mon) AS prev_year_revenue
    FROM monthly_rev
)
SELECT 
    yr,
    mon,
    year_month,
    revenue,
    ROUND(100.0 * (revenue - prev_month_revenue) / prev_month_revenue, 2) AS mom_change_pct,
    ROUND(100.0 * (revenue - prev_year_revenue) / prev_year_revenue, 2) AS yoy_change_pct
FROM calc_lag
ORDER BY yr, mon;

-- АНАЛИТИЧЕСКИЙ ВОПРОС:
-- Что произошло в июле 2025 года? Какие данные команды Б помогут проверить?
-- Ответ:
-- Сопоставление с производственными данными Команды Б (equipment_downtime и production_batches)
-- выявило системную производственную катастрофу в июле 2025 года:
-- 1. На Линии 2 произошла череда тяжелых поломок (гомогенизатор, насос, уплотнения маслообразователя)
--    с суммарным простоем более 52.5 часов.
-- 2. Возник острый дефицит ключевого сырья («молочный жир» и «молоко»).
-- 3. На Линии 3 зафиксирован незакрытый простой с 28.07.2025 из-за отсутствия молока.
-- В итоге выпуск готовой продукции рухнул на 37 % (с 386 тыс. упаковок до 244 тыс.),
-- образовался дефицит на складе готовой продукции, что и привело к падению выручки на 25.1 % MoM и 23.3 % YoY.


-- ============================================================================
-- ЗАДАНИЕ А5. ИНТЕРВАЛЫ МЕЖДУ ЗАКАЗАМИ И ДНИ ПРОСРОЧКИ (LAG, НАРАСТАЮЩИЙ ДОЛГ)
-- ============================================================================

-- ЧАСТЬ 1: Средний интервал между заказами в 2024 и 2025 гг. (Top-5 по росту интервала)
-- Проверка: первым идет ИП Носов (Шанс): 19.1 -> 60.9 дня (рост +41.8 дня).

WITH order_diffs AS (
    SELECT 
        o.customer_id,
        o.order_date,
        EXTRACT(YEAR FROM o.order_date)::INT AS yr,
        o.order_date - LAG(o.order_date) OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_date, o.order_id
        ) AS days_diff
    FROM orders o
    WHERE o.status <> 'Отменён'
),
yearly_avg AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(*) FILTER (WHERE yr = 2024) AS orders_2024_cnt,
        AVG(days_diff) FILTER (WHERE yr = 2024) AS avg_interval_2024,
        AVG(days_diff) FILTER (WHERE yr = 2025) AS avg_interval_2025
    FROM order_diffs od
    JOIN customers c ON od.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name
    HAVING COUNT(*) FILTER (WHERE yr = 2024) >= 10
)
SELECT 
    customer_id,
    customer_name,
    orders_2024_cnt,
    ROUND(avg_interval_2024, 1) AS avg_interval_2024,
    ROUND(avg_interval_2025, 1) AS avg_interval_2025,
    ROUND(avg_interval_2025 - avg_interval_2024, 1) AS interval_growth
FROM yearly_avg
ORDER BY interval_growth DESC
LIMIT 5;


-- ЧАСТЬ 2: Посчетный аудит долга и просрочки ООО «ТД Вектор» (customer_id = 1)
-- Проверка:
-- - Долг на конец периода: 6 907 600.45 руб.
-- - Лимит 3 млн руб. превышен 03.07.2025.
-- - После превышения лимита выставлено ровно 22 счета.

WITH inv_base AS (
    SELECT 
        i.invoice_id,
        i.invoice_number,
        i.invoice_date,
        i.due_date,
        i.amount,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        MAX(p.payment_date) AS last_payment_date
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id
    LEFT JOIN payments p ON i.invoice_id = p.invoice_id
    WHERE o.customer_id = 1
    GROUP BY i.invoice_id, i.invoice_number, i.invoice_date, i.due_date, i.amount
),
inv_calc AS (
    SELECT 
        invoice_id,
        invoice_number,
        invoice_date,
        due_date,
        amount,
        paid_amount,
        (amount - paid_amount) AS invoice_debt,
        GREATEST(0, COALESCE(last_payment_date, DATE '2025-12-31') - due_date) AS delay_days,
        SUM(amount - paid_amount) OVER (
            ORDER BY invoice_date, invoice_id 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_debt
    FROM inv_base
)
SELECT 
    invoice_id,
    invoice_number,
    invoice_date,
    due_date,
    ROUND(amount, 2) AS amount,
    ROUND(paid_amount, 2) AS paid_amount,
    ROUND(invoice_debt, 2) AS invoice_debt,
    delay_days,
    delay_days - LAG(delay_days) OVER (ORDER BY invoice_date, invoice_id) AS delay_diff,
    ROUND(running_debt, 2) AS running_debt
FROM inv_calc
ORDER BY invoice_date, invoice_id;

-- Проверочный подсчет счетов после превышения лимита 3 млн руб.:
WITH inv_base AS (
    SELECT 
        i.invoice_id,
        i.invoice_date,
        i.amount,
        COALESCE(SUM(p.amount), 0) AS paid_amount
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id
    LEFT JOIN payments p ON i.invoice_id = p.invoice_id
    WHERE o.customer_id = 1
    GROUP BY i.invoice_id, i.invoice_date, i.amount
),
inv_running AS (
    SELECT 
        invoice_id,
        invoice_date,
        SUM(amount - paid_amount) OVER (
            ORDER BY invoice_date, invoice_id 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_debt
    FROM inv_base
),
breach AS (
    SELECT MIN(invoice_date) AS breach_date
    FROM inv_running
    WHERE running_debt > 3000000.00
)
SELECT 
    (SELECT breach_date FROM breach) AS limit_breach_date,
    COUNT(*) AS invoices_after_breach
FROM inv_running
WHERE invoice_date >= (SELECT breach_date FROM breach);
-- Возвращает: дата превышения 2025-07-03, счетов выставлено (включая дату превышения) 23, строго после нее — 22.


-- ============================================================================
-- ЗАДАНИЕ А6. ТОП-3 ПРОДУКТА ПО ВОЗВРАТАМ В КАЖДОМ РЕГИОНЕ
-- ============================================================================
-- Задача:
-- Для каждого региона найти 3 продукта с наибольшим числом возвращенных единиц (DENSE_RANK).
-- Добавить общий объем возвратов региона (SUM OVER PARTITION BY region) и отсортировать по нему.
-- Проверка: первые два региона — Новосибирская обл. (15 355 ед.) и Красноярский край (8 377 ед.);
-- в их топ-3 — оба йогурта и молоко 3.2 %.

WITH reg_prod_returns AS (
    SELECT 
        COALESCE(rg.region_name, 'Без региона') AS region_name,
        p.product_id,
        p.product_name,
        SUM(r.quantity) AS returned_qty
    FROM returns r
    JOIN orders o ON r.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN regions rg ON c.region_id = rg.region_id
    JOIN products p ON r.product_id = p.product_id
    GROUP BY COALESCE(rg.region_name, 'Без региона'), p.product_id, p.product_name
),
ranked AS (
    SELECT 
        region_name,
        product_id,
        product_name,
        returned_qty,
        SUM(returned_qty) OVER (PARTITION BY region_name) AS region_total_returns,
        DENSE_RANK() OVER (PARTITION BY region_name ORDER BY returned_qty DESC) AS drnk
    FROM reg_prod_returns
)
SELECT 
    region_name,
    drnk,
    product_name,
    returned_qty,
    region_total_returns
FROM ranked
WHERE drnk <= 3
ORDER BY region_total_returns DESC, region_name, drnk, product_name;

-- АНАЛИТИЧЕСКИЙ ВОПРОС:
-- Какое свойство этих продуктов объясняет картину?
-- Ответ:
-- Ультракороткий срок годности скоропортящейся молочной продукции (7–10 дней)
-- в условиях экстремально длинного логистического плеча (3 000 – 4 000 км в Сибирь).
-- На два сибирских региона приходится 23 732 из 31 849 единиц всех возвратов компании (74.5 %).
-- Задержки в пути приводят к тому, что товар поступает в торговые точки с критическим
-- или истекшим сроком годности, порождая массовые возвраты.


-- ============================================================================
-- ЗАДАНИЕ А7*. СКИДКИ СВЕРХ ПОЛИТИКИ (PERCENT_RANK, ФИЛЬТРЫ)
-- ============================================================================
-- Задача:
-- По каждому менеджеру (за весь период) посчитать долю позиций со скидкой > 10 %,
-- сумму скидок в рублях (quantity * unit_price * discount_pct / 100)
-- и PERCENT_RANK по сумме скидок.
-- Проверка: у Соколова И. А. 100 % позиций сверх политики и 38.78 млн руб. скидок;
-- у Попова С. И. (уволен) — 39.8 %.

WITH mgr_discounts AS (
    SELECT 
        e.employee_id,
        e.full_name AS manager_name,
        e.position,
        COUNT(*) AS total_items,
        COUNT(*) FILTER (WHERE oi.discount_pct > 10) AS over_policy_items,
        100.0 * COUNT(*) FILTER (WHERE oi.discount_pct > 10) / COUNT(*) AS over_policy_share_pct,
        SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100) AS total_discount_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN employees e ON o.employee_id = e.employee_id
    WHERE o.status <> 'Отменён'
    GROUP BY e.employee_id, e.full_name, e.position
)
SELECT 
    employee_id,
    manager_name,
    position,
    total_items,
    over_policy_items,
    ROUND(over_policy_share_pct, 1) AS over_policy_share_pct,
    ROUND(total_discount_rub, 2) AS total_discount_rub,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_discount_rub)::NUMERIC, 3) AS discount_pct_rank
FROM mgr_discounts
ORDER BY total_discount_rub DESC;

-- ИТОГ АНАЛИЗА ЗАДАНИЯ А7*:
-- Соколов И. А. имеет PERCENT_RANK = 1.000, абсолютный рекорд по сумме скидок (38 779 098.61 руб.)
-- и 100.0 % позиций с нарушением корпоративной политики скидок (> 10 %).
-- Единственный второй нарушитель — уволенный ранее Попов С. И. (39.8 % строк с превышением).
-- Все остальные менеджеры компании строго соблюдают регламент (0.0 % позиций выше 10 %).
