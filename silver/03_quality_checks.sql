-- Nombre total d'expéditions
SELECT COUNT(*) AS total_shipments
FROM staging_shipments;


-- Répartition par transporteur
SELECT
    carrier,
    COUNT(*) AS nombre_expeditions
FROM staging_shipments
GROUP BY carrier
ORDER BY nombre_expeditions DESC;


-- Répartition par statut
SELECT
    delivery_status,
    COUNT(*) AS nombre_expeditions
FROM staging_shipments
GROUP BY delivery_status
ORDER BY nombre_expeditions DESC;


-- Recherche de doublons shipment_id
SELECT
    shipment_id,
    COUNT(*) AS nombre
FROM staging_shipments
GROUP BY shipment_id
HAVING COUNT(*) > 1;


-- Vérification des order_id inexistants
SELECT
    s.order_id
FROM staging_shipments s
LEFT JOIN orders o
    ON o.order_id = s.order_id
WHERE o.order_id IS NULL;


-- Vérification des dates incohérentes
SELECT *
FROM staging_shipments
WHERE delivered_at IS NOT NULL
  AND delivered_at < shipped_at;


-- Vérification des années présentes
SELECT
    EXTRACT(YEAR FROM shipped_at) AS annee,
    COUNT(*) AS nombre_expeditions
FROM staging_shipments
GROUP BY EXTRACT(YEAR FROM shipped_at)
ORDER BY annee;