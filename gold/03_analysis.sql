-- ============================================================
-- GOLD - Analyse métier
-- Question :
-- Parmi les clients Business ou Premium,
-- quels transporteurs génèrent le plus de jours de retard
-- cumulés et quel est le coût total d'expédition en 2026,
-- réparti par pays ?
-- ============================================================

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