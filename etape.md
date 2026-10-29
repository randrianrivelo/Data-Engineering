# Étapes détaillées du projet Data Engineering

## 1. Création et démarrage de PostgreSQL avec Docker

Le projet utilise PostgreSQL dans un conteneur Docker afin d'avoir un environnement de base de données isolé et reproductible.

Le conteneur utilisé est :

```text
postgres-data-engineering
```

La base de données utilisée est :

```text
data_engineering
```

Le démarrage du conteneur est effectué depuis le dossier `postgres` :

```powershell
cd "H:\ESMIA\L3_ESMIA\L3_S5\Data_Ingenering\nouvel\postgres"

docker compose up -d
```

Vérification du conteneur :

```powershell
docker ps
```

Le conteneur PostgreSQL doit apparaître avec le port :

```text
0.0.0.0:5432->5432/tcp
```

---

# 2. Connexion à PostgreSQL

Connexion à la base de données :

```powershell
docker exec -it postgres-data-engineering psql -U hyacinthe -d data_engineering
```

Vérification de la base utilisée :

```sql
SELECT current_database();
```

Résultat :

```text
data_engineering
```

Vérification de l'utilisateur :

```sql
SELECT current_user;
```

Résultat :

```text
hyacinthe
```

---

# 3. Création des tables OLTP

Les premières données du projet proviennent du modèle OLTP.

Le fichier utilisé est :

```text
bronze/ecommerce_oltp_schema.sql
```

Il contient la structure des tables :

```text
categories
customers
products
orders
order_items
payments
```

Le script est exécuté avec :

```powershell
docker exec -i postgres-data-engineering psql -U hyacinthe -d data_engineering < ".\bronze\ecommerce_oltp_schema.sql"
```

Vérification :

```sql
\dt
```

Les tables OLTP sont alors disponibles dans PostgreSQL.

---

# 4. Chargement des données OLTP

Après avoir créé les tables, les données sont chargées avec :

```text
bronze/ecommerce_oltp_inserts.sql
```

Commande :

```powershell
docker exec -i postgres-data-engineering psql -U hyacinthe -d data_engineering < ".\bronze\ecommerce_oltp_inserts.sql"
```

Les volumes obtenus sont ensuite vérifiés :

```sql
SELECT COUNT(*) FROM categories;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM payments;
```

Résultats :

```text
categories   : 10
customers    : 1030
products     : 530
orders       : 10000
order_items  : 30000
payments     : 10000
```

Ces tables constituent les données relationnelles de départ.

---

# 5. Import du fichier CSV des expéditions

Le deuxième ensemble de données provient du fichier :

```text
bronze/shipments.csv
```

Le fichier contient les colonnes :

```text
shipment_id
order_id
carrier
shipped_at
delivered_at
delivery_status
shipping_cost
```

Au lieu de modifier directement le fichier original, une table de staging est créée dans PostgreSQL.

---

# 6. Création de la table staging

La table `staging_shipments` est créée pour recevoir les données exactement comme elles apparaissent dans le CSV.

Commande SQL :

```sql
CREATE TABLE staging_shipments (
    shipment_id INTEGER,
    order_id INTEGER,
    carrier VARCHAR(100),
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    delivery_status VARCHAR(50),
    shipping_cost NUMERIC(10,2)
);
```

Vérification de la structure :

```sql
\d staging_shipments
```

La table contient donc les 7 colonnes originales du CSV.

---

# 7. Chargement du CSV dans staging

Le fichier CSV est ensuite importé dans `staging_shipments`.

Depuis PowerShell :

```powershell
docker exec -i postgres-data-engineering psql -U hyacinthe -d data_engineering -c "COPY staging_shipments (shipment_id, order_id, carrier, shipped_at, delivered_at, delivery_status, shipping_cost) FROM STDIN WITH (FORMAT csv, HEADER true)" < ".\bronze\shipments.csv"
```

Résultat :

```text
COPY 6727
```

Cela signifie que 6727 lignes ont été importées.

Vérification :

```sql
SELECT COUNT(*) AS total_lignes
FROM staging_shipments;
```

Résultat :

```text
6727
```

---

# 8. Vérification des données brutes

Avant de nettoyer les données, leur contenu est observé directement :

```sql
SELECT *
FROM staging_shipments
LIMIT 10;
```

À ce stade, `staging_shipments` représente les données brutes importées depuis le CSV.

Aucune colonne calculée n'a encore été ajoutée.

---

# 9. Vérification des doublons

Avant la transformation, les identifiants d'expédition sont contrôlés :

```sql
SELECT
    shipment_id,
    COUNT(*) AS nombre
FROM staging_shipments
GROUP BY shipment_id
HAVING COUNT(*) > 1;
```

Aucun résultat n'est retourné.

Cela signifie qu'aucun `shipment_id` n'est présent plusieurs fois.

---

# 10. Vérification de l'intégrité avec les commandes

Chaque expédition doit être associée à une commande existante.

La vérification est effectuée avec :

```sql
SELECT COUNT(*) AS commandes_inexistantes
FROM staging_shipments s
LEFT JOIN orders o
    ON o.order_id = s.order_id
WHERE o.order_id IS NULL;
```

Résultat :

```text
0
```

Toutes les expéditions correspondent donc à une commande existante.

---

# 11. Vérification des dates

On vérifie ensuite qu'une livraison n'est pas antérieure à son expédition :

```sql
SELECT COUNT(*) AS dates_invalides
FROM staging_shipments
WHERE delivered_at < shipped_at;
```

Résultat :

```text
0
```

Aucune date incohérente de ce type n'a été détectée.

---

# 12. Vérification des transporteurs

La répartition des transporteurs est vérifiée avec :

```sql
SELECT
    carrier,
    COUNT(*) AS nombre_expeditions
FROM staging_shipments
GROUP BY carrier
ORDER BY nombre_expeditions DESC;
```

Résultats :

```text
FedEx       : 1370
MadaPost    : 1361
DHL         : 1348
Chronopost  : 1345
Colissimo   : 1303
```

Cette étape permet de vérifier que les valeurs du fichier sont cohérentes avant transformation.

---

# 13. Vérification des statuts de livraison

Les statuts présents dans les données sont vérifiés :

```sql
SELECT
    delivery_status,
    COUNT(*) AS nombre_expeditions
FROM staging_shipments
GROUP BY delivery_status
ORDER BY nombre_expeditions DESC;
```

Résultats :

```text
delivered   : 6000
in_transit  : 727
```

---

# 14. Création de la table nettoyée

Après les contrôles, une nouvelle table `shipments` est créée à partir de `staging_shipments`.

L'objectif est de ne pas modifier directement les données brutes.

La commande utilisée est :

```sql
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
```

Résultat :

```text
SELECT 6727
```

La nouvelle table contient donc 6727 lignes.

---

# 15. Nettoyage du nom des transporteurs

Lors de la création de `shipments`, la fonction :

```sql
TRIM(carrier)
```

est utilisée.

Elle permet de supprimer les espaces inutiles au début ou à la fin du nom du transporteur.

La donnée :

```text
" DHL "
```

devient par exemple :

```text
"DHL"
```

Cette transformation est réalisée au moment de la création de la table `shipments`.

---

# 16. Calcul de la colonne delay_days

Une nouvelle colonne appelée :

```text
delay_days
```

est calculée.

La règle appliquée est :

```text
si delivered_at est NULL
    → delay_days = NULL

si durée <= 5 jours
    → delay_days = 0

si durée > 5 jours
    → nombre de jours dépassant les 5 jours
```

La formule utilisée est :

```sql
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
END
```

Exemple :

```text
4 jours → 0 jour de retard
5 jours → 0 jour de retard
6 jours → 1 jour de retard
7 jours → 2 jours de retard
```

---

# 17. Vérification de la nouvelle table

Structure :

```sql
\d shipments
```

La table contient maintenant :

```text
shipment_id
order_id
carrier
shipped_at
delivered_at
delivery_status
shipping_cost
delay_days
```

On peut afficher les premières lignes :

```sql
SELECT *
FROM shipments
LIMIT 10;
```

La table `shipments` représente maintenant la donnée nettoyée et enrichie.

---

# 18. Comparaison entre les données brutes et les données transformées

Pour montrer clairement l'évolution :

```sql
SELECT
    s.shipment_id,
    s.carrier AS carrier_brut,
    f.carrier AS carrier_final,
    s.shipped_at,
    s.delivered_at,
    s.shipping_cost,
    f.delay_days
FROM staging_shipments s
JOIN shipments f
    ON f.shipment_id = s.shipment_id
LIMIT 10;
```

Cette requête permet de voir simultanément :

```text
staging_shipments
        ↓
donnée originale
        ↓
transformation
        ↓
shipments
        ↓
donnée nettoyée + delay_days
```

---

# 19. Vérification de la répartition des retards

Une fois `delay_days` calculé, sa répartition est vérifiée :

```sql
SELECT
    delay_days,
    COUNT(*) AS nombre_expeditions
FROM shipments
GROUP BY delay_days
ORDER BY delay_days;
```

Résultats obtenus :

```text
0 jours  : 4248
1 jour   : 893
2 jours  : 859
NULL     : 727
```

Donc :

```text
1752 expéditions
```

présentent un retard supérieur à 5 jours.

---

# 20. Analyse des retards par transporteur

La somme des retards est calculée pour chaque transporteur :

```sql
SELECT
    carrier AS transporteur,
    SUM(delay_days) AS retard_cumule_jours
FROM shipments
GROUP BY carrier
ORDER BY retard_cumule_jours DESC;
```

Résultats :

```text
Colissimo    : 554
FedEx        : 536
DHL          : 530
MadaPost     : 522
Chronopost   : 469
```

Cette analyse permet d'identifier les transporteurs générant le plus de jours de retard.

---

# 21. Filtrage des clients Business et Premium

Les informations des expéditions sont ensuite reliées aux commandes et aux clients.

Les relations utilisées sont :

```text
shipments.order_id
        ↓
orders.order_id

orders.customer_id
        ↓
customers.customer_id
```

La première analyse porte uniquement sur les clients `Business` et `Premium` :

```sql
SELECT
    c.segment,
    COUNT(*) AS nombre_expeditions
FROM shipments s
JOIN orders o
    ON o.order_id = s.order_id
JOIN customers c
    ON c.customer_id = o.customer_id
WHERE c.segment IN ('Business', 'Premium')
GROUP BY c.segment;
```

Résultats :

```text
Business : 1703
Premium  : 1492
```

---

# 22. Calcul des retards pour Business et Premium

On calcule ensuite le retard cumulé par transporteur :

```sql
SELECT
    s.carrier AS transporteur,
    SUM(s.delay_days) AS retard_cumule_jours
FROM shipments s
JOIN orders o
    ON o.order_id = s.order_id
JOIN customers c
    ON c.customer_id = o.customer_id
WHERE c.segment IN ('Business', 'Premium')
GROUP BY s.carrier
ORDER BY retard_cumule_jours DESC;
```

Résultats :

```text
Colissimo    : 267
DHL          : 252
MadaPost     : 251
FedEx        : 242
Chronopost   : 240
```

---

# 23. Ajout du filtre sur l'année 2026

La question métier demande également le coût d'expédition sur l'année en cours.

L'année utilisée dans le projet est 2026.

Au lieu d'utiliser :

```sql
EXTRACT(YEAR FROM shipped_at) = 2026
```

on utilise une plage de dates :

```sql
s.shipped_at >= DATE '2026-01-01'
AND s.shipped_at < DATE '2027-01-01'
```

Cette écriture permet notamment de conserver une condition de recherche directement sur la colonne `shipped_at`.

---

# 24. Requête métier finale

La requête finale combine :

* les expéditions ;
* les commandes ;
* les clients ;
* les segments Business et Premium ;
* l'année 2026 ;
* les transporteurs ;
* les pays ;
* le retard cumulé ;
* le coût total d'expédition.

```sql
SELECT
    s.carrier AS transporteur,
    c.country AS pays_destination,
    COUNT(*) AS nombre_expeditions,
    SUM(s.delay_days) AS retard_cumule_jours,
    ROUND(SUM(s.shipping_cost), 2) AS cout_total_expedition
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
```

Cette requête répond à la question métier :

> Parmi les clients Business et Premium, quels sont les transporteurs générant le plus de jours de retard cumulés au-delà de 5 jours et quel est le coût total d'expédition payé en 2026, réparti par pays ?

---

# 25. Comparaison des performances

Afin d'étudier les performances, deux approches sont comparées.

La première approche recalcule le retard à chaque requête.

La deuxième approche utilise directement la colonne `delay_days`,
qui a été calculée lors de la transformation des données.

---

# 26. Requête non optimisée

```sql
EXPLAIN ANALYZE
SELECT
    s.carrier AS transporteur,
    c.country AS pays_destination,
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
```

Cette version recalcule le retard à partir de :

```text
delivered_at
shipped_at
```

à chaque exécution.

---

# 27. Requête optimisée

La deuxième version utilise directement la colonne déjà calculée :

```sql
EXPLAIN ANALYZE
SELECT
    s.carrier AS transporteur,
    c.country AS pays_destination,
    COUNT(*) AS nombre_expeditions,
    SUM(s.delay_days) AS retard_cumule_jours,
    ROUND(SUM(s.shipping_cost), 2) AS cout_total_expedition
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
```

La différence principale est que le calcul complexe du retard n'est plus réalisé pendant l'analyse.

Il a déjà été effectué lors de la transformation :

```text
staging_shipments
        ↓
transformation
        ↓
delay_days
        ↓
requêtes analytiques
```

---

# 28. Utilisation de EXPLAIN ANALYZE

La commande :

```sql
EXPLAIN ANALYZE
```

permet de mesurer le temps réel d'exécution et d'observer le plan choisi par PostgreSQL.

Lors du premier test, le temps obtenu était :

```text
Planning Time: 11.667 ms
Execution Time: 14.103 ms
```

Le plan contenait notamment :

```text
Seq Scan on shipments
Seq Scan on orders
Seq Scan on customers
Hash Join
HashAggregate
Sort
```

Les scans séquentiels sont normaux dans ce projet car les tables sont relativement petites.

---

# 29. Résultat final du pipeline

Le traitement complet peut être résumé ainsi :

```text
ecommerce_oltp_schema.sql
        ↓
Création des tables OLTP
        ↓
ecommerce_oltp_inserts.sql
        ↓
Chargement des données clients / commandes
        ↓
shipments.csv
        ↓
staging_shipments
        ↓
Contrôles qualité
        ↓
Vérification des doublons
        ↓
Vérification des commandes
        ↓
Vérification des dates
        ↓
Contrôle des transporteurs et statuts
        ↓
TRIM(carrier)
        ↓
Calcul de delay_days
        ↓
shipments
        ↓
Filtrage Business / Premium
        ↓
Filtrage année 2026
        ↓
Jointure customers / orders / shipments
        ↓
Analyse par transporteur et pays
        ↓
Calcul du retard cumulé
        ↓
Calcul du coût total
        ↓
EXPLAIN ANALYZE
        ↓
Comparaison des performances
```

# 30. État final

À la fin du processus, les données d'expédition sont disponibles dans :

```text
shipments
```

avec :

```text
6727 lignes
```

et les colonnes :

```text
shipment_id
order_id
carrier
shipped_at
delivered_at
delivery_status
shipping_cost
delay_days
```

La table constitue la donnée finale nettoyée et enrichie utilisée pour les analyses.

La couche Bronze conserve les sources originales, la couche Silver contient
les opérations de staging et de transformation, et la couche Gold correspond
aux données finales exploitables pour l'analyse.

Une limitation est à signaler : le fichier `shipments.csv` ne contient pas
de colonne `destination_country`. Le champ `customers.country` est donc
utilisé comme représentation du pays associé au client dans l'analyse.
Fichier utilisé :
`gold/01_create_gold.sql`

Action :
Création d'une table Gold à partir des données nettoyées
`shipments`, reliées aux tables `orders` et `customers`.

Relations utilisées :
- `shipments.order_id = orders.order_id`
- `orders.customer_id = customers.customer_id`

Résultat :
La table `gold_shipments_analysis` contient les informations
nécessaires à l'analyse métier.

### 7.2 Contrôles qualité Gold

Fichier utilisé :
`gold/02_quality_checks_gold.sql`

Contrôles effectués :
- nombre de lignes ;
- doublons ;
- répartition par segment ;
- répartition par transporteur ;
- répartition par pays ;
- valeurs NULL.

### 7.3 Analyse métier

Fichier utilisé :
`gold/03_analysis.sql`

L'analyse porte sur :
- les clients Business et Premium ;
- les expéditions de l'année 2026 ;
- le transporteur ;
- le pays ;
- le retard cumulé au-delà de 5 jours ;
- le coût total d'expédition.

Les données sont regroupées par :
`carrier + country`.

### 7.4 Comparaison des performances

Fichier utilisé :
`gold/04_performance.sql`

Deux requêtes ont été comparées avec `EXPLAIN ANALYZE` :

1. une requête recalculant `delay_days` ;
2. une requête utilisant directement `delay_days`
   déjà calculé dans Silver.

Les temps d'exécution obtenus sont relevés afin de déterminer
la requête la plus performante.