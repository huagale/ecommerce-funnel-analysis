-- 03. Дополнительные срезы и проверки правил воронки.

-- Полные недели первого просмотра: понедельник 04.05 - воскресенье 06.09.
-- YEARWEEK(..., 3): ISO-неделя, начинается в понедельник.
SELECT
    YEARWEEK(FROM_UNIXTIME(first_view_ts / 1000), 3) AS cohort_week,
    COUNT(*) AS users_with_view,
    COUNT(first_cart_ts) AS users_with_cart,
    COUNT(first_purchase_ts) AS users_with_purchase,
    ROUND(100.0 * COUNT(first_cart_ts) / NULLIF(COUNT(*), 0), 2)
        AS view_to_cart_pct,
    ROUND(100.0 * COUNT(first_purchase_ts) /
        NULLIF(COUNT(first_cart_ts), 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * COUNT(first_purchase_ts) / NULLIF(COUNT(*), 0), 2)
        AS view_to_purchase_pct
FROM retailrocket.first_purchases
WHERE FROM_UNIXTIME(first_view_ts / 1000) >= '2015-05-04'
  AND FROM_UNIXTIME(first_view_ts / 1000) < '2015-09-07'
GROUP BY cohort_week
ORDER BY cohort_week;

-- Одни сутки на тех же пользователях, что в семидневной воронке.
-- Контроль: 1345063 / 27221 / 7662.
SELECT
    COUNT(*) AS users_with_view,
    COUNT(CASE
        WHEN first_cart_ts <= first_view_ts + 24 * 60 * 60 * 1000
        THEN 1 END) AS users_with_cart_1d,
    COUNT(CASE
        WHEN first_purchase_ts <= first_view_ts + 24 * 60 * 60 * 1000
        THEN 1 END) AS users_with_purchase_1d
FROM retailrocket.first_purchases;

-- Сопоставимая таблица для обоих окон.
SELECT
    1 AS window_days,
    COUNT(*) AS users_with_view,
    COUNT(CASE
        WHEN first_cart_ts <= first_view_ts + 24 * 60 * 60 * 1000
        THEN 1 END) AS users_with_cart,
    COUNT(CASE
        WHEN first_purchase_ts <= first_view_ts + 24 * 60 * 60 * 1000
        THEN 1 END) AS users_with_purchase
FROM retailrocket.first_purchases
UNION ALL
SELECT 7, COUNT(*), COUNT(first_cart_ts), COUNT(first_purchase_ts)
FROM retailrocket.first_purchases
ORDER BY window_days;

-- Покупатели после просмотра независимо от наличия корзины.
-- JOIN может вернуть несколько товарных событий одного пользователя, DISTINCT нужен, чтобы посчитать его один раз.
SELECT
    COUNT(DISTINCT p.visitorid) AS buyers_after_view_7d,
    COUNT(DISTINCT CASE
        WHEN p.first_purchase_ts IS NULL THEN p.visitorid
        END) AS buyers_outside_funnel
FROM retailrocket.first_purchases AS p
JOIN retailrocket.events_clean AS e
    ON p.visitorid = e.visitorid
    AND e.event = 'transaction'
    AND e.`timestamp` > p.first_view_ts
    AND e.`timestamp` <= p.first_view_ts + 7 * 24 * 60 * 60 * 1000;

-- Разделение покупателей вне воронки: 1041 + 47 = 1088.
-- "Нет корзины" означает нет подходящего addtocart после просмотра
-- в пределах окна, а не полное отсутствие корзины в истории.
SELECT
    COUNT(DISTINCT CASE
        WHEN p.first_cart_ts IS NULL THEN p.visitorid
        END) AS buyers_without_cart,
    COUNT(DISTINCT CASE
        WHEN p.first_cart_ts IS NOT NULL THEN p.visitorid
        END) AS buyers_with_cart_but_wrong_order
FROM retailrocket.first_purchases AS p
JOIN retailrocket.events_clean AS e
    ON p.visitorid = e.visitorid
    AND e.event = 'transaction'
    AND e.`timestamp` > p.first_view_ts
    AND e.`timestamp` <= p.first_view_ts + 7 * 24 * 60 * 60 * 1000
WHERE p.first_purchase_ts IS NULL;
