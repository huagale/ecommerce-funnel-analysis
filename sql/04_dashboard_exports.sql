-- 04. Каждый SELECT экспортировать отдельно, с заголовками столбцов.

-- 1. funnel.csv.
SELECT 'Просмотр' AS stage, COUNT(*) AS users
FROM retailrocket.first_purchases
UNION ALL
SELECT 'Корзина после просмотра', COUNT(first_cart_ts)
FROM retailrocket.first_purchases
UNION ALL
SELECT 'Покупка после корзины', COUNT(first_purchase_ts)
FROM retailrocket.first_purchases
ORDER BY users DESC;

-- 2. monthly_funnel.csv. Семь столбцов.
SELECT
    DATE_FORMAT(FROM_UNIXTIME(first_view_ts / 1000), '%Y-%m-01') AS cohort_month,
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
GROUP BY cohort_month
ORDER BY cohort_month;

-- 3. weeks.csv. Четыре столбца.
SELECT
    DATE_SUB(
        DATE(FROM_UNIXTIME(first_view_ts / 1000)),
        INTERVAL WEEKDAY(FROM_UNIXTIME(first_view_ts / 1000)) DAY
    ) AS week_start,
    ROUND(1.0 * COUNT(first_cart_ts) / NULLIF(COUNT(*), 0), 4)
        AS view_to_cart,
    ROUND(1.0 * COUNT(first_purchase_ts) /
        NULLIF(COUNT(first_cart_ts), 0), 4) AS cart_to_purchase,
    ROUND(1.0 * COUNT(first_purchase_ts) / NULLIF(COUNT(*), 0), 4)
        AS view_to_purchase
FROM retailrocket.first_purchases
WHERE FROM_UNIXTIME(first_view_ts / 1000) >= '2015-05-04'
  AND FROM_UNIXTIME(first_view_ts / 1000) < '2015-09-07'
GROUP BY week_start
ORDER BY week_start;
