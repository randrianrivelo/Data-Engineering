CREATE TABLE IF NOT EXISTS staging_shipments (
    shipment_id INTEGER,
    order_id INTEGER,
    carrier VARCHAR(100),
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    delivery_status VARCHAR(50),
    shipping_cost NUMERIC(12,2)
);