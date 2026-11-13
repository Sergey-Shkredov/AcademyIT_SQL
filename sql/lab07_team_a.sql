-- ============================================================================
-- КУРС «УГЛУБЛЁННЫЙ SQL» · СКВОЗНОЙ КЕЙС «ПИТАНИЕ +» · POSTGRESQL 16
-- МОДУЛЬ 7. ЛАБОРАТОРНАЯ РАБОТА: «Наводим порядок в данных»
-- КОМАНДА А: «Финансы и продажи» (Вариант 1)
-- ============================================================================
-- Файл: lab07_team_a.sql
-- Исполнители: Команда А «Финансы и продажи»
-- СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)
-- Личная схема: stud_shkredov
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ОБЩАЯ ЧАСТЬ: ПОДКЛЮЧЕНИЕ И УСТАНОВКА ПУТИ ПОИСКА
-- ----------------------------------------------------------------------------
-- Устанавливаем путь поиска в личную схему (строго НЕ pitanie):
SET search_path TO stud_shkredov, pitanie, public;

-- Проверка текущей активной схемы:
SELECT current_schema();  -- Должно быть stud_shkredov

-- Проверка доступности загруженного прайс-листа 2026 года (36 строк):
SELECT COUNT(*) AS pl_2026_total_rows FROM price_list_2026;


-- ============================================================================
-- ЗАДАНИЕ А1. ЧИСТКА E-MAIL КЛИЕНТОВ (UPDATE С ВЫРАЖЕНИЕМ)
-- ============================================================================
-- Задача: привести customers.email к нижнему регистру без пробелов по краям;
-- пустую строку заменить на NULL.
-- Правило безопасности: SELECT перед изменением.

-- 1. Предварительный подсчет строк, требующих обновления:
SELECT COUNT(*) AS emails_to_clean
FROM customers
WHERE email IS DISTINCT FROM NULLIF(LOWER(BTRIM(email)), '');
-- Проверка: 32 строки.

-- 2. Безопасное обновление в транзакции:
BEGIN;

UPDATE customers
SET email = NULLIF(LOWER(BTRIM(email)), '')
WHERE email IS DISTINCT FROM NULLIF(LOWER(BTRIM(email)), '');
-- Сервер возвращает: UPDATE 32

-- 3. Контрольный запрос: грязных email не осталось
SELECT COUNT(*) AS dirty_emails_remaining
FROM customers
WHERE email <> LOWER(BTRIM(email));
-- Проверка: 0 строк.

COMMIT;


-- ============================================================================
-- ЗАДАНИЕ А2. ЕДИНЫЙ ФОРМАТ ТЕЛЕФОНОВ (UPDATE ... FROM ПОДЗАПРОСА)
-- ============================================================================
-- Задача: привести все телефоны клиентов к формату +7 (XXX) XXX-XX-XX.

-- 1. Анализ длин и первых цифр очищенных телефонных номеров:
SELECT 
    LENGTH(REGEXP_REPLACE(phone, '\D', '', 'g')) AS digits_len,
    SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 1 FOR 1) AS first_digit,
    COUNT(*) AS phones_count
FROM customers
GROUP BY 1, 2;
-- Вывод: все номера содержат ровно 11 цифр и начинаются с 7 (42 номера) или 8 (31 номер).

-- 2. Подсчет номеров, еще не приведенных к эталонному формату:
SELECT COUNT(*) AS phones_to_format
FROM customers
WHERE phone !~ '^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$'
  AND LENGTH(REGEXP_REPLACE(phone, '\D', '', 'g')) = 11
  AND SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 1 FOR 1) IN ('7', '8');
-- Проверка: 50 строк.

-- 3. Безопасное обновление в транзакции:
BEGIN;

UPDATE customers
SET phone = FORMAT('+7 (%s) %s-%s-%s',
                   SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 2 FOR 3),
                   SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 5 FOR 3),
                   SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 8 FOR 2),
                   SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 10 FOR 2))
WHERE phone !~ '^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$'
  AND LENGTH(REGEXP_REPLACE(phone, '\D', '', 'g')) = 11
  AND SUBSTRING(REGEXP_REPLACE(phone, '\D', '', 'g') FROM 1 FOR 1) IN ('7', '8');
-- Сервер возвращает: UPDATE 50

-- 4. Контрольный запрос: проверка всех 73 номеров по регулярному выражению:
SELECT COUNT(*) AS valid_formatted_phones
FROM customers
WHERE phone ~ '^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$';
-- Проверка: 73 строки (100% номеров соответствуют формату).

COMMIT;


-- ============================================================================
-- ЗАДАНИЕ А3. НАЙТИ ДУБЛИ КЛИЕНТОВ И СОСТАВИТЬ ТАБЛИЦУ СООТВЕТСТВИЙ
-- ============================================================================
-- 1. Поиск ИНН, под которыми заведено более одного клиента:
SELECT 
    inn, 
    COUNT(*) AS records_count, 
    ARRAY_AGG(customer_id ORDER BY customer_id) AS customer_ids
FROM customers
GROUP BY inn
HAVING COUNT(*) > 1;
-- Проверка: 3 ИНН, 7 карточек (4 дубля).

-- 2. Создание таблицы сопоставления дублей:
DROP TABLE IF EXISTS customer_merge_map;

CREATE TABLE customer_merge_map (
    dup_id   integer PRIMARY KEY,
    main_id  integer REFERENCES customers(customer_id),
    inn      varchar(12) NOT NULL,
    dup_name varchar(150) NOT NULL
);

-- 3. Заполнение customer_merge_map одной командой INSERT ... SELECT с RETURNING:
WITH ranked_customers AS (
    SELECT 
        customer_id,
        customer_name,
        inn,
        MIN(customer_id) OVER (PARTITION BY inn) AS min_id
    FROM customers
    WHERE inn IN (
        SELECT inn FROM customers GROUP BY inn HAVING COUNT(*) > 1
    )
)
INSERT INTO customer_merge_map (dup_id, main_id, inn, dup_name)
SELECT 
    customer_id, 
    min_id, 
    inn, 
    customer_name
FROM ranked_customers
WHERE customer_id <> min_id
ORDER BY inn, customer_id
RETURNING *;
-- Проверка: ровно 4 строки (дубли 72 -> 9, 69 -> 2, 70 -> 2, 71 -> 8).


-- ============================================================================
-- ЗАДАНИЕ А4. ОБЪЕДИНИТЬ ДУБЛИ (UPDATE ... FROM + DELETE ... USING)
-- ============================================================================
-- 1. Предварительный подсчет заказов, подлежащих переносу:
SELECT COUNT(*) AS orders_to_reassign
FROM orders o
JOIN customer_merge_map m ON o.customer_id = m.dup_id;
-- Проверка: 179 заказов.

-- Эксперимент: Что будет, если поменять команды местами (DELETE перед UPDATE)?
-- Проверяем внутри транзакции с немедленным откатом (ROLLBACK):
/*
BEGIN;
DELETE FROM customers c USING customer_merge_map m WHERE c.customer_id = m.dup_id;
-- ОШИБКА: update or delete on table "customers" violates foreign key constraint
-- "orders_customer_id_fkey" on table "orders"
-- ПРИЧИНА: Заказы дублей ссылаются на удаляемый customer_id. Сначала нужно перенести внешние ключи!
ROLLBACK;
*/

-- 2. Выполнение корректного объединения в транзакции:
BEGIN;

-- Перенос заказов дублей на основные записи:
UPDATE orders o
SET customer_id = m.main_id
FROM customer_merge_map m
WHERE o.customer_id = m.dup_id;
-- Сервер возвращает: UPDATE 179

-- Удаление записей-дублей из справочника клиентов:
DELETE FROM customers c
USING customer_merge_map m
WHERE c.customer_id = m.dup_id;
-- Сервер возвращает: DELETE 4

-- 3. Контрольные проверки:
SELECT COUNT(*) AS remaining_customers_count FROM customers;
-- Проверка: 69 клиентов.

SELECT COUNT(*) AS romashka_orders_count
FROM orders
WHERE customer_id = 2;
-- Проверка: ровно 230 заказов (было 51 собственный + 179 перенесенных).

COMMIT;

-- 4. Анализ выручки объединенного клиента №2 («Ромашка»):
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS total_revenue_rub
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.customer_id = 2 
  AND o.status <> 'Отменён'
GROUP BY c.customer_id, c.customer_name;
-- Результат: 230 заказов, выручка 50 894 689.06 руб. Клиент поднялся в топ-3 ключевых сетей компании!


-- ============================================================================
-- ЗАДАНИЕ А5. MERGE НОВОГО ПРАЙС-ЛИСТА В СПРАВОЧНИК ТОВАРОВ
-- ============================================================================
-- 1. Анализ прайса 2026 г. с помощью LEFT JOIN:
SELECT 
    COUNT(*) FILTER (WHERE p.sku IS NOT NULL AND p.base_price <> pl.price) AS price_changed,
    COUNT(*) FILTER (WHERE p.sku IS NOT NULL AND p.base_price = pl.price) AS price_same,
    COUNT(*) FILTER (WHERE p.sku IS NULL) AS new_sku
FROM price_list_2026 pl
LEFT JOIN products p ON pl.sku = p.sku;
-- Проверка: 23 изменили цену, 10 не изменили, 3 новых товара.

-- 2. Применение MERGE в транзакции:
BEGIN;

MERGE INTO products p
USING price_list_2026 pl ON (p.sku = pl.sku)
WHEN MATCHED AND p.base_price <> pl.price THEN
    UPDATE SET base_price = pl.price
WHEN NOT MATCHED THEN
    INSERT (sku, product_name, category_id, unit, weight_kg, shelf_life_days, 
            base_price, standard_cost, is_active, launch_date)
    VALUES (pl.sku, pl.product_name, pl.category_id, pl.unit, pl.weight_kg, pl.shelf_life_days, 
            pl.price, pl.standard_cost, TRUE, pl.valid_from);
-- Сервер возвращает: MERGE 26 (23 обновления + 3 вставки).

-- 3. Вывод из ассортимента товаров, отсутствующих в новом прайсе:
UPDATE products
SET is_active = FALSE,
    discontinued_date = DATE '2025-12-31'
WHERE is_active = TRUE 
  AND sku NOT IN (SELECT sku FROM price_list_2026);
-- Сервер возвращает: UPDATE 1 (SKU SOU-002 «Соус сливочно-чесночный 200 г»).

/*
Ответ на вопрос: Почему вывод из ассортимента нельзя сделать внутри MERGE в PostgreSQL 16?
В стандарте SQL и реализации PostgreSQL 16 поддерживаются только секции:
- WHEN MATCHED (совпадение по ключу)
- WHEN NOT MATCHED [BY TARGET] (вставка новых строк из источника)
Секция WHEN NOT MATCHED BY SOURCE (строки целевой таблицы, отсутствующие в источнике)
в синтаксисе PostgreSQL 16 не поддерживается, поэтому закрытие позиций выполняется отдельным UPDATE.
*/

-- 4. Контрольный запрос по структуре каталога:
SELECT 
    COUNT(*) AS total_products,
    COUNT(*) FILTER (WHERE is_active = TRUE) AS active_products,
    COUNT(*) FILTER (WHERE is_active = FALSE) AS inactive_products
FROM products;
-- Проверка: всего товаров 38, активных 36, выведенных 2 (SOU-002 и ранее снятый PEC-006).

COMMIT;


-- ============================================================================
-- ЗАДАНИЕ А6. ИСТОРИЯ ЦЕН (SCD-2): ЗАКРЫТЬ СТАРЫЕ ЦЕНЫ, ОТКРЫТЬ НОВЫЕ
-- ============================================================================
-- Обе команды выполняются строго в одной транзакции для гарантии целостности истории
-- (исключаются ситуации отсутствия цены или задвоения открытых цен).

BEGIN;

-- 1. Закрываем действующие цены 31.12.2025, которые изменились или товар выведен 31.12.2025:
UPDATE price_history ph
SET valid_to = DATE '2025-12-31'
FROM products p
WHERE ph.product_id = p.product_id
  AND ph.valid_to IS NULL
  AND (ph.price <> p.base_price OR p.discontinued_date = DATE '2025-12-31');
-- Сервер возвращает: UPDATE 24 (23 изменившие цену + 1 выведенный соус).

-- 2. Открываем цены 2026 г. с 01.01.2026 для всех активных товаров без открытой цены:
INSERT INTO price_history (product_id, price, valid_from, valid_to)
SELECT p.product_id, p.base_price, DATE '2026-01-01', NULL
FROM products p
WHERE p.is_active = TRUE
  AND NOT EXISTS (
      SELECT 1 FROM price_history ph 
      WHERE ph.product_id = p.product_id AND ph.valid_to IS NULL
  );
-- Сервер возвращает: INSERT 0 26 (23 обновленных + 3 новых).

-- 3. Контрольный запрос SCD-2:
SELECT 
    (SELECT COUNT(*) FROM products WHERE is_active = TRUE) AS active_products,
    (SELECT COUNT(*) FROM price_history WHERE valid_to IS NULL) AS open_prices_count,
    (SELECT COUNT(*) 
     FROM products p 
     JOIN price_history ph ON p.product_id = ph.product_id AND ph.valid_to IS NULL 
     WHERE p.is_active = TRUE AND p.base_price <> ph.price) AS price_mismatches;
-- Проверка: активных товаров 36, с действующей ценой 36, расхождений 0.

COMMIT;


-- ============================================================================
-- ЗАДАНИЕ А7. ЦЕНА НИЖЕ СЕБЕСТОИМОСТИ (CTE С МОДИФИКАЦИЕЙ ДАННЫХ)
-- ============================================================================
-- 1. Поиск активных товаров с базовой ценой со скидкой 10% ниже standard_cost:
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.base_price,
    ROUND(p.base_price * 0.90, 2) AS price_minus_10pct,
    p.standard_cost,
    CEIL(p.standard_cost * 1.25) AS target_new_price
FROM products p
WHERE p.is_active = TRUE
  AND p.base_price * 0.90 < p.standard_cost;
-- Проверка: 2 товара — Масло 82.5% (цена 189, себестоимость 205) и Масло 72.5% (цена 159, себестоимость 151).

-- 2. Фактическая валовая маржа этих товаров за 2025 г.:
SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS sold_qty_2025,
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct / 100.0) - p.standard_cost)), 2) AS gross_margin_2025_rub
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_date >= '2025-01-01' AND o.order_date <= '2025-12-31'
  AND o.status <> 'Отменён'
  AND p.product_id IN (13, 14)
GROUP BY p.product_id, p.product_name;
-- Масло 82.5%: -3 871 935.10 руб., Масло 72.5%: -312 880.49 руб.
-- Суммарный убыток: -4 184 815.59 руб. (около -4.2 млн руб.).

-- 3. Одной командой модифицируем каталог и историю цен через CTE:
BEGIN;

WITH target_products AS (
    SELECT product_id, CEIL(standard_cost * 1.25) AS new_price
    FROM products
    WHERE is_active = TRUE 
      AND base_price * 0.90 < standard_cost
),
upd_products AS (
    UPDATE products p
    SET base_price = tp.new_price
    FROM target_products tp
    WHERE p.product_id = tp.product_id
    RETURNING p.product_id, p.base_price
),
closed_history AS (
    UPDATE price_history ph
    SET valid_to = DATE '2026-01-31'
    FROM target_products tp
    WHERE ph.product_id = tp.product_id 
      AND ph.valid_to IS NULL
    RETURNING ph.product_id
)
INSERT INTO price_history (product_id, price, valid_from, valid_to)
SELECT product_id, base_price, DATE '2026-02-01', NULL
FROM upd_products;

-- Контроль новых цен:
SELECT product_id, sku, product_name, base_price
FROM products
WHERE product_id IN (13, 14);
-- Проверка: новые цены 257.00 и 189.00 руб.

COMMIT;

/*
Подумайте:
1. Почему коммерческая служба не исправила цены в прайсе 2026 года?
   Коммерческий отдел ориентировался на конкурентное позиционирование на полке и жесткие требования
   федеральных сетей, зафиксировав старые розничные цены без согласования с планово-экономическим отделом.
2. Какие данные запросить у Команды Б (Производство и закупки)?
   - Закупочные цены на молочное сырье (молоко-сырье, сливки) в purchase_order_items;
   - Фактический удельный расход жиросырья на выработку тонны масла в material_consumption;
   - Технологические потери и брак на линии маслоделия в production_batches.
*/


-- ============================================================================
-- ЗАДАНИЕ А8. СТОП-ЛИСТ ДОЛЖНИКОВ
-- ============================================================================
-- 1. Создание таблицы credit_stop_list:
DROP TABLE IF EXISTS credit_stop_list;

CREATE TABLE credit_stop_list (
    stop_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  integer UNIQUE NOT NULL REFERENCES customers(customer_id),
    debt         numeric(12,2) NOT NULL,
    credit_limit numeric(12,2) NOT NULL,
    reason       text NOT NULL,
    added_at     timestamp NOT NULL DEFAULT now()
);

-- 2. Внесение должников с возможностью безопасного повторного запуска (ON CONFLICT):
WITH debt_calc AS (
    SELECT 
        c.customer_id,
        c.credit_limit,
        SUM(i.amount - COALESCE(pay.paid, 0)) AS total_debt
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN invoices i ON o.order_id = i.order_id
    LEFT JOIN (
        SELECT invoice_id, SUM(amount) AS paid
        FROM payments
        GROUP BY invoice_id
    ) pay ON pay.invoice_id = i.invoice_id
    GROUP BY c.customer_id, c.credit_limit
    HAVING SUM(i.amount - COALESCE(pay.paid, 0)) > c.credit_limit
)
INSERT INTO credit_stop_list (customer_id, debt, credit_limit, reason)
SELECT 
    customer_id,
    total_debt,
    credit_limit,
    FORMAT('Превышение кредитного лимита: долг %s руб. при лимите %s руб.', total_debt, credit_limit)
FROM debt_calc
ON CONFLICT (customer_id) DO UPDATE
SET debt = EXCLUDED.debt,
    reason = EXCLUDED.reason,
    added_at = now()
RETURNING *;
-- Проверка: 1 клиент — ООО «Торговый дом Вектор» (долг 6 907 600.45 руб. при лимите 3 000 000 руб.).

-- 3. Добавление признака блокировки в orders и остановка отгрузок:
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT FALSE;

BEGIN;

UPDATE orders o
SET is_blocked = TRUE,
    comment = COALESCE(comment || '; ', '') || 'Заблокирован: стоп-лист (долг ' || sl.debt || ' руб.)'
FROM credit_stop_list sl
WHERE o.customer_id = sl.customer_id
  AND o.status IN ('Новый', 'В работе');
-- Сервер возвращает: UPDATE 1

-- 4. Контроль заблокированных заказов:
SELECT o.order_id, o.order_number, o.customer_id, o.status, o.is_blocked, o.comment
FROM orders o
WHERE o.is_blocked = TRUE;
-- Проверка: заблокирован 1 заказ (№ 4439).

COMMIT;


-- ============================================================================
-- ЗАДАНИЕ А9*. АРХИВ ОТМЕНЁННЫХ ЗАКАЗОВ
-- ============================================================================
-- 1. Создание архивных таблиц структуры orders и order_items:
DROP TABLE IF EXISTS orders_archive_items;
DROP TABLE IF EXISTS orders_archive;

CREATE TABLE orders_archive (LIKE orders INCLUDING ALL);
CREATE TABLE orders_archive_items (LIKE order_items INCLUDING ALL);

-- 2. Подсчет кандидатов на архивацию (2024 год, Отменён, без счетов и возвратов):
WITH target_orders AS (
    SELECT o.order_id
    FROM orders o
    WHERE o.status = 'Отменён'
      AND o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31'
      AND NOT EXISTS (SELECT 1 FROM invoices i WHERE i.order_id = o.order_id)
      AND NOT EXISTS (SELECT 1 FROM returns r WHERE r.order_id = o.order_id)
)
SELECT 
    COUNT(DISTINCT o.order_id) AS orders_to_archive,
    COUNT(oi.order_item_id) AS items_to_archive
FROM target_orders o
JOIN order_items oi ON o.order_id = oi.order_id;
-- Проверка: 83 заказа, 314 позиций.

-- 3. Перенос в архив и удаление одной транзакцией через CTE:
/*
Вопрос: В каком порядке удалять позиции и заказы и почему?
Ответ: Строго сначала позиции (order_items), а затем заказы (orders).
Причина: Ограничение внешнего ключа FOREIGN KEY (order_id) REFERENCES orders(order_id)
в таблице order_items. Если сначала удалить родительский заказ, СУБД заблокирует операцию
с ошибкой нарушения целостности внешнего ключа.
*/

BEGIN;

WITH target_orders AS (
    SELECT o.order_id
    FROM orders o
    WHERE o.status = 'Отменён'
      AND o.order_date >= '2024-01-01' AND o.order_date <= '2024-12-31'
      AND NOT EXISTS (SELECT 1 FROM invoices i WHERE i.order_id = o.order_id)
      AND NOT EXISTS (SELECT 1 FROM returns r WHERE r.order_id = o.order_id)
),
del_items AS (
    DELETE FROM order_items
    WHERE order_id IN (SELECT order_id FROM target_orders)
    RETURNING *
),
ins_items_archive AS (
    INSERT INTO orders_archive_items
    SELECT * FROM del_items
),
del_orders AS (
    DELETE FROM orders
    WHERE order_id IN (SELECT order_id FROM target_orders)
    RETURNING *
)
INSERT INTO orders_archive
SELECT * FROM del_orders;

-- 4. Контрольные проверки:
SELECT 
    (SELECT COUNT(*) FROM orders) AS remaining_orders_in_orders,
    (SELECT COUNT(*) FROM orders_archive) AS archived_orders_count,
    (SELECT COUNT(*) FROM orders_archive_items) AS archived_items_count;
-- Проверка: в orders осталось 4 375 заказов, в архиве 83 заказа и 314 позиций.

COMMIT;
