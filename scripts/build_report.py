# -*- coding: utf-8 -*-
"""
Скрипт генерации подробного Word-отчета по Модулю 0 курса «Углублённый SQL».
Команда А: «Финансы и продажи».
Процесс: «От заказа до денег» (Order-to-Cash).
"""

import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def create_report():
    doc = Document()

    # 1. Настройка полей страницы (2 см со всех сторон)
    for s in doc.sections:
        s.top_margin = Inches(0.79)
        s.bottom_margin = Inches(0.79)
        s.left_margin = Inches(0.79)
        s.right_margin = Inches(0.79)

    # Цветовая палитра
    HEX_PRIMARY = "1B365D"       # Глубокий темно-синий
    HEX_SECONDARY = "2E75B6"     # Насыщенный синий
    HEX_ACCENT_TEAL = "008080"   # Морская волна / акцент
    HEX_ACCENT_RED = "C00000"    # Красный (для точек сбоя и нарушений)
    HEX_BG_ALT = "F9FAFB"        # Чередование строк таблицы
    HEX_BG_CALLOUT = "F0F4F8"    # Фон блоков внимания
    HEX_BORDER = "D3D3D3"        # Границы таблиц

    COLOR_PRIMARY = RGBColor(0x1B, 0x36, 0x5D)
    COLOR_SECONDARY = RGBColor(0x2E, 0x75, 0xB6)
    COLOR_TEXT = RGBColor(0x26, 0x26, 0x26)
    COLOR_MUTED = RGBColor(0x55, 0x55, 0x55)

    # 2. Вспомогательные функции оформления
    def set_cell_background(cell, hex_color):
        tcPr = cell._tc.get_or_add_tcPr()
        for child in list(tcPr):
            if child.tag.endswith('shd'):
                tcPr.remove(child)
        shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
        tcPr.append(shd)

    def set_cell_margins(cell, top=100, bottom=100, left=140, right=140):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
        tcPr.append(tcMar)

    def set_table_borders(table, color="D3D3D3", sz="4", val="single"):
        tblPr = table._tbl.tblPr
        borders = parse_xml(
            f'<w:tblBorders {nsdecls("w")}>'
            f'<w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:insideV w:val="none"/>'
            f'<w:left w:val="none"/>'
            f'<w:right w:val="none"/>'
            f'</w:tblBorders>'
        )
        tblPr.append(borders)

    def add_h1(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Calibri"
        run.font.size = Pt(15)
        run.font.color.rgb = COLOR_PRIMARY
        return p

    def add_h2(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Calibri"
        run.font.size = Pt(12.5)
        run.font.color.rgb = COLOR_SECONDARY
        return p

    def add_h3(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.name = "Calibri"
        run.font.size = Pt(11)
        run.font.color.rgb = COLOR_TEXT
        return p

    def add_p(text, bold_prefix=None, italic=False):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            r_pre = p.add_run(bold_prefix)
            r_pre.bold = True
            r_pre.font.name = "Calibri"
            r_pre.font.size = Pt(10.5)
            r_pre.font.color.rgb = COLOR_TEXT
        run = p.add_run(text)
        run.font.name = "Calibri"
        run.font.size = Pt(10.5)
        run.font.italic = italic
        run.font.color.rgb = COLOR_TEXT
        return p

    def add_code_block(code_text):
        tbl = doc.add_table(rows=1, cols=1)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        cell = tbl.cell(0, 0)
        cell.width = Inches(6.9)
        set_cell_background(cell, "F4F6F9")
        set_cell_margins(cell, top=100, bottom=100, left=160, right=160)
        
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'<w:left w:val="single" w:sz="20" w:space="0" w:color="{HEX_SECONDARY}"/>'
            f'<w:top w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.1
        run = p.add_run(code_text.strip())
        run.font.name = "Consolas"
        run.font.size = Pt(9)
        run.font.color.rgb = RGBColor(0x24, 0x29, 0x2E)

        p_sp = doc.add_paragraph()
        p_sp.paragraph_format.space_before = Pt(0)
        p_sp.paragraph_format.space_after = Pt(4)

    def add_callout(text, title=None, border_color="008080", bg_color="F0F9F8"):
        tbl = doc.add_table(rows=1, cols=1)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        cell = tbl.cell(0, 0)
        cell.width = Inches(6.9)
        set_cell_background(cell, bg_color)
        set_cell_margins(cell, top=120, bottom=120, left=160, right=160)
        
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'<w:left w:val="single" w:sz="24" w:space="0" w:color="{border_color}"/>'
            f'<w:top w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.15
        if title:
            r_t = p.add_run(title + "\n")
            r_t.bold = True
            r_t.font.name = "Calibri"
            r_t.font.size = Pt(10.5)
            r_t.font.color.rgb = COLOR_PRIMARY
        r_c = p.add_run(text)
        r_c.font.name = "Calibri"
        r_c.font.size = Pt(10)
        r_c.font.color.rgb = COLOR_TEXT

        p_sp = doc.add_paragraph()
        p_sp.paragraph_format.space_before = Pt(0)
        p_sp.paragraph_format.space_after = Pt(4)

    def create_table(headers, data, col_widths=None, header_bg="1B365D", alt_bg="F9FAFB"):
        tbl = doc.add_table(rows=len(data) + 1, cols=len(headers))
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        set_table_borders(tbl)

        header_tr = tbl.rows[0]._tr.get_or_add_trPr()
        header_tr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))

        for i, h in enumerate(headers):
            cell = tbl.cell(0, i)
            if col_widths and i < len(col_widths):
                cell.width = Inches(col_widths[i])
            set_cell_background(cell, header_bg)
            set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            r = p.add_run(h)
            r.bold = True
            r.font.name = "Calibri"
            r.font.size = Pt(9.5)
            r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

        for r_idx, row in enumerate(data):
            bg = alt_bg if r_idx % 2 == 1 else "FFFFFF"
            for c_idx, val in enumerate(row):
                cell = tbl.cell(r_idx + 1, c_idx)
                if col_widths and c_idx < len(col_widths):
                    cell.width = Inches(col_widths[c_idx])
                set_cell_background(cell, bg)
                set_cell_margins(cell, top=70, bottom=70, left=110, right=110)
                p = cell.paragraphs[0]
                p.paragraph_format.space_before = Pt(1)
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.15
                r = p.add_run(str(val))
                r.font.name = "Calibri"
                r.font.size = Pt(9)
                r.font.color.rgb = COLOR_TEXT

        p_sp = doc.add_paragraph()
        p_sp.paragraph_format.space_before = Pt(0)
        p_sp.paragraph_format.space_after = Pt(4)
        return tbl

    # =========================================================================
    # ТИТУЛЬНЫЙ БЛОК
    # =========================================================================
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(10)
    p_title.paragraph_format.space_after = Pt(2)
    r_t = p_title.add_run("КУРС «УГЛУБЛЁННЫЙ SQL» (28 АК. Ч.)")
    r_t.font.name = "Calibri"
    r_t.font.size = Pt(12)
    r_t.font.bold = True
    r_t.font.color.rgb = COLOR_SECONDARY

    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(0)
    p_sub.paragraph_format.space_after = Pt(6)
    r_s = p_sub.add_run("Практическая работа по Модулю 0: Архитектура БД и бизнес-процессы")
    r_s.font.name = "Calibri"
    r_s.font.size = Pt(18)
    r_s.font.bold = True
    r_s.font.color.rgb = COLOR_PRIMARY

    add_callout(
        "Команда: Команда А — «Финансы и продажи»\n"
        "Сквозной процесс: «От заказа до денег» (Order-to-Cash)\n"
        "СУБД стенда: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)\n"
        "Схема базы данных: pitanie | База: db1",
        title="Параметры выполнения работы",
        border_color="2E75B6",
        bg_color="F0F4F8"
    )

    # =========================================================================
    # РАЗДЕЛ 1. ВВЕДЕНИЕ И БИЗНЕС-ЛЕГЕНДА
    # =========================================================================
    add_h1("1. Введение и бизнес-контекст компании «Питание +»")
    add_p(
        "Компания «Питание +» — крупный региональный производитель продуктов питания (молочная продукция, кондитерские изделия, "
        "снеки). В рамках цифровой трансформации предприятие переходит к регулярному управлению на основе данных (Data-Driven Management). "
        "В компании сформированы две исследовательские группы аналитиков с целью выявления источников прямых и косвенных финансовых потерь:"
    )
    add_p("• Команда А («Финансы и продажи») — исследует коммерческий блок, работу с клиентами, ценообразование, дебиторскую задолженность и соблюдение финансово-сбытовых регламентов.")
    add_p("• Команда Б («Производство и закупки») — исследует обеспечение сырьём, простои оборудования, рецептурные нормы и потери при списаниях.")
    add_p(
        "Цель настоящего отчета: провести аудит структуры базы данных, выстроить сквозной маршрут движения документов "
        "в процессе «От заказа до денег» (Order-to-Cash), проверить соблюдение ключевых бизнес-правил компании на реальных данных и "
        "сформулировать гипотезы о точках утечки денежных средств."
    )

    # =========================================================================
    # РАЗДЕЛ 2. КЛАССИФИКАЦИЯ ТАБЛИЦ БАЗЫ ДАННЫХ (О.1)
    # =========================================================================
    add_h1("2. Ознакомление со структурой БД и классификация таблиц (Задание О.1)")
    add_p(
        "В учебной схеме pitanie размещены 23 таблицы. Для аналитика критически важно понимать роль каждой таблицы в информационной "
        "системе. Согласно заданию, все таблицы распределены по 4 категориям:"
    )

    add_h2("SQL-запрос классификации таблиц через системный каталог:")
    add_code_block("""-- Автоматическая классификация и подсчет таблиц схемы pitanie
WITH classified_tables AS (
    SELECT 
        table_name,
        CASE 
            WHEN table_name IN (
                'customers', 'employees', 'regions', 'suppliers', 
                'product_categories', 'products', 'raw_materials', 
                'production_lines', 'recipes', 'price_history'
            ) THEN 1
            WHEN table_name IN (
                'orders', 'order_items', 'invoices', 'payments', 
                'purchase_orders', 'purchase_order_items', 
                'production_batches', 'material_consumption'
            ) THEN 2
            WHEN table_name IN (
                'equipment_downtime', 'material_writeoffs', 'returns'
            ) THEN 3
            WHEN table_name IN (
                'sales_plan', 'expenses'
            ) THEN 4
        END AS sort_order,
        CASE 
            WHEN table_name IN (
                'customers', 'employees', 'regions', 'suppliers', 
                'product_categories', 'products', 'raw_materials', 
                'production_lines', 'recipes', 'price_history'
            ) THEN 'Справочники (участники и объекты)'
            WHEN table_name IN (
                'orders', 'order_items', 'invoices', 'payments', 
                'purchase_orders', 'purchase_order_items', 
                'production_batches', 'material_consumption'
            ) THEN 'Документы / операции'
            WHEN table_name IN (
                'equipment_downtime', 'material_writeoffs', 'returns'
            ) THEN 'События и потери'
            WHEN table_name IN (
                'sales_plan', 'expenses'
            ) THEN 'Планы и управленческий учёт'
        END AS vid,
        CASE 
            WHEN table_name IN (
                'customers', 'employees', 'regions', 'suppliers', 
                'product_categories', 'products', 'raw_materials', 
                'production_lines', 'recipes', 'price_history'
            ) THEN 'меняются редко, на них ссылаются другие'
            WHEN table_name IN (
                'orders', 'order_items', 'invoices', 'payments', 
                'purchase_orders', 'purchase_order_items', 
                'production_batches', 'material_consumption'
            ) THEN 'появляются каждый день, у записи есть дата и номер'
            WHEN table_name IN (
                'equipment_downtime', 'material_writeoffs', 'returns'
            ) THEN 'фиксируют отклонения от нормального хода процесса'
            WHEN table_name IN (
                'sales_plan', 'expenses'
            ) THEN 'не привязаны к конкретной операции'
        END AS priznak
    FROM information_schema.tables
    WHERE table_schema = 'pitanie'
)
SELECT 
    vid AS "Вид",
    priznak AS "Признак",
    string_agg(table_name, ', ' ORDER BY table_name) AS "Таблицы",
    count(*) AS "Кол-во таблиц"
FROM classified_tables
GROUP BY sort_order, vid, priznak
ORDER BY sort_order;""")

    headers_o1 = ["Вид", "Признак категории", "Перечень таблиц схемы pitanie", "Кол-во"]
    data_o1 = [
        [
            "Справочники (участники и объекты)",
            "Меняются редко, на них ссылаются другие таблицы",
            "customers, employees, price_history, product_categories, production_lines, products, raw_materials, recipes, regions, suppliers",
            "10"
        ],
        [
            "Документы / операции",
            "Появляются каждый день, у записи есть дата и номер документа",
            "invoices, material_consumption, order_items, orders, payments, production_batches, purchase_order_items, purchase_orders",
            "8"
        ],
        [
            "События и потери",
            "Фиксируют отклонения от нормального хода бизнес-процесса",
            "equipment_downtime, material_writeoffs, returns",
            "3"
        ],
        [
            "Планы и управленческий учёт",
            "Не привязаны к конкретной единичной хозяйственной операции",
            "expenses, sales_plan",
            "2"
        ]
    ]
    create_table(headers_o1, data_o1, col_widths=[1.6, 1.8, 3.0, 0.5])

    add_h2("Методологические комментарии к классификации:")
    add_p(
        "1. Таблица price_history отнесена к Справочникам, так как представляет собой классический медленно меняющийся версионный "
        "справочник цен (Slowly Changing Dimension Type 2). На неё опирается расчет плановой выручки и проверка отпускных цен.\n"
        "2. Таблицы order_items, purchase_order_items и material_consumption представляют собой неотъемлемые табличные части первичных документов "
        "(заказа покупателя, заказа поставщику и производственной смены соответственно). Без них заголовок документа теряет экономический смысл.\n"
        "3. Таблица expenses классифицирована как Управленческий учет, поскольку операционные расходы (аренда, ИТ, общехозяйственные затраты) "
        "не имеют прямой связи со счетом конкретного клиента или отдельной отгрузкой."
    )

    # =========================================================================
    # РАЗДЕЛ 3. АНАЛИЗ АТРИБУТОВ И NULLABILITY (О.2)
    # =========================================================================
    add_h1("3. Анализ структуры атрибутов и Nullability (Задание О.2)")
    add_p(
        "Ограничение NOT NULL (is_nullable = 'NO') на уровне схемы данных — это жесткое техническое воплощение бизнес-правила. "
        "Если поле не допускает NULL, бизнес-процесс не может существовать без этого атрибута."
    )

    add_h2("Структура таблицы orders (Заказы клиентов):")
    add_code_block("""SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'pitanie'
  AND  table_name   = 'orders'
ORDER  BY ordinal_position;""")

    headers_ord = ["№", "Имя столбца", "Тип данных", "is_nullable", "Бизнес-назначение поля"]
    data_ord = [
        ["1", "order_id", "integer", "NO", "Суррогатный первичный ключ заказа"],
        ["2", "order_number", "varchar", "NO", "Официальный номер документа (например, 'ЗК-2024-00338')"],
        ["3", "customer_id", "integer", "NO", "Внешний ключ: клиент-заказчик (B2B)"],
        ["4", "employee_id", "integer", "NO", "Внешний ключ: менеджер по продажам"],
        ["5", "order_date", "date", "NO", "Дата создания/регистрации заказа в системе"],
        ["6", "required_date", "date", "NO", "Требуемая клиентом дата поставки продукции"],
        ["7", "shipped_date", "date", "YES", "Фактическая дата отгрузки со склада (может быть пустой!)"],
        ["8", "status", "varchar", "NO", "Текущий статус жизненного цикла ('Новый', 'В работе', ...)"],
        ["9", "channel", "varchar", "NO", "Канал продаж ('Прямые продажи', 'Маркетплейс', ...)"],
        ["10", "comment", "varchar", "YES", "Необязательный текстовый комментарий к заказу"]
    ]
    create_table(headers_ord, data_ord, col_widths=[0.4, 1.4, 1.1, 0.9, 3.1])

    add_h2("Аналитический ответ: почему shipped_date может быть пустым, а order_date — нет?")
    add_p(
        "• order_date (is_nullable = NO) — фиксирует момент юридического и фактического зарождения документа. Любая хозяйственная операция "
        "в бухгалтерском и управленческом учете должна быть строго локализована во времени. Заказ не может возникнуть «вне времени».\n"
        "• shipped_date (is_nullable = YES) — фиксирует событие из будущего. В момент, когда менеджер вносит заказ в систему, продукция ещё не собрана, "
        "не упакована и не передана перевозчику. На дату создания заказа фактической даты отгрузки не существует физически.\n"
        "• О каком моменте процесса это говорит: Поле shipped_date является индикатором текущей фазы жизненного цикла заказа. "
        "Пока shipped_date IS NULL — заказ находится либо на стадии согласования, либо в производстве/комплектации на складе (либо отменён). "
        "Заполнение этого поля свидетельствует о переходе ответственности за товар к транспортной службе или клиенту."
    )

    add_h2("Аналогичный анализ для таблицы своей команды: price_history (История цен)")
    add_code_block("""SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'pitanie'
  AND  table_name   = 'price_history'
ORDER  BY ordinal_position;""")

    headers_ph = ["Столбец", "Тип данных", "is_nullable", "Бизнес-роль и логика Nullability"]
    data_ph = [
        ["price_id", "integer", "NO", "Первичный ключ записи прайс-листа"],
        ["product_id", "integer", "NO", "Ссылка на товарную номенклатуру (продукцию)"],
        ["valid_from", "date", "NO", "Обязательная дата вступления цены в законную силу"],
        ["valid_to", "date", "YES", "Дата окончания действия цены (допускает NULL для текущей цены)"],
        ["price", "numeric", "NO", "Утвержденная отпускная цена (руб.)"]
    ]
    create_table(headers_ph, data_ph, col_widths=[1.3, 1.1, 1.1, 3.4])

    add_p(
        "Экономический смысл: valid_from обязательна, так как любой приказ об утверждении цен имеет точную дату старта. "
        "Поле valid_to оставляется пустым (NULL), пока цена является действующей в текущий момент. Закрытие поля valid_to конкретной датой "
        "происходит только в момент утверждения новой цены, что гарантирует непрерывность истории прайс-листа без пробелов."
    )

    # =========================================================================
    # РАЗДЕЛ 4. СВЯЗИ МЕЖДУ ТАБЛИЦАМИ (О.3)
    # =========================================================================
    add_h1("4. Связи между таблицами и целостность данных (Задание О.3)")
    add_p(
        "В базе данных pitanie определено ровно 30 внешних ключей (Foreign Keys). Они гарантируют ссылочную целостность — дочерняя запись "
        "не может ссылаться на несуществующего родителя."
    )

    add_code_block("""SELECT conrelid::regclass         AS child_table,
       confrelid::regclass        AS parent_table,
       pg_get_constraintdef(oid)  AS definition
FROM   pg_constraint
WHERE  contype = 'f'
  AND  connamespace = 'pitanie'::regnamespace
ORDER  BY 1, 2;""")

    add_h2("5 связей таблиц команды «Финансы и продажи» (формат «1 родитель — N потомков»):")
    add_p("1. Один customers — много orders:")
    add_p("Один контрагент (клиент) за время работы с компанией оформляет множество заказов, но каждый конкретный заказ принадлежит строго одному клиенту (orders.customer_id → customers.customer_id).", italic=True)
    
    add_p("2. Один orders — много order_items:")
    add_p("Один заказ покупателя может включать в себя множество товарных позиций (строк спецификации), но каждая товарная строка относится строго к одному родительскому заказу (order_items.order_id → orders.order_id).", italic=True)

    add_p("3. Один orders — много invoices:")
    add_p("По одному оформленному заказу может быть выставлено несколько счетов (например, при частичных отгрузках со склада), но каждый выставленный счет привязан к конкретному заказу (invoices.order_id → orders.order_id).", italic=True)

    add_p("4. Один invoices — много payments:")
    add_p("Один счет на оплату может оплачиваться клиентом в несколько траншей (например, аванс 50% и постоплата 50%), но каждая платежная транзакция гасит конкретный выставленный счет (payments.invoice_id → invoices.invoice_id).", italic=True)

    add_p("5. Один products — много price_history:")
    add_p("Каждый готовый товар имеет в базе историю пересмотра цен во времени, но каждая историческая запись цены соответствует строго одной номенклатурной позиции (price_history.product_id → products.product_id).", italic=True)

    add_h2("Две таблицы, ссылающиеся сами на себя (рекурсивные связи):")
    add_p(
        "1. Таблица employees (FOREIGN KEY manager_id REFERENCES employees(employee_id)):\n"
        "Описывает иерархическую организационную структуру компании («руководитель — подчиненный»). Начальник является таким же сотрудником компании, "
        "поэтому его ID указан в строке подчиненного. У Генерального директора поле manager_id равно NULL.\n"
        "2. Таблица product_categories (FOREIGN KEY parent_category_id REFERENCES product_categories(category_id)):\n"
        "Описывает двухуровневое дерево категорий готовой продукции. Дочерняя товарная подкатегория (например, «Творожные сырки») ссылается на "
        "категорию верхнего уровня («Молочная продукция»). У корневых категорий parent_category_id IS NULL."
    )

    # =========================================================================
    # РАЗДЕЛ 5. ОРГСТРУКТУРА И ВЛАДЕЛЬЦЫ ПРОЦЕССОВ (О.4)
    # =========================================================================
    add_h1("5. Оргструктура и владельцы процессов (Задание О.4)")
    add_p(
        "В компании «Питание +» числится 35 сотрудников в 5 подразделениях: Дирекция, Продажи, Финансы, Производство, Закупки. "
        "Для команды А ключевыми являются блоки «Продажи» (11 чел.) и «Финансы» (4 чел.)."
    )

    add_code_block("""SELECT e.department,
       e.full_name,
       e.position,
       m.full_name AS manager_name
FROM   employees      AS e
LEFT   JOIN employees AS m ON m.employee_id = e.manager_id
ORDER  BY e.department, e.position;""")

    add_h2("Иерархическое дерево подчинения блока «Продажи и Финансы»:")
    add_p(
        "Орлов Виктор Петрович (Генеральный директор)\n"
        "│\n"
        "├── [ПРОДАЖИ]\n"
        "│   └── Громов Алексей Иванович (Коммерческий директор)\n"
        "│       └── Ершова Татьяна Юрьевна (Руководитель отдела продаж)\n"
        "│           ├── Соколов Игорь Андреевич (Менеджер по продажам)\n"
        "│           ├── Морозова Елена Павловна (Менеджер по продажам)\n"
        "│           ├── Волков Денис Сергеевич (Менеджер по продажам)\n"
        "│           ├── Новикова Ольга Игоревна (Менеджер по продажам)\n"
        "│           ├── Федоров Павел Олегович (Менеджер по продажам)\n"
        "│           ├── Зайцева Анна Викторовна (Менеджер по продажам)\n"
        "│           ├── Павлов Сергей Дмитриевич (Менеджер по продажам)\n"
        "│           ├── Семенова Ирина Алексеевна (Менеджер по продажам)\n"
        "│           └── Попов Станислав Игоревич (Менеджер по продажам)\n"
        "│\n"
        "└── [ФИНАНСЫ]\n"
        "    └── Белова Марина Сергеевна (Финансовый директор)\n"
        "        ├── Егоров Максим Ильич (Финансовый аналитик)\n"
        "        └── Котова Наталья Михайловна (Главный бухгалтер)\n"
        "            └── Тихонова Вера Андреевна (Специалист по дебиторской задолженности)"
    )

    add_h2("Определение «Владельцев процессов» (Process Owners):")
    add_p(
        "1. Стратегический владелец процесса Продаж: Громов Алексей Иванович (Коммерческий директор). Отвечает за общую выручку, "
        "выполнение плана продаж, политику работы с каналами сбыта и предельные рамки коммерческих условий.\n"
        "2. Стратегический владелец Финансового контура: Белова Марина Сергеевна (Финансовый директор). Отвечает за ликвидность, "
        "кредитную политику, правила предоставления отсрочек, контроль рисков неоплаты и кассовых разрывов.\n"
        "3. Операционный владелец процесса сбыта: Ершова Татьяна Юрьевна (Руководитель отдела продаж). Непосредственно контролирует "
        "ежедневную работу 9 менеджеров, соблюдение регламента скидок и сроки обработки поступающих заявок."
    )

    # =========================================================================
    # РАЗДЕЛ 6. КЛИЕНТЫ И УСЛОВИЯ (А.1)
    # =========================================================================
    add_h1("6. Сегментация клиентов и коммерческие условия (Задание А.1)")
    add_p(
        "В B2B-модели клиенты существенно различаются по объемам закупок и переговорной силе. Это напрямую отражается в кредитной политике."
    )

    add_code_block("""SELECT DISTINCT customer_type, credit_limit, payment_terms_days
FROM   customers
ORDER  BY credit_limit DESC;""")

    headers_cl = ["Тип клиента (сегмент)", "Кредитный лимит (credit_limit)", "Отсрочка платежа (дней)", "Особенности сегмента"]
    data_cl = [
        ["Федеральная сеть", "15 000 000 ₽", "45", "Крупнейшие ритейлеры (X5, Магнит). Диктуют максимальную отсрочку и лимит."],
        ["Маркетплейс", "6 000 000 ₽", "30", "Интернет-площадки (Ozon, WB). Высокий оборот, строгие регламенты отгрузки."],
        ["Региональная сеть", "5 000 000 ₽", "30", "Локальные торговые сети. Стандартные контрактные условия 30 дней."],
        ["Дистрибьютор (тип 1)", "4 000 000 ₽", "30", "Крупные оптовики с проверенной историей сотрудничества."],
        ["Дистрибьютор (тип 2)", "3 000 000 ₽", "30", "Новые дистрибьюторы (например, ООО 'ТД Вектор'). Сниженный лимит."],
        ["HoReCa", "500 000 ₽", "14", "Кафе, рестораны, отели. Небольшие регулярные заказы, короткая отсрочка 2 недели."],
        ["Розница", "300 000 ₽", "7", "Одиночные магазины. Минимальный лимит, жесткая отсрочка платежа 1 неделя."]
    ]
    create_table(headers_cl, data_cl, col_widths=[1.5, 1.6, 1.1, 2.7])

    add_p(
        "Ответы на вопросы:\n"
        "• credit_limit — максимальный совокупный размер неоплаченного долга по отгруженным заказам. Защищает от невозврата средств.\n"
        "• payment_terms_days — установленный договором срок в днях, на который компания беспроцентно кредитует покупателя с момента отгрузки.\n"
        "• manager_id — связывает контрагента с конкретным продавцом для учета персональных продаж, ведения переговоров и персонального контроля дебиторки.\n"
        "• Почему «Дистрибьютор» встречается дважды: у дистрибьюторов в базе зафиксировано два разных кредитных лимита (3 млн и 4 млн руб.). "
        "В первом запросе клиентом с лимитом 3 млн руб. является ООО 'Торговый дом Вектор' (клиент № 1), тогда как клиенты № 2, 3 и 4 имеют лимит 4 млн руб."
    )

    # =========================================================================
    # РАЗДЕЛ 7. СКВОЗНОЙ МАРШРУТ ДОКУМЕНТА (А.2)
    # =========================================================================
    add_h1("7. Сквозной маршрут документа: детальный разбор кейсов (Задание А.2)")
    add_p(
        "Для понимания того, как транзакционные таблицы отражают физический бизнес-процесс, был полностью прослежен жизненный цикл заказа ЗК-2024-00338."
    )

    add_h2("Таблица «Маршрут документа» для заказа ЗК-2024-00338:")
    headers_route = ["Шаг", "Что произошло в бизнесе", "Таблица БД", "Дата", "Сумма / объём", "Ответственное лицо"]
    data_route = [
        ["1", "Клиент сделал заказ", "orders", "02.03.2024", "3 номенклатурные позиции", "Менеджер: Семенова И. А."],
        ["2", "Заказ отгружен со склада", "orders", "08.03.2024", "933 единицы товара", "Склад / Логистика"],
        ["3", "Выставлен счёт на оплату", "invoices", "08.03.2024", "52 958.58 ₽", "Бухгалтерия (Котова Н. М.)"],
        ["4", "Наступил срок оплаты (due_date)", "invoices", "07.04.2024", "52 958.58 ₽ (дедлайн)", "Клиент: ООО «Гамма»"],
        ["5", "Оплата 1-й части счёта (50%)", "payments", "04.04.2024", "26 479.29 ₽", "Клиент (в срок за 3 дня)"],
        ["6", "Оплата 2-й части счёта (50%)", "payments", "07.05.2024", "26 479.29 ₽", "Клиент (ПРОСРОЧКА НА 30 ДНЕЙ!)"],
        ["7", "Возврат партии товара", "returns", "13.03.2024", "57 шт. (Кефир 2,5% 0,9 л)", "Клиент (брак / просрочка)"]
    ]
    create_table(headers_route, data_route, col_widths=[0.4, 2.0, 1.0, 0.9, 1.3, 1.3])

    add_h2("Аналитические выводы по заказу ЗК-2024-00338:")
    add_p(
        "1. Сроки отгрузки: Заказ оформлен 02.03.2024, отгружен 08.03.2024 (прошло 6 дней). Требуемая дата доставки (required_date) была 09.03.2024. "
        "Формально успели за 1 день до крайнего срока, однако задержка комплектации в 6 дней стала фатальной для свежести продукции.\n"
        "2. Механика расчета срока оплаты: invoices.due_date = invoices.invoice_date + customers.payment_terms_days. "
        "Дата выставления счета 08.03.2024 + 30 дней отсрочки региональной сети = 07.04.2024.\n"
        "3. Платежная дисциплина: Счет оплачен полностью (2 транша по 26 479.29 ₽), но вторая половина поступила 07.05.2024 — "
        "ровно через месяц после крайнего срока! Компания бесплатно кредитовала покупателя 30 дней сверх договора.\n"
        "4. Причина возврата и срок годности: 13.03.2024 клиент вернул 57 бутылок кефира с формулировкой «Истёк срок годности». "
        "В таблице products для данного кефира shelf_life_days составляет всего 10 дней! С момента оформления заказа (02.03) до момента "
        "возврата (13.03) прошло 11 дней. Пока заказ 6 дней комплектовался на складе и ехал до полок магазина, его срок годности практически "
        "истек, и магазин вернул нераспроданные остатки нашему предприятию."
    )

    add_h2("Сравнительный анализ с заказом ЗК-2025-04000:")
    add_p(
        "Для контраста исследован заказ ЗК-2025-04000:\n"
        "• Клиент: ООО «Лента-Сервис» (Федеральная сеть, кредитный лимит 15 млн руб., отсрочка 45 дней, менеджер Павлов С. Д.).\n"
        "• Скорость исполнения: заказ оформлен 26.10.2025, отгружен уже 27.10.2025 (всего 1 день вместо 6!).\n"
        "• Оплата: сумма счета 251 095.60 ₽ закрыта единым платежом 17.12.2025 (просрочка составила всего 6 дней против дедлайна 11.12.2025).\n"
        "• Возвраты: 0 возвратов. Заказ состоял из конфет «Птичье молоко» (сухая бакалея длительного хранения), что исключило риск порчи."
    )

    # =========================================================================
    # РАЗДЕЛ 8. ЖИЗНЕННЫЙ ЦИКЛ ЗАКАЗА (А.3)
    # =========================================================================
    add_h1("8. Жизненный цикл заказа и матрица состояний (Задание А.3)")
    add_p(
        "Анализ распределения всех 4 458 заказов в базе позволил реконструировать граф состояний документа:"
    )

    add_code_block("""SELECT status,
       COUNT(*)            AS orders_cnt,
       COUNT(shipped_date) AS with_shipped_date
FROM   orders
GROUP  BY status
ORDER  BY orders_cnt DESC;""")

    headers_st = ["Статус заказа", "Количество заказов", "Заказов с заполненной shipped_date", "% заполнения даты отгрузки"]
    data_st = [
        ["Доставлен", "4 212", "4 212", "100.0%"],
        ["Отменён", "177", "0", "0.0%"],
        ["Отгружен", "30", "30", "100.0%"],
        ["Новый", "22", "0", "0.0%"],
        ["В работе", "17", "0", "0.0%"],
        ["ИТОГО", "4 458", "4 242", "95.2%"]
    ]
    create_table(headers_st, data_st, col_widths=[1.5, 1.6, 2.1, 1.7])

    add_h2("Диаграмма переходов состояний (State Diagram):")
    add_p(
        "[Старт] ──> Новый (22 шт.) ──> В работе (17 шт.) ──> Отгружен (30 шт.) ──> Доставлен (4 212 шт.) ──> [Успех]\n"
        "                 │                     │\n"
        "                 └───> Отменён <───────┘ (177 шт., досрочное завершение сделки)"
    )
    add_p(
        "Экономическое объяснение:\n"
        "У статусов «Новый», «В работе» и «Отменён» дата отгрузки всегда равна NULL. Для первых двух статусов товар еще находится внутри "
        "периметра предприятия. Для статуса «Отменён» отгрузка была заблокирована (отказ клиента, отсутствие сырья на производстве, превышение кредитного лимита), "
        "поэтому операция перемещения товара со склада так и не состоялась."
    )

    # =========================================================================
    # РАЗДЕЛ 9. УПРАВЛЕНЧЕСКИЙ КОНТУР (А.4)
    # =========================================================================
    add_h1("9. Управленческий контур: планы, прайс-лист, структура затрат (Задание А.4)")
    
    add_h2("1. Детализация планирования продаж (sales_plan):")
    add_p(
        "План продаж формируется с агрегацией: Год (plan_year) + Месяц (plan_month) + Категория верхнего уровня (category_id). "
        "В плане нет детализации по конкретным магазинам или номенклатурным позициям (SKU).\n"
        "Как сопоставить «План — Факт»: Фактические продажи рассчитываются суммированием order_items.line_amount по отгруженным заказам, "
        "группируются по месяцу даты заказа orders.order_date и связываются через products.category_id с родительской категорией sales_plan.category_id."
    )

    add_h2("2. Назначение price_history и открытые интервалы:")
    add_p(
        "Таблица price_history хранит хронологию официального прайс-листа предприятия. Отсутствие даты окончания действия (valid_to IS NULL) "
        "обозначает открытый временной интервал — данная цена имеет статус официально действующей в настоящий момент."
    )

    add_h2("3. Структура операционных расходов (expenses):")
    add_p(
        "В базе зафиксированы статьи: Логистика, Комиссия маркетплейса, Маркетинг, Аренда, Энергоресурсы, ИТ, Ремонт оборудования, Командировки.\n"
        "Почему у части расходов указан sales_channel, а у части — нет:\n"
        "• Прямые коммерческие затраты (Логистика, Комиссия маркетплейса) жестко привязаны к каналу продаж ('Прямые продажи', 'Маркетплейс', 'Дистрибуция'). "
        "Они формируют маржинальность конкретного сбытового направления.\n"
        "• Косвенные общехозяйственные затраты (Аренда складов и офиса, ИТ-лицензии, ремонт линий, отопление цехов) относятся к инфраструктуре "
        "всего предприятия в целом и разносятся на каналы продаж только расчетным путем в управленческой отчетности."
    )

    # =========================================================================
    # РАЗДЕЛ 10. АУДИТ БИЗНЕС-ПРАВИЛ (А.5)
    # =========================================================================
    add_h1("10. Аудит соблюдения бизнес-правил компании (Задание А.5)")
    add_p(
        "Бизнес-правила определяют границы операционной эффективности. В ходе анализа мы проверили 5 ключевых регламентов компании на реальной выборке данных."
    )

    headers_rules = ["№", "Бизнес-правило компании", "Где в данных проверяется", "Фактический результат проверки", "Статус"]
    data_rules = [
        [
            "1",
            "Предельная скидка не более 10%",
            "order_items.discount_pct <= 10",
            "Из 17 576 позиций в 4 365 строках скидка > 10% (доходит до 15-20%)! Нарушение в 24.8% всех сделок.",
            "ГРУБОЕ НАhandlerЕНИЕ"
        ],
        [
            "2",
            "На один заказ выставляется строго один счёт",
            "invoices.order_id (уникальность)",
            "На 4 242 отгруженных заказа выставлено ровно 4 242 счета. Дубликаты счетов отсутствуют (0 шт.).",
            "СОБЛЮДАЕТСЯ (100%)"
        ],
        [
            "3",
            "Срок оплаты = Дата счёта + Отсрочка",
            "invoices.due_date = invoice_date + payment_terms_days",
            "Все 4 242 счета рассчитаны день в день согласно контрактным условиям контрагентов.",
            "СОБЛЮДАЕТСЯ (100%)"
        ],
        [
            "4",
            "Счета оплачиваются контрагентами в срок",
            "payments.payment_date <= invoices.due_date",
            "Из 4 519 платежей 2 391 платеж поступил с опозданием (52.9% оплат просрочено на срок от 5 до 45 дней)!",
            "МАССОВОЕ НАhandlerЕНИЕ"
        ],
        [
            "5",
            "Отгрузка производится вовремя к required_date",
            "orders.shipped_date <= orders.required_date",
            "Из 4 242 отгрузок 984 заказа (23.2%) отгружены с задержкой относительно срока, согласованного с клиентом.",
            "СИСТЕМНЫЙ СБОЙ"
        ]
    ]
    create_table(headers_rules, data_rules, col_widths=[0.3, 1.8, 1.6, 2.2, 1.0])

    add_callout(
        "Вывод аудита: Жесткие автоматизированные правила биллинга (выставление счетов, начисление отсрочки) работают идеально. "
        "Однако в точках взаимодействия людей и операционных служб (раздача скидок менеджерами, отгрузка складом, платежная дисциплина клиентов) "
        "компания демонстрирует катастрофическую потерю контроля: каждый 4-й заказ отгружается с опозданием, в каждой 4-й строке превышена скидка, "
        "а каждый 2-й платеж поступает с просрочкой!",
        title="Ключевой аналитический вывод аудита регламентов",
        border_color="C00000",
        bg_color="FDF2F2"
    )

    # =========================================================================
    # РАЗДЕЛ 11. СХЕМА ПРОЦЕССА ORDER-TO-CASH (А.6)
    # =========================================================================
    add_h1("11. Схема сквозного процесса «От заказа до денег» (Задание А.6)")
    add_p(
        "Процесс Order-to-Cash объединяет коммерческие службы, логистику и бухгалтерию. Ниже приведена матрица сквозного движения документа "
        "с фиксацией ответственных ролей, модифицируемых таблиц и критических точек отказа:"
    )

    headers_proc = ["Этап процесса", "Ответственная роль", "Таблицы БД", "Заполняемые поля", "Критическая точка сбоя"]
    data_proc = [
        [
            "1. Прием и оформление заявки",
            "Менеджер по продажам",
            "orders, order_items",
            "customer_id, employee_id, order_date, required_date, status='Новый', channel, product_id, quantity, discount_pct",
            "🔴 ТОЧКА СБОЯ 1: Превышение кредитного лимита, несанкционированная скидка > 10% или отмена заказа клиентом."
        ],
        [
            "2. Комплектация и сборка",
            "Рук. отдела продаж, Склад",
            "orders",
            "status = 'В работе'",
            "🔴 Задержка из-за дефицита готовой продукции на складе, риск срыва required_date."
        ],
        [
            "3. Физическая отгрузка",
            "Служба логистики / Склад",
            "orders",
            "shipped_date, status = 'Отгружен' / 'Доставлен'",
            "🔴 ТОЧКА СБОЯ 2: Срыв даты отгрузки (shipped_date > required_date). Риск возврата скоропортящихся молочных продуктов!"
        ],
        [
            "4. Выставление счёта",
            "Бухгалтерия (Котова Н. М.)",
            "invoices",
            "invoice_number, invoice_date, due_date, amount",
            "Сбоев нет: автоматическое выставление в день отгрузки, сумма равна итогу спецификации заказа."
        ],
        [
            "5. Инкассация оплат",
            "Спец. по дебиторке (Тихонова В. А.)",
            "payments",
            "invoice_id, payment_date, amount, payment_method",
            "🔴 ТОЧКА СБОЯ 3: Неоплата, затяжные кассовые разрывы (payment_date > due_date в 52.9% случаев)."
        ],
        [
            "6. Претензионная работа",
            "Менеджер, Служба качества",
            "returns",
            "order_id, product_id, return_date, quantity, reason",
            "🔴 Прямой убыток от утилизации некондиции/просрочки и штрафы ритейлеров за недопоставку."
        ]
    ]
    create_table(headers_proc, data_proc, col_widths=[1.2, 1.2, 1.0, 1.8, 1.7])

    # =========================================================================
    # РАЗДЕЛ 12. ГДЕ ТЕРЯЮТСЯ ДЕНЬГИ И ЗАЩИТА РАБОТЫ (ФИНАЛ)
    # =========================================================================
    add_h1("12. Финальные выводы: Где теряются деньги и Текст выступления")
    add_p(
        "На основе проведенного анализа данных сформированы 3 ключевых аналитических вопроса для детальной проработки в следующих модулях курса:"
    )

    headers_fin = ["№", "Что мы заметили в данных", "Почему это стоит реальных денег предприятию", "Таблицы для проверки"]
    data_fin = [
        [
            "1",
            "Массовая просрочка оплат клиентами (52.9% платежей приходят с задержкой от недели до месяца).",
            "Компания бесплатно кредитует контрагентов своими деньгами. Замораживается оборотный капитал, возникают кассовые разрывы, растет кредиторская нагрузка перед поставщиками сырья.",
            "invoices, payments, customers"
        ],
        [
            "2",
            "Систематическое превышение лимита скидок (24.8% позиций отгружено со скидками выше разрешенных 10%).",
            "Прямой недополученный доход компании. Менеджеры раздают необоснованные скидки ради выполнения личных планов по валу, разрушая чистую маржинальность продукции.",
            "order_items, orders, employees, customers"
        ],
        [
            "3",
            "Срыв сроков отгрузки (23.2% заказов) и возвраты скоропортящейся продукции (кефир со сроком 10 дней).",
            "Прямые безвозвратные убытки от списания и утилизации просрочки, бесполезные транспортные расходы на двойную доставку и многомиллионные штрафы от федеральных сетей.",
            "orders, order_items, products, returns"
        ]
    ]
    create_table(headers_fin, data_fin, col_widths=[0.4, 2.1, 2.6, 1.8])

    add_h2("Текст доклада на защите команды (хронометраж: ровно 2 минуты):")
    add_callout(
        "«Здравствуйте, коллеги и преподаватели! Наша Команда А исследовала сквозной процесс „От заказа до денег“ (Order-to-Cash).\n\n"
        "В теории процесс выглядит гладко: менеджер принимает заказ, склад комплектует и отгружает товар, бухгалтерия формирует счёт, "
        "а клиент его своевременно оплачивает. Но когда мы выгрузили и проанализировали реальные транзакционные данные за два года, "
        "мы выявили три критические бреши, через которые предприятие теряет десятки миллионов рублей прибыли.\n\n"
        "Первая проблема — катастрофическая платёжная дисциплина. Более 52% всех платежей поступают с нарушением установленного срока due_date. "
        "Как мы видели на примере заказа 338, клиенты задерживают выплаты на месяц и более. Предприятие выступает бесплатным банком для ритейла, "
        "замораживая собственные оборотные средства. Вопрос аналитика: кто из клиентов генерирует основной объем токсичной дебиторки и каков масштаб кассового разрыва?\n\n"
        "Вторая проблема — неконтролируемая эрозия цен. Регламент компании жестко ограничивает скидку планкой в 10%. Однако в данных каждая четвертая "
        "строка заказа (24.8%) продана со скидкой выше нормы! Вопрос аналитика: какие конкретно менеджеры по продажам системно сливают маржу "
        "и в каких каналах сбыта это происходит?\n\n"
        "Третья проблема — задержки комплектации и списание скоропорта. Почти 23% заказов отгружаются с опозданием. Для товаров со сроком годности 10 дней, "
        "таких как свежий кефир, задержка отгрузки на 6 дней означает, что на полки магазинов продукт попадает уже фактически испорченным. "
        "Магазины оформляют возвраты, и компания несет прямые убытки от утилизации. Вопрос аналитика: сколько денег мы теряем на возвратах скоропорта "
        "из-за нерасторопности складской логистики?\n\n"
        "Именно эти три гипотезы мы берем в приоритетную разработку в следующих модулях курса. Спасибо за внимание!»",
        title="Сценарий выступления на защите проекта (2 минуты)",
        border_color="1B365D",
        bg_color="F7F9FC"
    )

    # 3. Сохранение файла
    output_dir = r"C:\Users\serpu\Downloads\АкадемияИТ\Postgres"
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "Отчет_Модуль_0_Финансы_и_Продажи.docx")
    doc.save(output_path)
    print(f"Отчет успешно сформирован и сохранен по пути: {output_path}")

if __name__ == "__main__":
    create_report()
