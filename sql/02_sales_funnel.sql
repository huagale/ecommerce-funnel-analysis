-- 02. Пользовательская воронка: просмотр < корзина < покупка.
-- Общее окно: 7 суток от первого зарегистрированного просмотра.
-- Выполнять после 01_data_quality.sql.
USE retailrocket;

DROP TABLE IF EXISTS retailrocket.first_purchases;
DROP TABLE IF EXISTS retailrocket.first_carts;
DROP TABLE IF EXISTS retailrocket.funnel_users;
DROP TABLE IF EXISTS retailrocket.first_views;

CREATE TABLE retailrocket.first_views AS
SELECT
    visitorid,
    MIN(`timestamp`) AS first_view_ts
FROM retailrocket.events_clean
WHERE event = 'view'
GROUP BY visitorid;

SELECT
    visitorid,
    first_view_ts,
    FROM_UNIXTIME(first_view_ts / 1000) AS first_view_datetime
FROM retailrocket.first_views
ORDER BY visitorid
LIMIT 10;

-- 1404179 пользователей с зарегистрированным просмотром.
SELECT COUNT(*) AS users_with_view
FROM retailrocket.first_views;

-- Исключаем пользователей без полных семи суток наблюдения.
CREATE TABLE retailrocket.funnel_users AS
SELECT visitorid, first_view_ts
FROM retailrocket.first_views
WHERE first_view_ts <= (
    SELECT MAX(`timestamp`)
    FROM retailrocket.events_clean
) - 7 * 24 * 60 * 60 * 1000;

-- Контроль: 1345063.
SELECT COUNT(*) AS funnel_users_count
FROM retailrocket.funnel_users;

CREATE TABLE retailrocket.first_carts AS
SELECT
    u.visitorid,
    u.first_view_ts,
    MIN(e.`timestamp`) AS first_cart_ts
FROM retailrocket.funnel_users AS u
LEFT JOIN retailrocket.events_clean AS e
    ON u.visitorid = e.visitorid
    AND e.event = 'addtocart'
    AND e.`timestamp` > u.first_view_ts
    AND e.`timestamp` <= u.first_view_ts + 7 * 24 * 60 * 60 * 1000
GROUP BY u.visitorid, u.first_view_ts;

-- Контроль: 1345063 / 29150.
SELECT COUNT(*) AS users_with_view,
       COUNT(first_cart_ts) AS users_with_cart
FROM retailrocket.first_carts;

CREATE TABLE retailrocket.first_purchases AS
SELECT
    c.visitorid,
    c.first_view_ts,
    c.first_cart_ts,
    MIN(e.`timestamp`) AS first_purchase_ts
FROM retailrocket.first_carts AS c
LEFT JOIN retailrocket.events_clean AS e
    ON c.visitorid = e.visitorid
    AND e.event = 'transaction'
    AND e.`timestamp` > c.first_cart_ts
    AND e.`timestamp` <= c.first_view_ts + 7 * 24 * 60 * 60 * 1000
GROUP BY c.visitorid, c.first_view_ts, c.first_cart_ts;

-- Контроль: 1345063 / 29150 / 8539.
SELECT
    COUNT(*) AS users_with_view,
    COUNT(first_cart_ts) AS users_with_cart,
    COUNT(first_purchase_ts) AS users_with_purchase
FROM retailrocket.first_purchases;

-- Контроль: 2.17 / 29.29 / 0.63, значения в процентах.
SELECT
    ROUND(100.0 * COUNT(first_cart_ts) / NULLIF(COUNT(*), 0), 2)
        AS view_to_cart_pct,
    ROUND(100.0 * COUNT(first_purchase_ts) /
        NULLIF(COUNT(first_cart_ts), 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * COUNT(first_purchase_ts) / NULLIF(COUNT(*), 0), 2)
        AS view_to_purchase_pct
FROM retailrocket.first_purchases;

-- Непрохождение следующих этапов заданной последовательности.
SELECT
    COUNT(*) - COUNT(first_cart_ts) AS users_without_cart_step,
    COUNT(first_cart_ts) - COUNT(first_purchase_ts) AS users_without_purchase_step,
    ROUND(100.0 * (COUNT(*) - COUNT(first_cart_ts)) /
        NULLIF(COUNT(*), 0), 2) AS view_to_cart_dropoff_pct,
    ROUND(100.0 * (COUNT(first_cart_ts) - COUNT(first_purchase_ts)) /
        NULLIF(COUNT(first_cart_ts), 0), 2) AS cart_to_purchase_dropoff_pct
FROM retailrocket.first_purchases;
