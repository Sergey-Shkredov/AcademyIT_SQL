# -*- coding: utf-8 -*-
"""
Генератор отчета по Модулю 1 курса «Углублённый SQL».
Команда А: «Финансы и продажи».
Тема: «Первые улики: фильтрация и сортировка».
"""

import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

def create_m1_report():
    doc = Document()

    # Поля страницы 2 см
    for s in doc.sections:
        s.top_margin = Inches(0.79)
        s.bottom_margin = Inches(0.79)
        s.left_margin = Inches(0.79)
        s.right_margin = Inches(0.79)

    # Цветовая гамма
    HEX_PRIMARY = "1B365D"       # Темно-синий
    HEX_SECONDARY = "2E75B6"     # Насыщенный синий
    HEX_ACCENT_TEAL = "008080"   # Морская волна
    HEX_ACCENT_RED = "C00000"    # Красный (акцент на убытках/сбоях)
    HEX_BG_ALT = "F9FAFB"        # Чередование строк таблицы
    HEX_BORDER = "D3D3D3"        # Границы

    COLOR_PRIMARY = RGBColor(0x1B, 0x36, 0x5D)
    COLOR_SECONDARY = RGBColor(0x2E, 0x75, 0xB6)
    COLOR_TEXT = RGBColor(0x26, 0x26, 0x26)

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
        run.font.size = Pt(14.5)
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
        run.font.size = Pt(12)
        run.font.color.rgb = COLOR_SECONDARY
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
            set_cell_margins(cell, top=90, bottom=90, left=110, right=110)
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
                set_cell_margins(cell, top=70, bottom=70, left=100, right=100)
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
    # ТИТУЛ
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
    r_s = p_sub.add_run("Модуль 1. Лабораторная работа: «Первые улики: фильтрация и сортировка»")
    r_s.font.name = "Calibri"
    r_s.font.size = Pt(17)
    r_s.font.bold = True
    r_s.font.color.rgb = COLOR_PRIMARY

    add_callout(
        "Команда: Команда А — «Финансы и продажи»\n"
        "Сквозной сюжет: Аудит коммерческого контура предприятия «Питание +»\n"
        "СУБД: PostgreSQL 16 (Yandex Managed Service for PostgreSQL)\n"
        "Схема базы данных: pitanie | Скрипт: lab01_team_a.sql",
        title="Паспорт лабораторной работы",
        border_color="2E75B6",
        bg_color="F0F4F8"
    )

    # =========================================================================
    # ВВЕДЕНИЕ
    # =========================================================================
    add_h1("1. Цели работы и инструментальные ограничения")
    add_p(
        "Руководство компании «Питание +» дало аналитикам коммерческого блока неделю на выявление первых улик — строк транзакционных данных, "
        "свидетельствующих о прямых или скрытых финансовых потерях компании. Согласно условиям Модуля 1, исследование проводится без соединений таблиц (JOIN) "
        "и без группировок (GROUP BY) — исключительно с использованием предикатов WHERE (IN, BETWEEN, LIKE/ILIKE, IS NULL, IS DISTINCT FROM), "
        "сортировок ORDER BY и ограничений LIMIT / FETCH FIRST ... WITH TIES."
    )
    add_p(
        "Несмотря на ограничения, базовой фильтрации и арифметики оказалось достаточно, чтобы обнаружить масштабные бреши в сбытовой политике: "
        "несанкционированные скидки на десятки миллионов рублей, персональную связь продавца с клиентом, продажу ключевой номенклатуры ниже себестоимости, "
        "а также задержки отгрузок и дублирование клиентов в CRM/ERP."
    )

    # =========================================================================
    # ОБЩАЯ ЧАСТЬ (О1 – О3)
    # =========================================================================
    add_h1("2. Общая часть (Задания О1 – О3)")

    add_h2("Задание О1. Общий объём заказов и отмены")
    add_p("Определить общее количество заказов в системе и количество отмененных заказов (status = 'Отменён').")
    add_code_block("""SELECT COUNT(*)                                   AS total_orders,
       COUNT(*) FILTER (WHERE status = 'Отменён') AS cancelled_orders
FROM   orders;""")
    add_p("Результат проверки: Всего заказов — 4 458, отменено — 177 заказов (3.97 % от общего пула).")

    add_h2("Задание О2. Скоропортящаяся продукция (срок годности <= 14 дней)")
    add_p("Вывести продукцию со сроком годности не более двух недель, отсортированную от наиболее скоропортящейся к менее, а при равенстве — по наименованию.")
    add_code_block("""SELECT product_id, product_name, shelf_life_days, base_price
FROM   products
WHERE  shelf_life_days <= 14
ORDER  BY shelf_life_days ASC, product_name ASC;""")
    
    headers_o2 = ["ID", "Наименование продукта", "Срок годности (дней)", "Базовая цена (руб.)"]
    data_o2 = [
        ["8", "Йогурт клубничный 2,5% 0,3 кг", "7", "65.00"],
        ["9", "Йогурт персиковый 2,5% 0,3 кг", "7", "65.00"],
        ["6", "Кефир 2,5% 0,9 л", "10", "86.48"],
        ["1", "Молоко пастеризованное 2,5% 1 л", "10", "79.00"],
        ["2", "Молоко пастеризованное 3,2% 1 л", "10", "85.00"],
        ["7", "Ряженка 4% 0,5 л", "10", "68.00"],
        ["10", "Творог 9% 0,2 кг", "12", "98.00"],
        ["33", "Биойогурт питьевой черника 0,27 л", "14", "72.00"],
        ["4", "Сливки 20% 0,5 л", "14", "165.00"],
        ["5", "Сливки 33% 0,5 л", "14", "245.00"],
        ["11", "Сметана 20% 0,3 кг", "14", "92.00"]
    ]
    create_table(headers_o2, data_o2, col_widths=[0.6, 3.4, 1.5, 1.4])
    add_p("Результат проверки: 11 позиций. Первые две строки — йогурты (7 дней). Данные продукты находятся в критической зоне логистического риска.")

    add_h2("Задание О3. Неполные контактные данные персонала")
    add_p("Вывести сотрудников, у которых отсутствует email или номер телефона (подсказка: = NULL не работает, используется IS NULL).")
    add_code_block("""SELECT employee_id, department, full_name, position, email, phone
FROM   employees
WHERE  email IS NULL OR phone IS NULL
ORDER  BY department ASC, full_name ASC;""")
    add_p(
        "Результат проверки: 13 сотрудников (11 операторов производства вообще не имеют корпоративного email и телефона, "
        "у менеджера Попова С. И. нет телефона, у менеджера Зайцевой А. В. нет email, а у специалиста по дебиторке Тихоновой В. А. не внесен телефон). "
        "Это создает риски потери оперативной связи при разрешении экстренных инцидентов."
    )

    # =========================================================================
    # ВАРИАНТ 1: ЗАДАНИЯ А1 – А3 (СКИДКИ И МЕНЕДЖЕРЫ)
    # =========================================================================
    add_h1("3. Анализ скидок и деанонимизация нарушителей (Задания А1 – А3)")

    add_h2("Задание А1. Скидки сверх регламента (политика: скидка не более 10 %)")
    add_p("Посчитать количество строк заказов со скидкой более 10 %, и отдельно — со скидкой 20 % и выше.")
    add_code_block("""-- Позиции со скидкой выше 10 %:
SELECT COUNT(*) AS count_discount_over_10
FROM   order_items
WHERE  discount_pct > 10;
-- Проверка: 4 365 позиций (24.8 % всех строк в базе!)

-- Экстремальные скидки (20 % и выше):
SELECT COUNT(*) AS count_discount_gte_20
FROM   order_items
WHERE  discount_pct >= 20;
-- Проверка: 1 741 позиция.""")

    add_h2("Задание А2. Финансовая оценка ущерба от сверхнормативных скидок")
    add_p(
        "Рассчитать избыточную сумму скидки сверх разрешенных 10 % в рублях: "
        "quantity * unit_price * (discount_pct - 10) / 100. Вывести Топ-20 позиций (FETCH FIRST 20 ROWS WITH TIES)."
    )
    add_code_block("""SELECT order_item_id,
       order_id,
       product_id,
       quantity,
       unit_price,
       discount_pct,
       ROUND(quantity * unit_price * (discount_pct - 10) / 100, 2) AS over_discount_rub
FROM   order_items
WHERE  discount_pct > 10
ORDER  BY over_discount_rub DESC, 
          order_item_id ASC
FETCH  FIRST 20 ROWS WITH TIES;""")

    headers_a2 = ["order_item_id", "order_id", "product_id", "Кол-во", "Цена (руб)", "Скидка %", "Ущерб сверх 10% (руб)"]
    data_a2 = [
        ["9654", "2467", "25", "1440", "245.00", "25.00", "52 920.00 ₽"],
        ["17282", "4385", "25", "1400", "245.00", "25.00", "51 450.00 ₽"],
        ["13417", "3425", "25", "1183", "245.00", "25.00", "43 475.25 ₽"],
        ["13418", "3425", "26", "962", "299.00", "25.00", "43 145.70 ₽"],
        ["13082", "3339", "26", "900", "299.00", "25.00", "40 365.00 ₽"],
        ["6151", "1561", "25", "1084", "230.30", "25.00", "37 446.78 ₽"],
        ["8509", "2165", "26", "1494", "299.00", "18.00", "35 736.48 ₽"],
        ["5243", "1326", "25", "1010", "230.30", "25.00", "34 890.45 ₽"],
        ["9197", "2349", "5", "1375", "245.00", "20.00", "33 687.50 ₽"],
        ["8654", "2201", "13", "1104", "189.00", "25.00", "31 298.40 ₽"],
        ["6254", "1586", "26", "713", "281.06", "25.00", "30 059.37 ₽"],
        ["13780", "3514", "5", "1192", "245.00", "20.00", "29 204.00 ₽"],
        ["12345", "3138", "26", "969", "299.00", "20.00", "28 973.10 ₽"],
        ["6564", "1664", "14", "1287", "149.46", "25.00", "28 853.25 ₽"],
        ["8510", "2165", "13", "990", "189.00", "25.00", "28 066.50 ₽"],
        ["17320", "4398", "13", "1478", "189.00", "20.00", "27 934.20 ₽"],
        ["421", "106", "13", "1045", "177.66", "25.00", "27 848.21 ₽"],
        ["10711", "2742", "13", "977", "189.00", "25.00", "27 697.95 ₽"],
        ["15449", "3931", "26", "612", "299.00", "25.00", "27 448.20 ₽"],
        ["1782", "432", "26", "956", "281.06", "20.00", "26 869.34 ₽"]
    ]
    create_table(headers_a2, data_a2, col_widths=[1.1, 0.9, 0.9, 0.9, 1.0, 0.9, 1.2])
    add_p("Результат проверки: Первая строка — позиция 9654 в заказе 2467 с избыточным списанием 52 920.00 руб. (скидка 25 % вместо 10 %).")

    add_h2("Задание А3. Расследование: кто согласовывал завышенные скидки?")
    add_p("Выписать order_id из первых 10 строк задания А2 и найти заказы и ответственного менеджера:")
    add_code_block("""-- Шаг 1. Проверяем заказы из Топ-10 по перерасходу:
SELECT order_id, order_number, customer_id, employee_id, order_date, channel
FROM   orders
WHERE  order_id IN (2467, 4385, 3425, 3339, 1561, 2165, 1326, 2349, 2201)
ORDER  BY order_id;

-- Шаг 2. Идентификация сотрудника:
SELECT employee_id, department, full_name, position, manager_id
FROM   employees
WHERE  employee_id = 10;""")

    add_callout(
        "Сенсационный аналитический результат:\n"
        "• Все до единого заказы из Топ-10 с максимальным перерасходом оформлены ОДНИМ менеджером: Соколов Игорь Андреевич (employee_id = 10)!\n"
        "• Более того, 7 из этих 9 заказов отгружены одному и тому же контрагенту: customer_id = 7 (ООО «Свежесть-Трейд»).\n"
        "Вывод: Это не случайность, а системное нарушение регламента, указывающее либо на личную заинтересованность продавца (сговор с покупателем), "
        "либо на предоставление эксклюзивных несанкционированных преференций.\n"
        "Что дадут модули 3–4: Соединения (JOIN) и агрегация (GROUP BY) позволят рассчитать полную сумму убытков, нанесенных компанией конкретно менеджером Соколовым, "
        "и сопоставить его среднюю скидку со средней скидкой по отделу продаж.",
        title="Аналитическое заключение по заданию А3",
        border_color="C00000",
        bg_color="FDF2F2"
    )

    # =========================================================================
    # ЗАДАНИЕ А4 (ЗАКАЗЫ БЕЗ ОТГРУЗКИ И ЛОГИСТИКА)
    # =========================================================================
    add_h1("4. Анализ неотгруженных заказов и срыва сроков (Задание А4)")

    add_code_block("""-- 1. Неотгруженные действующие заказы (39 строк):
SELECT order_id, order_number, customer_id, employee_id, required_date, status
FROM   orders
WHERE  shipped_date IS NULL AND status != 'Отменён'
ORDER  BY required_date ASC;

-- 2. Зависшие просроченные заказы на конец 2025 года (2 строки):
SELECT order_id, order_number, customer_id, employee_id, order_date, required_date, status
FROM   orders
WHERE  shipped_date IS NULL 
  AND  status IN ('Новый', 'В работе') 
  AND  required_date < DATE '2025-12-31'
ORDER  BY required_date ASC;

-- 3. Контроль качества данных (0 строк):
SELECT COUNT(*) FROM orders WHERE status IN ('Отгружен', 'Доставлен') AND shipped_date IS NULL;

-- 4. Заказы, отгруженные позже требуемой даты (984 строки):
SELECT COUNT(*) FROM orders WHERE shipped_date > required_date;""")

    add_p(
        "Аналитические выводы:\n"
        "1. В системе числится 39 неотгруженных заказов. Из них 2 заказа (ЗК-2025-04420 и ЗК-2025-04421 от 27.12.2025) должны были быть "
        "доставлены клиентам к 29.12.2025, но на срез 31.12.2025 так и не отгружены (статусы 'Новый' и 'В работе').\n"
        "2. Контроль качества подтвердил 100 % надежность данных: ни один заказ со статусом 'Отгружен' или 'Доставлен' не имеет пустого shipped_date.\n"
        "3. Отгружено с опозданием 984 заказа (23.2 % всех отгрузок!). Это объясняет регулярные возвраты скоропортящейся молочной продукции.\n"
        "4. Почему в п. 4 не нужно исключать shipped_date IS NULL: в стандарте SQL действует трехзначная логика (3VL). "
        "Сравнение NULL > required_date возвращает результат UNKNOWN. Предикат WHERE отбирает только строки со значением TRUE, "
        "поэтому все строки с NULL отсекаются движком базы данных автоматически."
    )

    # =========================================================================
    # ЗАДАНИЯ А5 – А6 (ГРЯЗНЫЕ ДАННЫЕ И ДУБЛИКАТЫ)
    # =========================================================================
    add_h1("5. Аудит качества мастер-данных контрагентов (Задания А5 – А6)")

    add_h2("Задание А5. Дефекты контактных данных клиентов")
    add_code_block("""-- 1. Проверка чистоты email адресов (53 строки с ошибками):
SELECT customer_id, customer_name, '[' || COALESCE(email, 'NULL') || ']' AS email_check
FROM   customers
WHERE  email IS NULL 
   OR  email LIKE ' %' 
   OR  email LIKE '% ' 
   OR  email != LOWER(email)
ORDER  BY customer_id;

-- 2. Клиенты без привязки к региону (3 строки: ID 19, 54, 67):
SELECT customer_id, customer_name, region_id
FROM   customers
WHERE  region_id IS NULL;""")
    add_p(
        "Последствия дефектов:\n"
        "• 53 клиента имеют невалидные адреса: пропущенные email приведут к неполучению счетов, а ведущие/замыкающие пробелы вызовут сбой почтовых шлюзов (SMTP).\n"
        "• 3 клиента не имеют региона (region_id IS NULL). При формировании управленческой отчетности по регионам с использованием INNER JOIN "
        "продажи этим контрагентам полностью выпадут из расчета, исказив данные о доходности географических рынков."
    )

    add_h2("Задание А6. Клиенты-дубликаты (клоны карточек)")
    add_code_block("""SELECT customer_id, customer_name, inn, phone, credit_limit
FROM   customers
WHERE  customer_name ILIKE '%ромашк%'
   OR  customer_name ILIKE '%свежест%'
   OR  customer_name ILIKE '%колос%'
ORDER  BY inn ASC, customer_id ASC;""")

    headers_a6 = ["ID", "Наименование в базе", "ИНН контрагента", "Контактный телефон", "Лимит (руб)"]
    data_a6 = [
        ["9", "ИП Ромашов (Колос)", "562810604315", "8-937-683-84-23", "500 000 ₽"],
        ["72", "ООО \"Колос\" (Свежесть)", "562810604315", "8-937-683-84-23", "300 000 ₽"],
        ["2", "ООО \"Ромашка\"", "7924695572", "8-952-311-84-97", "4 000 000 ₽"],
        ["69", "Ромашка ООО", "7924695572", "8-952-311-84-97", "500 000 ₽"],
        ["70", "ООО  \"Ромашка\" (с двойным пробелом)", "7924695572", "8-952-311-84-97", "300 000 ₽"],
        ["8", "АО \"Свежесть\"", "8423916122", "+7 (953) 414-42-73", "5 000 000 ₽"],
        ["71", "ООО \"Свежесть\"", "8423916122", "+7 (953) 414-42-73", "300 000 ₽"]
    ]
    create_table(headers_a6, data_a6, col_widths=[0.5, 2.7, 1.4, 1.4, 0.9])
    add_p(
        "Что произойдет с отчетом «Топ-10 клиентов по выручке»:\n"
        "Выручка одного и того же юридического лица дробится между несколькими суррогатными карточками. "
        "В результате крупный стратегический покупатель (например, «Ромашка» с оборотом по трем карточкам) выпадает из Топ-10. "
        "Хуже того: кредитный лимит рассчитывается по каждой карточке изолированно (4 млн + 0.5 млн + 0.3 млн = 4.8 млн), "
        "что позволяет контрагенту несанкционированно выбирать товара на сумму, превышающую лимит риска компании."
    )

    # =========================================================================
    # ЗАДАНИЕ А7 (МАСЛО НИЖЕ СЕБЕСТОИМОСТИ)
    # =========================================================================
    add_h1("6. Ценообразование против себестоимости: убыточное масло (Задание А7)")
    add_p("Анализ позиций сливочного масла показал фундаментальный сбой в ценовой политике предприятия:")

    add_code_block("""-- Шаг 1. Сравнение базового прайса и себестоимости:
SELECT product_id, product_name, base_price, standard_cost,
       ROUND(base_price - standard_cost, 2) AS initial_margin_rub
FROM   products
WHERE  product_name ILIKE 'масло%'
ORDER  BY product_id;

-- Шаг 2. Подсчет сделок, где цена продажи ниже себестоимости:
-- Масло 82,5 % (product_id = 13, standard_cost = 205.00):
SELECT COUNT(*) FROM order_items WHERE product_id = 13 AND unit_price * (1 - discount_pct / 100) < 205.00;
-- Результат: 552 позиции (100.0 % продаж масла 82,5 %!)

-- Масло 72,5 % (product_id = 14, standard_cost = 151.00):
SELECT COUNT(*) FROM order_items WHERE product_id = 14 AND unit_price * (1 - discount_pct / 100) < 151.00;
-- Результат: 365 позиций (69.7 % продаж масла 72,5 %!)""")

    headers_a7 = ["ID", "Товар", "Базовая цена", "Себестоимость", "Базовая маржа", "Всего продаж", "Убыточных продаж", "% убытка"]
    data_a7 = [
        ["13", "Масло сливочное 82,5% 180 г", "189.00 ₽", "205.00 ₽", "-16.00 ₽ (УБЫТОК!)", "552", "552", "100.0 %"],
        ["14", "Масло сливочное 72,5% 180 г", "159.00 ₽", "151.00 ₽", "+8.00 ₽ (маржа 5%)", "524", "365", "69.7 %"]
    ]
    create_table(headers_a7, data_a7, col_widths=[0.4, 2.3, 0.9, 0.9, 1.1, 0.7, 0.7, 0.9])

    add_callout(
        "Критический вывод:\n"
        "• По маслу 82,5 % базовый прайс (189 ₽) УЖЕ НИЖЕ СЕБЕСТОИМОСТИ (205 ₽). Предприятие теряет минимум 16 рублей на каждой отгруженной пачке "
        "даже без скидки, а с учетом скидок менеджеров убыток удваивается. Все 552 сделки — глубоко убыточны.\n"
        "• По маслу 72,5 % базовая маржа составляет всего 8 рублей (5 %). Любая скидка более 5 % загоняет сделку в чистый минус. "
        "В итоге 365 сделок из 524 завершились прямым убытком.\n"
        "Что проверить в следующих модулях: 1) Рецептуру recipes на масло (почему себестоимость выросла до 205 руб.); "
        "2) Немедленно поднять отпускную цену масла 82,5 % в price_history минимум до 230–240 руб.",
        title="Экономическая катастрофа в ценообразовании сливочного масла",
        border_color="C00000",
        bg_color="FDF2F2"
    )

    # =========================================================================
    # ЗАДАНИЯ А8 – А9 (ПАГИНАЦИЯ СЧЕТОВ)
    # =========================================================================
    add_h1("7. Рейтинги крупнейших счетов и техника пагинации (Задания А8 – ★А9)")

    add_h2("Задание А8. Классическая пагинация (OFFSET / FETCH NEXT)")
    add_code_block("""-- Первая страница рейтинга (Топ-10 счетов):
SELECT invoice_id, invoice_number, order_id, invoice_date, amount
FROM   invoices
ORDER  BY amount DESC, invoice_id ASC
FETCH  FIRST 10 ROWS ONLY;

-- Вторая страница рейтинга (места 11–20):
SELECT invoice_id, invoice_number, order_id, invoice_date, amount
FROM   invoices
ORDER  BY amount DESC, invoice_id ASC
OFFSET 10
FETCH  NEXT 10 ROWS ONLY;""")
    add_p(
        "Проверка результатов:\n"
        "• 1-е место: Счёт СЧ-2025-02646 на сумму 1 245 137,26 ₽ (заказ 2753 от 10.04.2025).\n"
        "• 11-е место (старт 2-й страницы): Счёт СЧ-2025-03994 на сумму 887 276,43 ₽."
    )

    add_h2("Задание ★А9. Высокопроизводительная Keyset-пагинация (поиск без OFFSET)")
    add_p(
        "На больших объемах данных OFFSET вынужден сканировать и отбрасывать тысячи строк. "
        "Курсорная keyset-пагинация использует сравнение кортежей значений последнего элемента предыдущей страницы."
    )
    add_code_block("""-- Выборка следующих 10 счетов после invoice_id = 2881 (сумма 875 376,40):
SELECT invoice_id, invoice_number, order_id, invoice_date, amount
FROM   invoices
WHERE  (amount, invoice_id) < (875376.40, 2881)
ORDER  BY amount DESC, invoice_id DESC
FETCH  FIRST 10 ROWS ONLY;""")
    add_p(
        "Проверка: первая строка выборки — счёт СЧ-2025-03817 на сумму 867 809,62 ₽ (invoice_id = 3817).\n\n"
        "Почему направление сортировки обоих ключей обязано совпадать (DESC, DESC):\n"
        "Кортежное выражение (amount, invoice_id) < (A, B) эквивалентно логическому условию (amount < A) OR (amount = A AND invoice_id < B). "
        "Оно корректно продолжает убывающую последовательность только тогда, когда оба атрибута упорядочены в одну сторону. "
        "При несовпадении направлений (например, DESC и ASC) при равных суммах порядок обхода сломается, а СУБД не сможет задействовать составной B-Tree индекс."
    )

    # =========================================================================
    # ЗАДАНИЕ ★А10 И ВЫВОД ДЛЯ РУКОВОДСТВА
    # =========================================================================
    add_h1("8. Итоговая оценка потерь и Вывод для руководства (Задание ★А10)")

    add_h2("Задание ★А10. Цифра для руководства (расчет совокупных потерь)")
    add_code_block("""SELECT COUNT(*)                                                           AS items,
       ROUND(SUM(quantity * unit_price * discount_pct / 100), 2)          AS discount_total_rub,
       ROUND(SUM(quantity * unit_price * (discount_pct - 10) / 100), 2)   AS over_policy_rub
FROM   order_items
WHERE  discount_pct > 10;""")

    headers_a10 = ["Позиций со сверх-скидкой", "Совокупный объём скидок", "УЩЕРБ СВЕРХ НОРМАТИВА 10%"]
    data_a10 = [
        ["4 365 строк (24.8 % всех продаж)", "40 741 250.63 ₽", "17 979 376.44 ₽"]
    ]
    create_table(headers_a10, data_a10, col_widths=[2.3, 2.3, 2.3])

    add_h2("Официальный вывод для руководства компании «Питание +»:")
    add_callout(
        "«Мы обнаружили систематическое нарушение коммерческого регламента компании в части предоставления скидок, "
        "установления отпускных цен и ведения клиентской базы.\n\n"
        "Это касается 4 365 позиций заказов (почти четверть всех строк продаж — 24.8 %), где скидка превышает допустимые 10 %, "
        "а также 100 % продаж сливочного масла 82,5 % (552 позиции) и 69.7 % продаж масла 72,5 % (365 позиций), которые отгружаются ниже себестоимости.\n\n"
        "Потенциальные прямые потери составляют 17 979 376,44 руб. только на несанкционированных скидках. "
        "При этом все крупнейшие скидки (топ-10 с перерасходом до 53 тыс. руб. на позицию) согласованы одним сотрудником — Соколовым И. А. "
        "преимущественно в адрес клиента ООО „Свежесть-Трейд“, что указывает на системный сговор или несанкционированные преференции.\n\n"
        "Чтобы подтвердить персональную ответственность менеджеров и масштаб скрытых кассовых разрывов, на следующем шаге (модули 3–4) "
        "мы проведем детальный многомерный анализ с помощью соединений таблиц (JOIN) и агрегации (GROUP BY), "
        "а также объединим дублирующиеся карточки контрагентов (выявлено 7 записей-клонов по совпадающим ИНН и телефонам).\n\n"
        "Какая находка обходится дороже всего: Сверхнормативные скидки (~18 млн руб.) и продажа масла 82,5 % с отрицательной маржой.\n"
        "Что проверить в первую очередь: Немедленно заблокировать в учетной системе возможность ручного ввода скидок свыше 10 % "
        "и повысить базовую цену масла 82,5 % выше 205 руб.»",
        title="Доклад для Совета Директоров (Команда А «Финансы и продажи»)",
        border_color="1B365D",
        bg_color="F7F9FC"
    )

    output_dir = r"C:\Users\serpu\Downloads\АкадемияИТ\Postgres"
    output_path = os.path.join(output_dir, "Отчет_Модуль_1_Финансы_и_Продажи.docx")
    doc.save(output_path)
    print(f"Отчет по Модулю 1 успешно сохранен: {output_path}")

if __name__ == "__main__":
    create_m1_report()
