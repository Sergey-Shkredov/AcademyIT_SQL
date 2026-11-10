-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 3. ЛАБОРАТОРНАЯ РАБОТА: «Извлечение данных из нескольких таблиц»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab03_team_a.sql
-- Исполнители: Команда А «Финансы и продажи»
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Дата среза данных: 31.12.2025
-- ============================================================================

SET search_path TO pitanie, public;

-- ============================================================================
-- ОБЩАЯ ЧАСТЬ (Обе команды)
-- ============================================================================

-- 1. Подсчет количества строк в рабочих таблицах Команды А
-- Фиксируем базовые размеры таблиц для контроля отсутствия неконтролируемого
-- «размножения» строк (декартова произведения / дублирования при 1:N)
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'product_categories', COUNT(*) FROM product_categories
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'returns', COUNT(*) FROM returns
UNION ALL SELECT 'regions', COUNT(*) FROM regions
UNION ALL SELECT 'employees', COUNT(*) FROM employees;
/*
Результат подсчета:
- customers:          73 строки
- orders:             4 458 строк
- order_items:        17 576 строк
- products:           35 строк
- product_categories: 10 строк
- invoices:           4 242 строки
- payments:           4 519 строк
- returns:            308 строк
- regions:            12 строк
- employees:          35 строк
*/

-- 2. Цепочка связей для Команды А:
--   customers (1) ──< orders (N) ──< order_items (N) >── products (1) >── product_categories (1)
--   orders (1) ──< invoices (N) ──< payments (N)
--   orders (1) ──< returns (N)
--   regions (1) ──< customers (N)
--   employees (1, руководитель) ──< employees (N, подчиненные) [SELF-JOIN]

-- 3. Анализ кардинальности (1:N) и возможности NULL во внешних ключах:
-- * Связи «один ко многим» (1:N):
--   - customers -> orders: у одного клиента может быть много заказов.
--   - orders -> order_items: в одном заказе содержится несколько товарных позиций.
--   - products -> order_items: один продукт продается во множестве заказов.
--   - product_categories -> products: в одной категории содержится несколько товаров.
--   - orders -> invoices: по одному заказу формируется счет (в системе допускается 1:N).
--   - invoices -> payments: один счет может оплачиваться несколькими платежами (частичная оплата).
--   - orders -> returns: по одному заказу может быть зарегистрировано несколько возвратов.
--   - regions -> customers: в одном регионе зарегистрировано несколько клиентов.
--   - employees -> orders: один менеджер оформляет множество заказов.
--   - employees -> employees: один руководитель курирует нескольких сотрудников.
--
-- * Где возможен NULL во внешнем ключе (требует обязательного LEFT JOIN):
--   - customers.region_id: у 3 клиентов регион не указан (NULL), на них приходится 84 заказа!
--   - employees.manager_id: у высшего руководителя (Генеральный директор) нет начальника (NULL).
--   - payments: у некоторых счетов еще нет оплат (Anti-join: payments.payment_id IS NULL).
--   - orders: у некоторых клиентов в декабре нет заказов (orders.order_id IS NULL).


-- ============================================================================
-- ВАРИАНТ 1 — КОМАНДА А «ФИНАНСЫ И ПРОДАЖИ»
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Задание А1. Заказы 2025 года с клиентом, регионом и менеджером
-- ----------------------------------------------------------------------------
-- Условие:
-- Выведите номер и дату заказа, название клиента, регион, ФИО менеджера
-- (из orders.employee_id) для заказов 2025 г., кроме отменённых (status <> 'Отменён').
-- Подсказки: orders -> customers -> regions, orders -> employees.
-- У некоторых клиентов нет региона — подумайте, какой JOIN нужен, и замените
-- NULL на «не указан» через COALESCE.
-- Проверка: 2240 строк. Если 2156 — потеряно 84 заказа клиентов без региона.

SELECT 
    o.order_number,
    o.order_date,
    c.customer_name,
    COALESCE(r.region_name, 'не указан') AS region_name,
    e.full_name AS manager_name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
JOIN employees e ON o.employee_id = e.employee_id
WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
  AND o.status <> 'Отменён'
ORDER BY o.order_date, o.order_number;

-- Проверка количества строк (ровно 2240):
SELECT COUNT(*) AS check_a1_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
JOIN employees e ON o.employee_id = e.employee_id
WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
  AND o.status <> 'Отменён';
-- Результат: 2240 строк.


-- ----------------------------------------------------------------------------
-- Задание А2. Скидки сверх политики: менеджер и его руководитель
-- ----------------------------------------------------------------------------
-- Условие:
-- Политика компании — скидка не более 10 %. Выведите позиции заказов 2025 г.
-- (кроме отменённых) со скидкой > 10%: номер заказа, дату, менеджера,
-- руководителя менеджера, продукт, количество, цену, скидку.
-- Подсказки: руководитель — это тоже строка employees: присоедините таблицу
-- второй раз под другим псевдонимом по manager_id.
-- Проверка: 2088 строк.
-- Затем (GROUP BY) посчитайте число таких позиций по каждому менеджеру за весь период.
-- Сколько менеджеров нарушают политику? Кто их руководитель?

-- 1. Детальный список позиций со скидкой > 10% (2088 строк):
SELECT 
    o.order_number,
    o.order_date,
    e.full_name AS manager_name,
    m.full_name AS supervisor_name,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.discount_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN employees e ON o.employee_id = e.employee_id
LEFT JOIN employees m ON e.manager_id = m.employee_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
  AND o.status <> 'Отменён'
  AND oi.discount_pct > 10
ORDER BY o.order_date, o.order_number, oi.discount_pct DESC;

-- Проверка количества строк (ровно 2088):
SELECT COUNT(*) AS check_a2_count
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN employees e ON o.employee_id = e.employee_id
LEFT JOIN employees m ON e.manager_id = m.employee_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
  AND o.status <> 'Отменён'
  AND oi.discount_pct > 10;
-- Результат: 2088 строк.

-- 2. Группировка: число нарушений по менеджерам за весь период
SELECT 
    e.employee_id,
    e.full_name AS manager_name,
    m.full_name AS supervisor_name,
    COUNT(*) AS discount_violation_count,
    MIN(oi.discount_pct) AS min_discount,
    MAX(oi.discount_pct) AS max_discount
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN employees e ON o.employee_id = e.employee_id
LEFT JOIN employees m ON e.manager_id = m.employee_id
WHERE oi.discount_pct > 10
GROUP BY e.employee_id, e.full_name, m.full_name
ORDER BY discount_violation_count DESC;
/*
Ответ на вопросы задания А2:
1. Политику нарушают всего 2 менеджера:
   - Соколов Игорь Андреевич (id = 10): 4 312 позиций с превышением скидок (от 12% до 25%).
   - Попов Станислав Игоревич (id = 60): 53 позиции со скидкой 12%.
2. Руководитель обоих менеджеров-нарушителей:
   - Ершова Татьяна Юрьевна (Руководитель отдела продаж, employee_id = 4).
   Это свидетельствует о полном отсутствии контроля со стороны прямого руководителя.
*/


-- ----------------------------------------------------------------------------
-- Задание А3. Кто оформляет заказы «чужих» клиентов
-- ----------------------------------------------------------------------------
-- Условие:
-- У клиента есть закреплённый менеджер (customers.manager_id), а у заказа —
-- оформивший его менеджер (orders.employee_id). Найдите заказы, где они не совпадают;
-- выведите обоих менеджеров по ФИО.
-- Подсказки: employees нужно присоединить два раза — по двум разным связям.
-- Проверка: 35 строк.

SELECT 
    o.order_id,
    o.order_number,
    o.order_date,
    c.customer_name,
    ord_emp.full_name AS order_manager_name,     -- Оформивший менеджер
    cust_emp.full_name AS assigned_manager_name  -- Закрепленный менеджер
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN employees ord_emp ON o.employee_id = ord_emp.employee_id
JOIN employees cust_emp ON c.manager_id = cust_emp.employee_id
WHERE o.employee_id <> c.manager_id
ORDER BY o.order_date, o.order_number;

-- Проверка количества строк (ровно 35):
SELECT COUNT(*) AS check_a3_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN employees ord_emp ON o.employee_id = ord_emp.employee_id
JOIN employees cust_emp ON c.manager_id = cust_emp.employee_id
WHERE o.employee_id <> c.manager_id;
-- Результат: 35 строк.


-- ----------------------------------------------------------------------------
-- Задание А4. Счета без единой оплаты
-- ----------------------------------------------------------------------------
-- Условие:
-- Найдите счета, по которым не поступило ни одной оплаты, с клиентом и
-- закреплённым менеджером. Отдельным запросом — сколько из них имеют
-- срок оплаты (due_date) раньше 01.01.2026 и на какую сумму.
-- Подсказки: anti-join: invoices LEFT JOIN payments … WHERE p.payment_id IS NULL.
-- Проверка: 229 счетов; просроченных на конец периода — 60 на 10 699 261,89 руб.

-- 1. Список всех неоплаченных счетов (229 счетов):
SELECT 
    i.invoice_id,
    i.invoice_number,
    i.invoice_date,
    i.due_date,
    i.amount,
    c.customer_name,
    e.full_name AS assigned_manager_name
FROM invoices i
LEFT JOIN payments p ON i.invoice_id = p.invoice_id
JOIN orders o ON i.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN employees e ON c.manager_id = e.employee_id
WHERE p.payment_id IS NULL
ORDER BY i.due_date, i.amount DESC;

-- Проверка общего числа счетов без оплат (ровно 229):
SELECT COUNT(*) AS check_a4_unpaid_count
FROM invoices i
LEFT JOIN payments p ON i.invoice_id = p.invoice_id
WHERE p.payment_id IS NULL;
-- Результат: 229 счетов.

-- 2. Счета, просроченные на конец расчетного периода (due_date < '2026-01-01'):
SELECT 
    COUNT(*) AS overdue_unpaid_invoices_cnt,
    SUM(i.amount) AS total_overdue_unpaid_amount
FROM invoices i
LEFT JOIN payments p ON i.invoice_id = p.invoice_id
WHERE p.payment_id IS NULL
  AND i.due_date < '2026-01-01';
/*
Результат проверки:
- Количество счетов: 60 счетов
- Сумма долга:       10 699 261,89 руб.
*/


-- ----------------------------------------------------------------------------
-- Задание А5. Клиент с долгом выше кредитного лимита
-- ----------------------------------------------------------------------------
-- Условие:
-- 1. Сгруппируйте неоплаченные счета (из А4) по клиенту: число счетов, сумма,
--    кредитный лимит (customers.credit_limit). Отсортируйте по сумме. Кто на первом месте?
-- 2. Для клиента-лидера посчитайте полный долг = сумма всех его счетов - сумма всех его оплат.
-- 3. Сравните долг с кредитным лимитом. Выведите неоплаченные счета клиента: продолжались ли отгрузки?
-- Подсказки: не считайте SUM(i.amount) и SUM(p.amount) в одном запросе с JOIN payments —
-- сумма счетов «размножится». Сделайте два запроса.
-- Проверка: лидер — клиент с id 1; неоплаченных счетов — 31;
-- сумма всех счетов — 14 716 047,93, оплат — 7 808 447,48.

-- 1. Группировка неоплаченных счетов по клиентам:
SELECT 
    c.customer_id,
    c.customer_name,
    c.credit_limit,
    COUNT(i.invoice_id) AS unpaid_invoices_count,
    SUM(i.amount) AS unpaid_invoices_sum
FROM invoices i
LEFT JOIN payments p ON i.invoice_id = p.invoice_id
JOIN orders o ON i.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE p.payment_id IS NULL
GROUP BY c.customer_id, c.customer_name, c.credit_limit
ORDER BY unpaid_invoices_sum DESC
LIMIT 5;
/*
Лидер рейтинга должников:
- customer_id:            1
- customer_name:          ООО "Торговый дом Вектор"
- credit_limit:           3 000 000,00 руб.
- unpaid_invoices_count:  31 счет
- unpaid_invoices_sum:    5 689 975,85 руб. (только полностью неоплаченные счета)
*/

-- 2. Расчет полного долга клиента-лидера (customer_id = 1) с учетом частичных оплат:
-- Во избежание декартова размножения сумм считаем счетовые начисления и платежи раздельно
SELECT 
    (SELECT SUM(i.amount) 
     FROM invoices i 
     JOIN orders o ON i.order_id = o.order_id 
     WHERE o.customer_id = 1) AS total_invoiced,
    (SELECT SUM(p.amount) 
     FROM payments p 
     JOIN invoices i ON p.invoice_id = i.invoice_id 
     JOIN orders o ON i.order_id = o.order_id 
     WHERE o.customer_id = 1) AS total_paid,
    (SELECT SUM(i.amount) 
     FROM invoices i 
     JOIN orders o ON i.order_id = o.order_id 
     WHERE o.customer_id = 1) - 
    (SELECT SUM(p.amount) 
     FROM payments p 
     JOIN invoices i ON p.invoice_id = i.invoice_id 
     JOIN orders o ON i.order_id = o.order_id 
     WHERE o.customer_id = 1) AS total_debt;
/*
Результат:
- total_invoiced: 14 716 047,93 руб.
- total_paid:      7 808 447,48 руб.
- total_debt:      6 907 600,45 руб.
Кредитный лимит клиента: 3 000 000,00 руб.
Превышение лимита: в 2,3 раза (долг превышает норматив на 3 907 600,45 руб.)!
*/

-- 3. Вывод неоплаченных счетов лидера:
SELECT 
    i.invoice_number,
    i.invoice_date,
    i.due_date,
    i.amount,
    o.order_number,
    o.shipped_date,
    o.status
FROM invoices i
LEFT JOIN payments p ON i.invoice_id = p.invoice_id
JOIN orders o ON i.order_id = o.order_id
WHERE o.customer_id = 1
  AND p.payment_id IS NULL
ORDER BY i.due_date;
-- Ответ: Отгрузки клиенту не прекращались, несмотря на растущий дефолт!


-- ----------------------------------------------------------------------------
-- Задание А6. Возвраты: продукт, категория, регион
-- ----------------------------------------------------------------------------
-- Условие:
-- Выведите возвраты с продуктом, сроком годности (shelf_life_days), подкатегорией,
-- клиентом, регионом, федеральным округом, причиной и сроком доставки (shipped_date - order_date).
-- Затем посчитайте (COUNT(*)): сколько возвратов в Сибирском ФО по причине «Истёк срок годности».
-- Проверка: 308 строк (не потеряйте возвраты клиентов без региона!);
-- Сибирь + «Истёк срок годности» — 171.

-- 1. Подробный реестр всех возвратов (308 строк):
SELECT 
    ret.return_id,
    ret.return_date,
    p.product_name,
    p.shelf_life_days,
    pc.category_name,
    c.customer_name,
    COALESCE(r.region_name, 'не указан') AS region_name,
    COALESCE(r.federal_district, 'не указан') AS federal_district,
    ret.reason,
    ret.quantity,
    (o.shipped_date - o.order_date) AS delivery_days
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN products p ON ret.product_id = p.product_id
JOIN product_categories pc ON p.category_id = pc.category_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
ORDER BY ret.return_date, ret.return_id;

-- Проверка общего числа возвратов (ровно 308):
SELECT COUNT(*) AS check_a6_total_returns
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN products p ON ret.product_id = p.product_id
JOIN product_categories pc ON p.category_id = pc.category_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id;
-- Результат: 308 строк.

-- 2. Подсчет возвратов в Сибирском ФО по причине «Истёк срок годности»:
SELECT COUNT(*) AS siberia_expired_returns_cnt
FROM returns ret
JOIN orders o ON ret.order_id = o.order_id
JOIN products p ON ret.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN regions r ON c.region_id = r.region_id
WHERE r.federal_district = 'Сибирский'
  AND ret.reason = 'Истёк срок годности';
-- Результат: ровно 171 возврат.

-- 3. Аналитическое расследование: какие продукты возвращают чаще всего
SELECT 
    p.product_id,
    p.product_name,
    p.shelf_life_days,
    pc.category_name,
    COUNT(*) AS return_count
FROM returns ret
JOIN products p ON ret.product_id = p.product_id
JOIN product_categories pc ON p.category_id = pc.category_id
GROUP BY p.product_id, p.product_name, p.shelf_life_days, pc.category_name
ORDER BY return_count DESC
LIMIT 5;
/*
Аналитические выводы к А6:
- Топ возвращаемых товаров:
  1. Йогурт клубничный 2,5% 0,3 кг (срок годности всего 7 дней) — 57 возвратов;
  2. Йогурт черничный 2,5% 0,3 кг (срок годности всего 7 дней) — 53 возврата;
  3. Молоко пастеризованное 3,2% 1 л (срок годности 10 дней) — 31 возврат;
  4. Молоко пастеризованное 2,5% 1 л (срок годности 10 дней) — 31 возврат;
  5. Кефир 2,5% 0,9 л (срок годности 10 дней) — 29 возвратов.
- Что общего у продуктов: критически короткий срок годности (от 7 до 10 дней).
- Что общего у регионов: 55,5% всех возвратов компании (171 из 308) приходятся на Сибирский ФО
  из-за длительного логистического плеча комплектации и доставки (5–9 дней). Продукция приезжает
  на склады ритейла уже просроченной или на грани списания.
*/


-- ----------------------------------------------------------------------------
-- Задание А7. Ловушка ON / WHERE: кто «замолчал» в декабре
-- ----------------------------------------------------------------------------
-- Условие:
-- Выведите всех клиентов и их заказы за декабрь 2025 г. Клиенты без декабрьских
-- заказов должны остаться в результате с NULL. Затем найдите только «замолчавших» клиентов.
-- Проверка: 228 строк, 73 клиента; «замолчавших» — 10.
-- Если у вас 218 строк — условие на дату стоит не там.

-- 1. Полный список клиентов и декабрьских заказов (228 строк, 73 клиента):
SELECT 
    c.customer_id,
    c.customer_name,
    o.order_number,
    o.order_date,
    o.status
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id 
                  AND o.order_date >= '2025-12-01' 
                  AND o.order_date <= '2025-12-31'
ORDER BY c.customer_id, o.order_date;

-- Проверка общего числа строк и уникальных клиентов (228 строк, 73 клиента):
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT c.customer_id) AS total_clients
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id 
                  AND o.order_date >= '2025-12-01' 
                  AND o.order_date <= '2025-12-31';
-- Результат: 228 строк, 73 клиента.

-- 2. Список только «замолчавших» клиентов (10 клиентов):
SELECT 
    c.customer_id,
    c.customer_name,
    c.inn,
    c.phone,
    c.email
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id 
                  AND o.order_date >= '2025-12-01' 
                  AND o.order_date <= '2025-12-31'
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- Проверка числа «замолчавших» клиентов (ровно 10):
SELECT COUNT(*) AS silent_clients_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id 
                  AND o.order_date >= '2025-12-01' 
                  AND o.order_date <= '2025-12-31'
WHERE o.order_id IS NULL;
-- Результат: 10 клиентов.
/*
Объяснение ловушки ON vs WHERE:
- Если поместить фильтр по дате в секцию WHERE:
  LEFT JOIN orders o ON c.customer_id = o.customer_id
  WHERE o.order_date BETWEEN '2025-12-01' AND '2025-12-31'
  то строки с клиентами, у которых o.order_id IS NULL (и, следовательно, o.order_date IS NULL),
  будут отброшены фильтром WHERE, превратив запрос фактически в INNER JOIN (218 строк вместо 228).
- Условие на правую таблицу в LEFT JOIN ОБЯЗАНО находиться в блоке ON!
*/


-- ----------------------------------------------------------------------------
-- Задание А8. Дубли клиентов через SELF-JOIN
-- ----------------------------------------------------------------------------
-- Условие:
-- Найдите пары клиентов с одинаковым ИНН. Каждая пара должна выводиться один раз
-- (без зеркальной (B, A)).
-- Проверка: 5 пар.
-- Подумайте: Как дубли искажают анализ задолженности и выручки по клиентам?

SELECT 
    a.customer_id AS client_1_id,
    a.customer_name AS client_1_name,
    b.customer_id AS client_2_id,
    b.customer_name AS client_2_name,
    a.inn
FROM customers a
JOIN customers b ON a.inn = b.inn AND a.customer_id < b.customer_id
ORDER BY a.inn, a.customer_id;
/*
Результат (ровно 5 пар дублей):
1. ИНН 562810604315: id=9 (ИП Иванов (Колос))  и id=72 (ООО "Колос" (дубль))
2. ИНН 7924695572:   id=2 (ООО "Ромашка")      и id=69 (Ромашка ООО)
3. ИНН 7924695572:   id=2 (ООО "Ромашка")      и id=70 (ООО  "РОМАШКА")
4. ИНН 7924695572:   id=69 (Ромашка ООО)       и id=70 (ООО  "РОМАШКА")
5. ИНН 8423916122:   id=8 (АО "Свежесть")      и id=71 (ооо "Свежесть")

Анализ влияния дублей на бизнес:
1. Искажение кредитного лимита: Кредитный лимит устанавливается на карточку клиента (customer_id).
   Дублирование позволяет контрагенту набрать долгов в 2-3 раза больше разрешенного лимита по ИНН.
2. Искажение дебиторской задолженности: Аналитики и менеджеры видят долг по отдельным карточкам,
   не замечая совокупного дефолта реального юридического лица.
3. Искажение ABC/XYZ анализа продаж: Выручка и объемы дробятся, из-за чего ключевой стратегический
   клиент (категории А) может ошибочно отображаться как мелкий оптовик категории B или C.
*/


-- ----------------------------------------------------------------------------
-- Задание А9*. Пустые ячейки «менеджер × канал»
-- ----------------------------------------------------------------------------
-- Условие:
-- С помощью CROSS JOIN менеджеров по продажам (position = 'Менеджер по продажам')
-- и списка каналов (VALUES ('Прямые продажи'), ('Дистрибуция'), ('Маркетплейс'), ('Тендер'))
-- найдите сочетания, в которых в 2025 г. не было ни одного заказа.
-- Проверка: 14 строк. Объясните, почему у одного менеджера пусты все 4 канала.

SELECT 
    e.employee_id,
    e.full_name AS manager_name,
    c.channel
FROM employees e
CROSS JOIN (VALUES ('Прямые продажи'), ('Дистрибуция'), ('Маркетплейс'), ('Тендер')) AS c(channel)
LEFT JOIN orders o ON o.employee_id = e.employee_id 
                  AND o.channel = c.channel
                  AND o.order_date >= '2025-01-01' 
                  AND o.order_date <= '2025-12-31'
WHERE e.position = 'Менеджер по продажам'
  AND o.order_id IS NULL
ORDER BY e.employee_id, c.channel;

-- Проверка количества строк (ровно 14):
SELECT COUNT(*) AS check_a9_empty_slots
FROM employees e
CROSS JOIN (VALUES ('Прямые продажи'), ('Дистрибуция'), ('Маркетплейс'), ('Тендер')) AS c(channel)
LEFT JOIN orders o ON o.employee_id = e.employee_id 
                  AND o.channel = c.channel
                  AND o.order_date >= '2025-01-01' 
                  AND o.order_date <= '2025-12-31'
WHERE e.position = 'Менеджер по продажам'
  AND o.order_id IS NULL;
-- Результат: 14 строк.
/*
Ответ на вопрос: почему у Попова Станислава Игоревича (employee_id = 60) пусты все 4 канала?
- Анализ данных по таблице orders показал, что в 2025 году у Попова С. И. зафиксировано ровно 0 заказов!
  Все его 35 заказов в базе оформлены в предыдущие годы (2023-2024 гг.).
- Причины: длительный отпуск, декрет, перевод на другие задачи или увольнение, при котором
  карточка сотрудника не была архивирована или деактивирована в кадровой системе.
*/


-- ----------------------------------------------------------------------------
-- Задание А10*. Отгрузки должнику
-- ----------------------------------------------------------------------------
-- Условие:
-- Выведите заказы клиента-лидера из А5 (ООО «Торговый дом Вектор», id = 1),
-- отгруженные после срока оплаты самого раннего неоплаченного счёта.
-- (Можно использовать подзапрос — тема модуля 5.)
-- Проверка: 39 заказов.

SELECT 
    o.order_id,
    o.order_number,
    o.order_date,
    o.shipped_date,
    o.status,
    (SELECT MIN(i.due_date)
     FROM invoices i
     JOIN orders ord ON i.order_id = ord.order_id
     LEFT JOIN payments p ON i.invoice_id = p.invoice_id
     WHERE ord.customer_id = 1
       AND p.payment_id IS NULL) AS earliest_unpaid_due_date
FROM orders o
WHERE o.customer_id = 1
  AND o.shipped_date > (
      SELECT MIN(i.due_date)
      FROM invoices i
      JOIN orders ord ON i.order_id = ord.order_id
      LEFT JOIN payments p ON i.invoice_id = p.invoice_id
      WHERE ord.customer_id = 1
        AND p.payment_id IS NULL
  )
ORDER BY o.shipped_date;

-- Проверка количества заказов (ровно 39):
SELECT COUNT(*) AS check_a10_orders_count
FROM orders o
WHERE o.customer_id = 1
  AND o.shipped_date > (
      SELECT MIN(i.due_date)
      FROM invoices i
      JOIN orders ord ON i.order_id = ord.order_id
      LEFT JOIN payments p ON i.invoice_id = p.invoice_id
      WHERE ord.customer_id = 1
        AND p.payment_id IS NULL
  );
-- Результат: 39 заказов.
/*
Анализ вопиющего нарушения:
- Самый ранний неоплаченный счет лидера (счет № 2031) имел дату оплаты due_date = 2025-01-31.
- Начиная с 02.02.2025 и вплоть до конца года (27.12.2025) клиенту было отгружено 39 новых заказов!
- В компании полностью отсутствует контроль стоп-листа: несмотря на нарастающий кассовый разрыв
  и долг 6,9 млн руб. (превышающий кредитный лимит более чем в 2,3 раза), отгрузки не блокировались.
*/


-- ============================================================================
-- ВОПРОСЫ ДЛЯ ЗАЩИТЫ РАБОТЫ (КОМАНДА А)
-- ============================================================================
/*
1. В каком задании вы использовали LEFT JOIN и что произошло бы с INNER JOIN?
   Ответ:
   - В задании А1: соединение customers c regions. У 3 клиентов region_id IS NULL.
     При INNER JOIN потерялись бы 84 заказа этих клиентов (вывелось бы 2156 строк вместо 2240).
   - В задании А4 (Anti-join): invoices c payments. При INNER JOIN были бы отобраны только
     оплаченные счета, а неоплаченные (цель задания) были бы полностью исключены.
   - В задании А6: customers c regions для возвратов. При INNER JOIN потерялись бы возвраты без региона.
   - В задании А7: customers c orders за декабрь. При INNER JOIN отсеклись бы 10 клиентов,
     не делавших заказов, и мы не смогли бы выявить «замолчавших» контрагентов.
   - В задании А9: CROSS JOIN каналов с заказами через LEFT JOIN. При INNER JOIN потерялись бы
     все неиспользованные каналы (пустые ячейки).

2. Где в вашей работе возможен эффект «размножения строк» и как вы его избежали?
   Ответ:
   - В задании А5 при расчете общего долга клиента: между счетами и платежами существует связь
     1:N (один счет оплачивается несколькими транзакциями). При наивном соединении
     invoices JOIN payments строки счетов продублировались бы по числу платежей, и функция
     SUM(i.amount) завысила бы сумму счетов в несколько раз!
   - Как избежали: разделили расчет на два независимых подзапроса: отдельно вычислили SUM(amount)
     по всем выставленным счетам клиента, и отдельно SUM(amount) по всем поступившим платежам,
     после чего вычли одно из другого.

3. Почему в SELF-JOIN пар используется a.id < b.id?
   Ответ:
   - В задании А8 для дедупликации: a.inn = b.inn AND a.customer_id < b.customer_id.
   - Если использовать a.id != b.id, то каждая пара вернется дважды (A, B) и (B, A).
   - Если использовать a.id = b.id, каждая запись соединится сама с собой.
   - Условие строгого неравенства (<) оставляет только одну уникальную комбинацию для каждой
     пары записей и исключает зеркальные дубли. Для трех одинаковых ИНН получается ровно 3 пары.
*/
