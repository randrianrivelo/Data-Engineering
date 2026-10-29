-- ============================================================
-- GOLD - Contrôles qualité
-- ============================================================

-- 1. Nombre total de lignes
SELECT COUNT(*) AS total_lignes
FROM gold_shipments_analysis;


-- 2. Vérification des doublons shipment_id
SELECT
    shipment_id,
    COUNT(*) AS nombre
FROM gold_shipments_analysis
GROUP BY shipment_id
HAVING COUNT(*) > 1;


-- 3. Répartition par segment
SELECT
    segment,
    COUNT(*) AS nombre_expeditions
FROM gold_shipments_analysis
GROUP BY segment
ORDER BY nombre_expeditions DESC;


-- 4. Répartition par transporteur
SELECT
    carrier,
    COUNT(*) AS nombre_expeditions
FROM gold_shipments_analysis
GROUP BY carrier
ORDER BY nombre_expeditions DESC;


-- 5. Répartition par pays
SELECT
    country,
    COUNT(*) AS nombre_expeditions
FROM gold_shipments_analysis
GROUP BY country
ORDER BY nombre_expeditions DESC;


-- 6. Vérification des valeurs importantes NULL
SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_null,
    COUNT(*) FILTER (WHERE segment IS NULL) AS segment_null,
    COUNT(*) FILTER (WHERE country IS NULL) AS country_null,
    COUNT(*) FILTER (WHERE carrier IS NULL) AS carrier_null,
    COUNT(*) FILTER (WHERE shipping_cost IS NULL) AS shipping_cost_null,
    COUNT(*) FILTER (WHERE delay_days IS NULL) AS delay_days_null
FROM gold_shipments_analysis;