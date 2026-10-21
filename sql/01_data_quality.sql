-- 01. Первичное исследование и очистка.
-- Предварительно импортировать events.csv в retailrocket.events.
-- Пустые transactionid должны быть NULL.
USE retailrocket;

-- Зафиксировать настройки перед календарными расчётами.
SELECT @@session.time_zone AS session_time_zone,
       @@system_time_zone AS system_time_zone;

SHOW COLUMNS FROM retailrocket.events;

-- Контрольные значения: 2756101 / 1407580 / 235061 / 17672.
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT visitorid) AS unique_visitors,
    COUNT(DISTINCT itemid) AS unique_items,
    COUNT(DISTINCT transactionid) AS unique_transactions
FROM retailrocket.events;

-- Период событий: 03.05.2015 - 18.09.2015.
SELECT
    DATE(FROM_UNIXTIME(MIN(`timestamp`) / 1000)) AS first_event,
    DATE(FROM_UNIXTIME(MAX(`timestamp`) / 1000)) AS last_event
FROM retailrocket.events;

SELECT
    event,
    COUNT(*) AS events_count,
    COUNT(DISTINCT visitorid) AS visitors_count
FROM retailrocket.events
GROUP BY event
ORDER BY events_count DESC;

SELECT
    SUM(event IS NULL) AS null_events,
    SUM(TRIM(event) = '') AS empty_events
FROM retailrocket.events;

-- Сопоставление типа события и заполненности номера заказа.
-- 22457 событий transaction не равны 17672 уникальным заказам.
SELECT
    event,
    COUNT(*) AS total_events,
    COUNT(transactionid) AS with_transaction_id,
    SUM(transactionid IS NULL) AS without_transaction_id
FROM retailrocket.events
GROUP BY event;

-- 458 групп полных дубликатов.
-- Сумма лишних строк в этих группах: 460.
SELECT
    COUNT(*) AS duplicate_groups,
    SUM(copies - 1) AS extra_rows
FROM (
    SELECT
        `timestamp`,
        visitorid,
        event,
        itemid,
        transactionid,
        COUNT(*) AS copies
    FROM retailrocket.events
    GROUP BY `timestamp`, visitorid, event, itemid, transactionid
    HAVING COUNT(*) > 1
) AS duplicates;

-- Пересоздаётся только производная очищенная таблица.
DROP TABLE IF EXISTS retailrocket.events_clean;

CREATE TABLE retailrocket.events_clean AS
SELECT DISTINCT
    `timestamp`,
    visitorid,
    event,
    itemid,
    transactionid
FROM retailrocket.events;

-- Ожидается 2755641 событие после удаления 460 лишних строк.
SELECT COUNT(*) AS total_events
FROM retailrocket.events_clean;

-- Индекс для поиска событий пользователя в диапазоне времени.
-- Создаётся после пересоздания events_clean, поэтому повторов индекса нет.
CREATE INDEX idx_visitor_time
ON retailrocket.events_clean (visitorid, `timestamp`);

-- Активность по календарным дням.
-- orders_count: заказы с событием в данном дне. При суммировании по дням
-- один заказ может быть посчитан повторно, если его события в разных днях.
SELECT
    DATE(FROM_UNIXTIME(`timestamp` / 1000)) AS event_date,
    COUNT(*) AS events_count,
    COUNT(DISTINCT visitorid) AS visitors_count,
    COUNT(DISTINCT transactionid) AS orders_count
FROM retailrocket.events_clean
GROUP BY event_date
ORDER BY event_date;

-- Проверка заказов, события которых попали на разные календарные даты.
-- Наличие такого заказа само по себе не означает ошибку данных.
SELECT
    transactionid,
    COUNT(DISTINCT DATE(FROM_UNIXTIME(`timestamp` / 1000))) AS days_count,
    COUNT(DISTINCT visitorid) AS visitors_count,
    MIN(FROM_UNIXTIME(`timestamp` / 1000)) AS first_event,
    MAX(FROM_UNIXTIME(`timestamp` / 1000)) AS last_event
FROM retailrocket.events_clean
WHERE transactionid IS NOT NULL
GROUP BY transactionid
HAVING days_count > 1;
