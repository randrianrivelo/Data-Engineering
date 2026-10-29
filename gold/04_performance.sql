-- ============================================================
-- GOLD - Performance
-- Requête non optimisée
-- ============================================================

EXPLAIN ANALYZE
SELECT
    s.carrier AS transporteur,
    c.country AS pays,
    COUNT(*) AS nombre_expeditions,
    SUM(
        CASE
            WHEN s.delivered_at IS NULL THEN 0
            WHEN s.delivered_at - s.shipped_at > INTERVAL '5 days'
                THEN EXTRACT(
                    DAY FROM (
                        s.delivered_at
                        - s.shipped_at
                        - INTERVAL '5 days'
                    )
                )::INTEGER
            ELSE 0
        END
    ) AS retard_cumule_jours,
    SUM(s.shipping_cost) AS cout_total_expedition
FROM shipments s
JOIN orders o
    ON o.order_id = s.order_id
JOIN customers c
    ON c.customer_id = o.customer_id
WHERE c.segment IN ('Business', 'Premium')
  AND s.shipped_at >= DATE '2026-01-01'
  AND s.shipped_at < DATE '2027-01-01'
GROUP BY
    s.carrier,
    c.country
ORDER BY
    retard_cumule_jours DESC,
    cout_total_expedition DESC;

-- ============================================================
-- Requête optimisée
-- ============================================================

EXPLAIN ANALYZE
SELECT
    carrier AS transporteur,
    country AS pays,
    COUNT(*) AS nombre_expeditions,
    SUM(delay_days) AS retard_cumule_jours,
    ROUND(SUM(shipping_cost), 2) AS cout_total_expedition
FROM gold_shipments_analysis
WHERE segment IN ('Business', 'Premium')
  AND shipped_at >= DATE '2026-01-01'
  AND shipped_at < DATE '2027-01-01'
GROUP BY
    carrier,
    country
ORDER BY
    retard_cumule_jours DESC,
    cout_total_expedition DESC;