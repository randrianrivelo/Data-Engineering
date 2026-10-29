DROP TABLE IF EXISTS shipments;

CREATE TABLE shipments AS
SELECT
    shipment_id,
    order_id,
    TRIM(carrier) AS carrier,
    shipped_at,
    delivered_at,
    delivery_status,
    shipping_cost,
    CASE
        WHEN delivered_at IS NULL THEN NULL
        WHEN delivered_at - shipped_at > INTERVAL '5 days'
            THEN EXTRACT(
                DAY FROM (
                    delivered_at
                    - shipped_at
                    - INTERVAL '5 days'
                )
            )::INTEGER
        ELSE 0
    END AS delay_days
FROM staging_shipments;