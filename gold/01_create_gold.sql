-- ============================================================
-- GOLD - Création de la table d'analyse
-- ============================================================

DROP TABLE IF EXISTS gold_shipments_analysis;

CREATE TABLE gold_shipments_analysis AS
SELECT
    s.shipment_id,
    s.order_id,
    o.customer_id,
    c.segment,
    c.country,
    s.carrier,
    s.shipped_at,
    s.delivered_at,
    s.delivery_status,
    s.shipping_cost,
    s.delay_days
FROM shipments s
JOIN orders o
    ON o.order_id = s.order_id
JOIN customers c
    ON c.customer_id = o.customer_id;