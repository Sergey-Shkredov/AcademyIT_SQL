-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 5. ПРАКТИЧЕСКАЯ РАБОТА: «Вложенные запросы: от скалярного подзапроса до NOT EXISTS»
-- ИСПОЛНИТЕЛЬ: Команда А («Финансы и продажи»)
-- ============================================================================
-- Файл: lab05_team_a.sql (разделы 1–8 соответствуют шагам работы)
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Среда: только чтение (SELECT), схема pitanie не изменяется
-- ============================================================================

SET search_path TO pitanie, public;

-- Проверка доступности данных (ожидается 17 576):
SELECT COUNT(*) AS total_order_items FROM order_items;


-- ============================================================================
-- ШАГ 1. Скалярный подзапрос в WHERE
-- ============================================================================
-- Задача: сколько позиций продано со скидкой выше средней по компании?

-- 1. Средняя скидка по компании (ожидается 7.25):
SELECT ROUND(AVG(discount_pct), 2) AS avg_discount
FROM order_items;

-- 2. Позиции со скидкой выше средней (ожидается 5 483):
SELECT COUNT(*) AS items_above_avg
FROM order_items
WHERE discount_pct > (
    SELECT AVG(discount_pct) 
    FROM order_items
);

/*
Подумайте: Почему нельзя написать WHERE discount_pct > AVG(discount_pct)?
- По порядку выполнения SQL (FROM -> WHERE -> GROUP BY -> HAVING -> SELECT -> ORDER BY)
  блок WHERE фильтрует отдельные строки ДО группировки и вычисления агрегатных функций.
  В момент прохода WHERE значение AVG(discount_pct) еще не вычислено, поэтому агрегаты в WHERE запрещены.
- Скалярный подзапрос вычисляется заранее как единая константа (7.25) и подставляется в сравнение.
*/

-- Типичная ошибка: скалярный подзапрос вернул более 1 строки (закомментировано для безопасного прогона файла)
/*
SELECT product_name
FROM products
WHERE base_price = (SELECT base_price FROM products WHERE category_id = 13);
-- ERROR: more than one row returned by a subquery used as an expression
*/

-- Исправление ошибки: использование IN (...) или = ANY (...):
SELECT product_name, base_price
FROM products
WHERE base_price IN (
    SELECT base_price 
    FROM products 
    WHERE category_id = 13
);


-- ============================================================================
-- ШАГ 2. Многострочный подзапрос: IN, ANY, ALL
-- ============================================================================

-- 1. Клиенты из Сибирского федерального округа (ожидается 15 клиентов):
SELECT customer_id, customer_name, customer_type
FROM customers
WHERE region_id IN (
    SELECT region_id
    FROM regions
    WHERE federal_district = 'Сибирский'
)
ORDER BY customer_name;

-- 2. Товары дороже ЛЮБОГО печенья/вафель (category_id = 21) (ожидается 15 строк, от 112.00):
SELECT product_name, base_price
FROM products
WHERE base_price > ALL (
    SELECT base_price 
    FROM products 
    WHERE category_id = 21
)
ORDER BY base_price;

-- 3. Ловушка пустого набора (> ALL vs > MAX):
SELECT COUNT(*) AS all_on_empty_set
FROM products
WHERE base_price > ALL (
    SELECT base_price 
    FROM products 
    WHERE category_id = 999
);
-- Ожидаемый результат: 35 (все продукты, т.к. ALL над пустым набором истинно — vacuously true!)

SELECT COUNT(*) AS max_on_empty_set
FROM products
WHERE base_price > (
    SELECT MAX(base_price) 
    FROM products 
    WHERE category_id = 999
);
-- Ожидаемый результат: 0 (MAX от пустого набора равен NULL, сравнение с NULL дает UNKNOWN!)

/*
Подумайте: В каком бизнес-отчёте такая разница может привести к неверному выводу?
- Например, в отчёте «Найти заказы крупнее любого возвращённого заказа за месяц» или
  «Товары дороже всех акционных товаров категории Х». Если за выбранный период возвратов или акций
  не было (пустой набор), оператор > ALL ошибочно вернет ВСЕ 100% заказов/товаров как «аномальные»,
  тогда как > (SELECT MAX(...)) корректно вернет пустой результат (0 строк).
*/


-- ============================================================================
-- ШАГ 3. Производная таблица в FROM
-- ============================================================================
-- Многошаговый расчет показателей менеджеров с последующей сортировкой:

SELECT 
    m.employee_id, 
    e.full_name, 
    m.items, 
    m.avg_discount, 
    m.discount_rub
FROM (
    SELECT 
        o.employee_id,
        COUNT(*) AS items,
        ROUND(AVG(oi.discount_pct), 2) AS avg_discount,
        ROUND(SUM(oi.quantity * oi.unit_price * oi.discount_pct / 100)) AS discount_rub
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status <> 'Отменён'
    GROUP BY o.employee_id
) AS m
JOIN employees AS e ON e.employee_id = m.employee_id
ORDER BY m.discount_rub DESC;

/*
Ожидаемый фрагмент:
- 10 | Соколов Игорь Андреевич  | 4167 | 18.01 | 38 779 099
- 11 | Морозова Елена Павловна  | 3625 | 4.02  | 10 324 708
- 16 | Павлов Сергей Дмитриевич | 1590 | 5.23  | 7 095 398

Подумайте: Политика компании — скидка не более 10 %. Что говорит средняя скидка 18 % у одного менеджера?
Что ещё нужно проверить, прежде чем идти к руководству?
1. Проверить круг клиентов: возможно, скидки 15-25% предоставляются одному или нескольким VIP-клиентам
   по согласованному индивидуальному контракту с директором.
2. Проверить маржинальность этих сделок (не продается ли товар ниже себестоимости standard_cost).
3. Проверить временной период (разовая акция/распродажа или систематическое нарушение на протяжении всех лет).
4. Проверить роль канала продаж и согласование условий руководителем отдела продаж (Ершовой Т. Ю.).
*/


-- ============================================================================
-- ШАГ 4. Коррелированный подзапрос — «для каждой строки»
-- ============================================================================

-- 1. Продукты дороже средней цены своей категории (ожидается 14 строк):
SELECT p.product_name, p.category_id, p.base_price
FROM products AS p
WHERE p.base_price > (
    SELECT AVG(p2.base_price)
    FROM products AS p2
    WHERE p2.category_id = p.category_id
)
ORDER BY p.category_id, p.base_price DESC;

-- 2. Производственные партии с браком выше среднего по своей линии:
SELECT b.line_id, b.shift, COUNT(*) AS batches_above_line_avg
FROM production_batches AS b
WHERE 1.0 * b.defect_qty / b.produced_qty > (
    SELECT 1.0 * SUM(b2.defect_qty) / SUM(b2.produced_qty)
    FROM production_batches AS b2
    WHERE b2.line_id = b.line_id
)
GROUP BY b.line_id, b.shift
ORDER BY b.line_id, b.shift;

-- Дополнительное расследование по Линии 3 для ответа на вопрос «Подумайте»:
SELECT 
    b.line_id,
    b.shift,
    COUNT(*) AS total_batches,
    ROUND(100.0 * SUM(b.defect_qty) / SUM(b.produced_qty), 2) AS avg_defect_pct,
    ROUND(100.0 * MIN(1.0 * b.defect_qty / b.produced_qty), 2) AS min_batch_defect_pct,
    ROUND(100.0 * MAX(1.0 * b.defect_qty / b.produced_qty), 2) AS max_batch_defect_pct
FROM production_batches b
WHERE b.line_id = 3
GROUP BY b.line_id, b.shift
ORDER BY b.shift;
/*
Подумайте: Почему у Линии 3 нет строки «День»? Что это значит для команды Б?
- В дневную смену на Линии 3 (627 партий) брак составляет всего 0.74% - 2.48% (в среднем 1.62%).
- В ночную смену (627 партий) брак взлетает до 5.98% - 9.97% (в среднем 7.94% — почти в 5 раз выше!).
- Средний взвешенный брак по всей Линии 3 составляет ~4.78%.
- Поскольку даже максимальный брак дневной смены (2.48%) ниже среднего по линии (4.78%), НИ ОДНА дневная партия
  не попала в выборку. Зато ВСЕ 100% ночных партий (627 из 627) превысили средний показатель!
- Для Команды Б это сигнал о критическом технологическом сбое или нарушении дисциплины в ночную смену на Линии 3.
*/

-- 3. Последний заказ каждого клиента:
SELECT c.customer_name, o.order_number, o.order_date
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
WHERE o.order_date = (
    SELECT MAX(o2.order_date)
    FROM orders o2
    WHERE o2.customer_id = c.customer_id
)
ORDER BY o.order_date
LIMIT 10;

-- 4. Топ-2 самых дорогих продукта в каждой категории (ожидается 14 строк: 7 категорий x 2):
SELECT p.category_id, p.product_name, p.base_price
FROM products AS p
WHERE (
    SELECT COUNT(*)
    FROM products p2
    WHERE p2.category_id = p.category_id
      AND p2.base_price > p.base_price
) < 2
ORDER BY p.category_id, p.base_price DESC;


-- ============================================================================
-- ШАГ 5. EXISTS / NOT EXISTS и ловушка NOT IN + NULL
-- ============================================================================

-- 1. Клиенты без заказов в последние 3 месяца (с 01.10.2025) (ожидается 2 строки):
SELECT c.customer_id, c.customer_name
FROM customers AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.order_date >= DATE '2025-10-01'
);
-- Результат: 71 | ооо "Свежесть"  и  73 | ООО "Новый горизонт"

-- 2. Проверка дубля «ооо "Свежесть"» с помощью подзапроса по ИНН:
SELECT c.customer_id, c.customer_name, c.inn
FROM customers AS c
WHERE c.inn IN (
    SELECT c2.inn
    FROM customers AS c2
    WHERE c2.customer_id = 71
);
/*
Подумайте: Не дубль ли это другого клиента? Как проверить по ИНН?
- Подзапрос по ИНН выявил, что клиент 71 (ооо "Свежесть") имеет ИНН 8423916122 — точно такой же,
  как у действующего крупного клиента 8 (АО "Свежесть")!
- Вывод: клиент не ушёл из компании, просто заказы с октября стали оформляться на основную карточку № 8.
*/

-- 3. Ловушка NOT IN + NULL (поиск сотрудников, которые никем не руководят):
SELECT COUNT(*) AS not_in_result
FROM employees
WHERE employee_id NOT IN (SELECT manager_id FROM employees);
-- Ожидаемый результат: 0 (!), т.к. у генерального директора manager_id IS NULL!

SELECT COUNT(*) AS not_exists_result
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 
    FROM employees s 
    WHERE s.manager_id = e.employee_id
);
-- Ожидаемый результат: 26 (корректное число рядовых сотрудников без подчиненных).


-- ============================================================================
-- ШАГ 6. Смотрим планы выполнения (EXPLAIN)
-- ============================================================================

-- 1. План для EXISTS (Nested Loop Semi Join + Index Only Scan):
EXPLAIN
SELECT c.customer_id 
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- 2. План для NOT EXISTS (Nested Loop Anti Join + Index Only Scan):
EXPLAIN
SELECT c.customer_id 
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- 3. План для NOT IN (Seq Scan ... Filter: NOT (hashed SubPlan 1)):
EXPLAIN
SELECT COUNT(*) 
FROM employees
WHERE employee_id NOT IN (SELECT manager_id FROM employees);

/*
Подумайте: Коррелированный подзапрос «выполняется для каждой строки» — это логическая модель.
Что на самом деле сделал оптимизатор с EXISTS?
- Оптимизатор PostgreSQL декоррелировал подзапрос и преобразовал его в операцию Semi Join (Nested Loop Semi Join).
- Вместо чтения всех строк таблицы orders он использует индекс ix_orders_customer (Index Only Scan)
  и прерывает поиск по клиенту при обнаружении самого первого совпадения, что работает в разы быстрее.
*/


-- ============================================================================
-- ШАГ 7. Подзапросы в HAVING и ORDER BY
-- ============================================================================
-- Менеджеры со средней скидкой выше средней скидки по компании (ожидается 2 строки):
SELECT 
    o.employee_id, 
    e.full_name, 
    ROUND(AVG(oi.discount_pct), 2) AS avg_discount
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN employees e ON e.employee_id = o.employee_id
GROUP BY o.employee_id, e.full_name
HAVING AVG(oi.discount_pct) > (
    SELECT AVG(discount_pct) 
    FROM order_items
)
ORDER BY avg_discount DESC;
-- Ожидаемый результат: Соколов И. А. (18.02) и Попов С. И. (8.21).


-- ============================================================================
-- ШАГ 8. Подзапрос или JOIN?
-- ============================================================================

-- 1. Число уникальных клиентов на Маркетплейсе (IN проверяет факт наличия -> 3 клиента):
SELECT COUNT(*) AS customers_via_in
FROM customers
WHERE customer_id IN (
    SELECT customer_id 
    FROM orders 
    WHERE channel = 'Маркетплейс'
);

-- 2. Соединение клиентов с заказами (JOIN размножает строки по заказам -> 175 заказов):
SELECT COUNT(*) AS rows_via_join
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id 
             AND o.channel = 'Маркетплейс';

/*
Подумайте: Почему JOIN дал 175? Когда нужен JOIN, а когда — IN/EXISTS?
- JOIN соединяет каждого из 3 клиентов со всеми его заказами на маркетплейсе (175 заказов суммарно).
- JOIN нужен тогда, когда из второй таблицы требуется извлечь столбцы в SELECT или вычислить по ней агрегаты.
- IN / EXISTS нужен тогда, когда необходимо проверить сам факт существования (или отсутствия) связи
  в подчиненной таблице без дублирования строк основной таблицы (1:N).
*/
