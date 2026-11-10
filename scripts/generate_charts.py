# -*- coding: utf-8 -*-
"""
Генерация визуализаций и графиков для репозитория AcademyIT_SQL.
Команда А: «Финансы и продажи».
"""

import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

# Настройки стилей
plt.rcParams['font.sans-serif'] = 'DejaVu Sans'
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.edgecolor'] = '#CCCCCC'
plt.rcParams['axes.linewidth'] = 0.8

output_dir = r"C:\Users\serpu\Downloads\АкадемияИТ\Postgres\images"
os.makedirs(output_dir, exist_ok=True)

# -----------------------------------------------------------------------------
# График 1. Распределение скидок по строкам заказов
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
labels = ['В рамках нормы (<= 10 %)', 'Сверх политики (10 % - 20 %)', 'Экстремальные (>= 20 %)']
sizes = [17576 - 4365, 4365 - 1741, 1741]
colors = ['#2E75B6', '#F39C12', '#C00000']
explode = (0, 0.05, 0.1)

wedges, texts, autotexts = ax.pie(
    sizes, explode=explode, labels=labels, colors=colors,
    autopct='%1.1f%%', startangle=140, pctdistance=0.75,
    textprops=dict(color='#262626', fontsize=10)
)
for at in autotexts:
    at.set_fontsize(10)
    at.set_weight('bold')
    at.set_color('white')

ax.set_title('Распределение скидок в заказах компании «Питание +»\n(Всего 17 576 позиций, 4 365 с нарушением регламента)',
             fontsize=12, fontweight='bold', color='#1B365D', pad=15)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, '01_discounts_breakdown.png'))
plt.close()

# -----------------------------------------------------------------------------
# График 2. Анализ рентабельности сливочного масла
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5), dpi=300)
categories = ['Масло 82,5% (180 г)', 'Масло 72,5% (180 г)']
base_prices = [189.0, 159.0]
standard_costs = [205.0, 151.0]

x = np.arange(len(categories))
width = 0.35

rects1 = ax.bar(x - width/2, base_prices, width, label='Базовая цена прайса (руб.)', color='#2E75B6')
rects2 = ax.bar(x + width/2, standard_costs, width, label='Плановая себестоимость (руб.)', color='#E74C3C')

ax.set_ylabel('Рубли за пачку', fontsize=11, fontweight='bold', color='#1B365D')
ax.set_title('Сравнение базовой цены и себестоимости сливочного масла\n(Масло 82,5% изначально продаётся с прямым убытком -16 руб./пачка)',
             fontsize=12, fontweight='bold', color='#1B365D', pad=15)
ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=11, fontweight='bold')
ax.legend(frameon=True, facecolor='#F9FAFB')
ax.grid(axis='y', linestyle='--', alpha=0.5)

# Подписи над столбиками
for rect in rects1:
    height = rect.get_height()
    ax.annotate(f'{height:.2f} ₽', xy=(rect.get_x() + rect.get_width() / 2, height),
                xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontweight='bold')

for rect in rects2:
    height = rect.get_height()
    ax.annotate(f'{height:.2f} ₽', xy=(rect.get_x() + rect.get_width() / 2, height),
                xytext=(0, 3), textcoords="offset points", ha='center', va='bottom', fontweight='bold', color='#C00000')

plt.tight_layout()
plt.savefig(os.path.join(output_dir, '02_butter_margin_analysis.png'))
plt.close()

# -----------------------------------------------------------------------------
# График 3. Своевременность отгрузок
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
bars = ax.bar(['Вовремя к required_date', 'С опозданием (shipped > required)'],
              [3258, 984], color=['#27AE60', '#C00000'], width=0.5)
ax.set_ylabel('Количество заказов', fontsize=11, fontweight='bold', color='#1B365D')
ax.set_title('Своевременность отгрузки заказов клиентам\n(23.2% отгрузок срывают согласованный срок доставки)',
             fontsize=12, fontweight='bold', color='#1B365D', pad=15)
ax.grid(axis='y', linestyle='--', alpha=0.5)

for bar in bars:
    yval = bar.get_height()
    pct = (yval / 4242) * 100
    ax.text(bar.get_x() + bar.get_width()/2.0, yval + 50, f'{yval:,} шт. ({pct:.1f}%)',
            ha='center', va='bottom', fontweight='bold', fontsize=11)

plt.tight_layout()
plt.savefig(os.path.join(output_dir, '03_shipment_punctuality.png'))
plt.close()

# -----------------------------------------------------------------------------
# График 4. Дисциплина оплат клиентами (дебиторская задолженность)
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
labels = ['Оплачено в срок (до due_date)', 'Просрочено (payment > due_date)']
sizes = [2128, 2391]
colors = ['#2980B9', '#E67E22']
explode = (0, 0.08)

wedges, texts, autotexts = ax.pie(
    sizes, explode=explode, labels=labels, colors=colors,
    autopct='%1.1f%%', startangle=140, pctdistance=0.75,
    textprops=dict(color='#262626', fontsize=10)
)
for at in autotexts:
    at.set_fontsize(11)
    at.set_weight('bold')
    at.set_color('white')

ax.set_title('Платёжная дисциплина клиентов\n(52.9% всех платежей поступают с нарушением установленного срока)',
             fontsize=12, fontweight='bold', color='#1B365D', pad=15)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, '04_payment_punctuality.png'))
plt.close()

# -----------------------------------------------------------------------------
# График 5. Воронка жизненного цикла заказов
# -----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5), dpi=300)
statuses = ['Доставлен', 'Отгружен', 'Новый', 'В работе', 'Отменён']
counts = [4212, 30, 22, 17, 177]
colors = ['#27AE60', '#2980B9', '#8E44AD', '#F39C12', '#C00000']

bars = ax.barh(statuses, counts, color=colors, height=0.6)
ax.set_xlabel('Количество заказов', fontsize=11, fontweight='bold', color='#1B365D')
ax.set_title('Распределение заказов по текущему статусу в системе\n(Всего 4 458 заказов в базе данных pitanie)',
             fontsize=12, fontweight='bold', color='#1B365D', pad=15)
ax.invert_yaxis()
ax.grid(axis='x', linestyle='--', alpha=0.5)

for bar in bars:
    xval = bar.get_width()
    ax.text(xval + 40, bar.get_y() + bar.get_height()/2.0, f'{xval:,} шт.',
            ha='left', va='center', fontweight='bold', fontsize=10)

plt.tight_layout()
plt.savefig(os.path.join(output_dir, '05_order_lifecycle.png'))
plt.close()

print("Все графики успешно сгенерированы в папку:", output_dir)
