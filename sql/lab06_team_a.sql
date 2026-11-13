-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 6. ЛАБОРАТОРНАЯ РАБОТА №6: 
-- «Объединение наборов: единые журналы и сравнение периодов»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab06_team_a.sql
-- Исполнители: Команда А «Финансы и продажи»
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Дата среза данных: 31.12.2025
-- ============================================================================

SET search_path TO pitanie, public;

-- ============================================================================
-- ОБЩАЯ ЧАСТЬ (Все команды)
-- ============================================================================
-- Задание О-1. Подсчет ИНН в справочниках customers и suppliers
-- а) с UNION ALL:
SELECT COUNT(*) AS total_inn_union_all
FROM (
    SELECT inn FROM customers
    UNION ALL
    SELECT inn FROM suppliers
) AS s;
-- Проверка: 85 строк.

-- б) с UNION:
SELECT COUNT(*) AS unique_inn_union
FROM (
    SELECT inn FROM customers
    UNION
    SELECT inn FROM suppliers
) AS s;
-- Проверка: 81 строка.

-- Задание О-2. Где именно повторяются ИНН?
-- Пересечение между справочниками клиентов и поставщиков:
SELECT inn FROM customers
INTERSECT
SELECT inn FROM suppliers;
-- Проверка: 0 строк (клиенты и поставщики не пересекаются по ИНН).

-- Поиск дубликатов внутри каждого справочника:
SELECT inn, COUNT(*) AS count_in_customers
FROM customers 
GROUP BY inn 
HAVING COUNT(*) > 1;
/*
Результат дублирования внутри customers (ровно 4 «лишних» значения):
- ИНН 8423916122:   2 записи (+1 дубль)
- ИНН 562810604315: 2 записи (+1 дубль)
- ИНН 7924695572:   3 записи (+2 дубля)
Сумма дублей: 1 + 1 + 2 = 4 строки.
*/

SELECT inn, COUNT(*) AS count_in_suppliers
FROM suppliers 
GROUP BY inn 
HAVING COUNT(*) > 1;
-- Проверка: 0 строк (в suppliers дубликатов нет).


-- ============================================================================
-- ВАРИАНТ 1 — КОМАНДА А «ФИНАНСЫ И ПРОДАЖИ»
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Задание А-1. Единая лента «движения денег»
-- ----------------------------------------------------------------------------
-- Собрать в один набор с помощью UNION ALL:
-- - счета: 'Счёт', customer_id, invoice_date, amount;
-- - оплаты: 'Оплата', customer_id (через invoices -> orders), payment_date, amount;
-- - возвраты: 'Возврат', customer_id, return_date, сумма = quantity * цена со скидкой.
-- Проверка: 3 строки; счетов 4 242, оплат 4 519, возвратов 308.

WITH cash_flow AS (
    SELECT 
        'Счёт' AS op_type,
        o.customer_id,
        i.invoice_date AS op_date,
        i.amount
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id

    UNION ALL

    SELECT 
        'Оплата' AS op_type,
        o.customer_id,
        p.payment_date AS op_date,
        p.amount
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.invoice_id
    JOIN orders o ON i.order_id = o.order_id

    UNION ALL

    SELECT 
        'Возврат' AS op_type,
        o.customer_id,
        ret.return_date AS op_date,
        ROUND(ret.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0), 2) AS amount
    FROM returns ret
    JOIN orders o ON ret.order_id = o.order_id
    JOIN order_items oi ON ret.order_id = oi.order_id AND ret.product_id = oi.product_id
)
SELECT 
    op_type,
    COUNT(*) AS documents_count,
    ROUND(SUM(amount), 2) AS total_amount_rub
FROM cash_flow
GROUP BY op_type
ORDER BY op_type;
/*
Результат:
- Возврат:   308 документов на сумму     2 439 507.01 руб.
- Оплата:  4 519 документов на сумму   764 917 216.04 руб.
- Счёт:    4 242 документов на сумму   821 243 564.75 руб.
*/


-- ----------------------------------------------------------------------------
-- Задание А-2. Лента по одному клиенту (customer_id = 1)
-- ----------------------------------------------------------------------------
-- Вывести помесячно за 2025 г. для клиента с customer_id = 1 (ООО «ТД Вектор»):
-- выставлено, оплачено, изменение долга.
-- Проверка: 12 строк.

WITH client_flow AS (
    SELECT 
        'Счёт' AS op_type,
        i.invoice_date AS op_date,
        i.amount
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id
    WHERE o.customer_id = 1 
      AND i.invoice_date >= '2025-01-01' AND i.invoice_date <= '2025-12-31'

    UNION ALL

    SELECT 
        'Оплата' AS op_type,
        p.payment_date AS op_date,
        p.amount
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.invoice_id
    JOIN orders o ON i.order_id = o.order_id
    WHERE o.customer_id = 1
      AND p.payment_date >= '2025-01-01' AND p.payment_date <= '2025-12-31'
)
SELECT 
    TO_CHAR(m.mon_date, 'YYYY-MM') AS month_name,
    COALESCE(SUM(cf.amount) FILTER (WHERE cf.op_type = 'Счёт'), 0) AS invoiced_rub,
    COALESCE(SUM(cf.amount) FILTER (WHERE cf.op_type = 'Оплата'), 0) AS paid_rub,
    COALESCE(SUM(cf.amount) FILTER (WHERE cf.op_type = 'Счёт'), 0) -
    COALESCE(SUM(cf.amount) FILTER (WHERE cf.op_type = 'Оплата'), 0) AS debt_change_rub
FROM generate_series(DATE '2025-01-01', DATE '2025-12-01', INTERVAL '1 month') AS m(mon_date)
LEFT JOIN client_flow cf ON DATE_TRUNC('month', cf.op_date) = m.mon_date
GROUP BY m.mon_date
ORDER BY m.mon_date;
/*
Ответы на вопросы к А-2:
1. В скольких месяцах оплат не было вообще?
   В 5 месяцах из 12 (Март, Июнь, Сентябрь, Октябрь, Декабрь 2025 г.) оплата = 0.00 руб.
2. В каком месяце прирост долга максимален?
   В декабре 2025 г. (+1 540 300.27 руб.), на втором месте ноябрь 2025 г. (+1 030 013.17 руб.).
   Клиент наращивал долг перед закрытием года без погашения.
*/


-- ----------------------------------------------------------------------------
-- Задание А-3. Кто перестал покупать (EXCEPT)
-- ----------------------------------------------------------------------------
-- 1. Клиенты, покупавшие в 2024 г., но не покупавшие в 2025 г. (ожидается 0 строк):
SELECT customer_id FROM orders 
WHERE order_date >= '2024-01-01' AND order_date <= '2024-12-31' AND status <> 'Отменён'
EXCEPT
SELECT customer_id FROM orders 
WHERE order_date >= '2025-01-01' AND order_date <= '2025-12-31' AND status <> 'Отменён';
-- Проверка: 0 строк (клиентская база не имеет полного оттока).

-- 2. Исчезнувшие пары «клиент — товар» (ожидается 127 пар, из них 31 по снятому продукту):
WITH lost_pairs AS (
    SELECT o.customer_id, oi.product_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31' 
      AND o.status <> 'Отменён'
    EXCEPT
    SELECT o.customer_id, oi.product_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31' 
      AND o.status <> 'Отменён'
)
SELECT 
    COUNT(*) AS total_lost_pairs,
    COUNT(*) FILTER (WHERE p.is_active = FALSE) AS discontinued_lost_pairs,
    COUNT(*) FILTER (WHERE p.is_active = TRUE) AS active_lost_pairs
FROM lost_pairs lp
JOIN products p ON lp.product_id = p.product_id;
-- Проверка: ровно 127 пар, из них 31 по снятым продуктам (is_active = FALSE), 96 по активным.

-- 3. Оценка выручки 2024 г. по исчезнувшим парам (CROSS JOIN LATERAL):
WITH lost_pairs AS (
    SELECT o.customer_id, oi.product_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31' 
      AND o.status <> 'Отменён'
    EXCEPT
    SELECT o.customer_id, oi.product_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31' 
      AND o.status <> 'Отменён'
)
SELECT 
    COUNT(lp.customer_id) AS pairs_count,
    ROUND(SUM(rev_2024.revenue), 2) AS lost_revenue_2024_rub
FROM lost_pairs lp
CROSS JOIN LATERAL (
    SELECT SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.customer_id = lp.customer_id 
      AND oi.product_id = lp.product_id
      AND o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31'
      AND o.status <> 'Отменён'
) AS rev_2024;
-- Результат: 8 223 886.16 руб. базовой выручки 2024 года потеряно в этих связках.

-- 4. ★ Клиент, полностью переставший покупать целую категорию верхнего уровня (ожидается 1 строка):
WITH cat_2024 AS (
    SELECT DISTINCT o.customer_id, COALESCE(pc_sub.parent_category_id, pc_sub.category_id) AS parent_cat_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_categories pc_sub ON p.category_id = pc_sub.category_id
    WHERE o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31' 
      AND o.status <> 'Отменён'
),
cat_2025 AS (
    SELECT DISTINCT o.customer_id, COALESCE(pc_sub.parent_category_id, pc_sub.category_id) AS parent_cat_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_categories pc_sub ON p.category_id = pc_sub.category_id
    WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31' 
      AND o.status <> 'Отменён'
),
lost_cats AS (
    SELECT customer_id, parent_cat_id FROM cat_2024
    EXCEPT
    SELECT customer_id, parent_cat_id FROM cat_2025
)
SELECT 
    lc.customer_id, 
    c.customer_name, 
    lc.parent_cat_id, 
    pc.category_name AS lost_category_name
FROM lost_cats lc
JOIN customers c ON lc.customer_id = c.customer_id
JOIN product_categories pc ON lc.parent_cat_id = pc.category_id;
-- Проверка: ровно 1 строка — клиент id 50 (ООО "Партнёр") полностью бросил категорию "Бакалея" (parent_id = 3).


-- ----------------------------------------------------------------------------
-- Задание А-4. Продажи-лидеры и лидеры возвратов (INTERSECT и EXCEPT)
-- ----------------------------------------------------------------------------
-- Топ-10 по выручке:
-- (SELECT ...)
-- Топ-10 по сумме возвратов:
-- (SELECT ...)

-- 1. Пересечение топов (INTERSECT) (ожидается 4 продукта):
(
    SELECT oi.product_id, p.product_name
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.status <> 'Отменён'
    GROUP BY oi.product_id, p.product_name
    ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) DESC
    LIMIT 10
)
INTERSECT
(
    SELECT ret.product_id, p.product_name
    FROM returns ret
    JOIN orders o ON ret.order_id = o.order_id
    JOIN order_items oi ON ret.order_id = oi.order_id AND ret.product_id = oi.product_id
    JOIN products p ON ret.product_id = p.product_id
    GROUP BY ret.product_id, p.product_name
    ORDER BY SUM(ret.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) DESC
    LIMIT 10
);
/*
Результат INTERSECT (4 продукта):
- Масло сливочное 82,5% 180 г (product_id = 13)
- Соус сырный 200 г (product_id = 31)
- Конфеты шоколадные ассорти 200 г (product_id = 26)
- Сливки 33% 0,5 л (product_id = 5)
*/

-- 2. В топе возвратов, но НЕ в топе выручки (EXCEPT) (ожидается 6 продуктов):
WITH top_rev AS (
    SELECT oi.product_id, p.product_name
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.status <> 'Отменён'
    GROUP BY oi.product_id, p.product_name
    ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) DESC
    LIMIT 10
),
top_ret AS (
    SELECT ret.product_id, p.product_name
    FROM returns ret
    JOIN orders o ON ret.order_id = o.order_id
    JOIN order_items oi ON ret.order_id = oi.order_id AND ret.product_id = oi.product_id
    JOIN products p ON ret.product_id = p.product_id
    GROUP BY ret.product_id, p.product_name
    ORDER BY SUM(ret.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) DESC
    LIMIT 10
)
SELECT tr.product_id, tr.product_name, p.shelf_life_days
FROM (
    SELECT product_id, product_name FROM top_ret
    EXCEPT
    SELECT product_id, product_name FROM top_rev
) tr
JOIN products p ON tr.product_id = p.product_id
ORDER BY p.shelf_life_days, tr.product_name;
/*
Результат EXCEPT (6 продуктов):
- Йогурт клубничный 2,5% 0,3 кг   (7 дней)
- Йогурт черничный 2,5% 0,3 кг    (7 дней)
- Кефир 2,5% 0,9 л                (10 дней)
- Молоко пастеризованное 2,5% 1 л (10 дней)
- Молоко пастеризованное 3,2% 1 л (10 дней)
- Ряженка 4% 0,5 л                (10 дней)
Вывод: все 6 позиций имеют ультракороткий срок годности (7-10 дней) и возвращаются
не из-за больших объемов продаж, а из-за истечения срока годности в пути (логистика).
*/


-- ----------------------------------------------------------------------------
-- Задание А-5. Top-3 скидки каждого менеджера (LATERAL)
-- ----------------------------------------------------------------------------
-- 1. CROSS JOIN LATERAL (ожидается 27 строк: 9 активных менеджеров по 3 позиции):
SELECT 
    e.employee_id,
    e.full_name AS manager_name,
    top3.order_id,
    top3.product_id,
    top3.discount_rub
FROM employees e
CROSS JOIN LATERAL (
    SELECT 
        oi.order_id,
        oi.product_id,
        ROUND(oi.quantity * oi.unit_price * oi.discount_pct / 100.0, 2) AS discount_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.employee_id = e.employee_id
      AND o.status <> 'Отменён'
    ORDER BY discount_rub DESC
    LIMIT 3
) top3
ORDER BY e.employee_id, top3.discount_rub DESC;
-- Проверка: ровно 27 строк.

-- 2. По всем сотрудникам отдела «Продажи» (LEFT JOIN LATERAL ... ON TRUE) (ожидается 29 строк):
SELECT 
    e.employee_id,
    e.full_name AS employee_name,
    e.position,
    top3.order_id,
    top3.discount_rub
FROM employees e
LEFT JOIN LATERAL (
    SELECT 
        oi.order_id,
        oi.product_id,
        ROUND(oi.quantity * oi.unit_price * oi.discount_pct / 100.0, 2) AS discount_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.employee_id = e.employee_id
      AND o.status <> 'Отменён'
    ORDER BY discount_rub DESC
    LIMIT 3
) top3 ON TRUE
WHERE e.department = 'Продажи'
ORDER BY e.employee_id, top3.discount_rub DESC NULLS LAST;
/*
Проверка: ровно 29 строк (добавились Коммерческий директор Громов А. И. и 
Руководитель отдела продаж Ершова Т. Ю., которые лично не оформляли заказы в orders).
*/


-- ----------------------------------------------------------------------------
-- Задание А-6 ★. Лидер скидок по месяцам (generate_series + LATERAL)
-- ----------------------------------------------------------------------------
-- Сгенерировать месяцы 2025 г. и найти менеджера с максимальной суммой скидок в каждом месяце:
SELECT 
    m.mon_date::date AS month_date,
    lead.employee_id,
    lead.full_name AS leader_name,
    lead.total_discount_rub
FROM generate_series(DATE '2025-01-01', DATE '2025-12-01', INTERVAL '1 month') AS m(mon_date)
CROSS JOIN LATERAL (
    SELECT 
        e.employee_id,
        e.full_name,
        ROUND(SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100.0), 2) AS total_discount_rub
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN employees e ON o.employee_id = e.employee_id
    WHERE o.order_date >= m.mon_date 
      AND o.order_date < m.mon_date + INTERVAL '1 month'
      AND o.status <> 'Отменён'
    GROUP BY e.employee_id, e.full_name
    ORDER BY total_discount_rub DESC
    LIMIT 1
) lead
ORDER BY month_date;
/*
Проверка: ровно 12 строк.
Ответ на вопрос: Один ли и тот же менеджер во всех месяцах?
ДА! Во ВСЕХ 12 месяцах 2025 года лидером по сумме скидок является исключительно
Соколов Игорь Андреевич (от 1.08 млн до 2.23 млн руб. скидок ежемесячно!).
*/


-- ----------------------------------------------------------------------------
-- Задание А-7 ★. Цена ошибки UNION
-- ----------------------------------------------------------------------------
-- Собрать ленту «счета + оплаты» из столбцов customer_id, дата, сумма (без признака типа)
-- с UNION ALL и с UNION:

-- 1. С UNION ALL (ожидается 8 761 строка):
SELECT COUNT(*) AS count_union_all 
FROM (
    SELECT o.customer_id, i.invoice_date AS op_date, i.amount
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id
    UNION ALL
    SELECT o.customer_id, p.payment_date AS op_date, p.amount
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.invoice_id
    JOIN orders o ON i.order_id = o.order_id
) s1;
-- Результат: 8 761 строка (4 242 счетов + 4 519 оплат).

-- 2. С UNION (ожидается 8 703 строки):
SELECT COUNT(*) AS count_union 
FROM (
    SELECT o.customer_id, i.invoice_date AS op_date, i.amount
    FROM invoices i
    JOIN orders o ON i.order_id = o.order_id
    UNION
    SELECT o.customer_id, p.payment_date AS op_date, p.amount
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.invoice_id
    JOIN orders o ON i.order_id = o.order_id
) s2;
-- Результат: 8 703 строки.
/*
Объяснение цены ошибки:
Разница составляет 58 строк (8 761 - 8 703).
При использовании обычного UNION без ALL СУБД производит автоматическую дедупликацию строк.
В результате исчезают:
1) реальные повторные операции клиента за день (несколько счетов на одну сумму в один день);
2) дробные платежи одинакового размера в одну дату;
3) счета и оплаты, совпавшие день-в-день на полную сумму счета (одинаковые customer_id, дата, сумма).
В финансовом учете и лентах операций UNION недопустим — необходимо строго использовать UNION ALL!
*/
