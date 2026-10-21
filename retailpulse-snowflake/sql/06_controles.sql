-- =====================================================================
-- RetailPulse - 06 : Contrôles de qualité
-- ---------------------------------------------------------------------
-- Vérifications à lancer après chaque étape.
-- Les chiffres attendus sont calculés à partir des fichiers sources.
-- =====================================================================
use role sysadmin;
use warehouse RETAIL_WH;

-- ---------------------------------------------------------------------
-- Après 02 : chargement initial (attendu : 500)
-- ---------------------------------------------------------------------
select count(*) as NB_LIGNES_RAW
from RETAIL_DB.STAGING.RAW_TRANSACTIONS;

-- ---------------------------------------------------------------------
-- Après 03 : FACT_SALES (attendu : 500 / 1580 / 72520.00)
-- ---------------------------------------------------------------------
select
  count(*)          as NB_COMMANDES,
  sum(NB_ITEMS)     as TOTAL_ARTICLES,
  sum(TOTAL_AMOUNT) as CHIFFRE_AFFAIRES
from RETAIL_DB.ANALYTICS.FACT_SALES;

-- ---------------------------------------------------------------------
-- Test de sécurité du rôle ANALYST_ROLE
-- À exécuter ligne par ligne. Les rôles secondaires sont désactivés
-- pour que seuls les droits d'ANALYST_ROLE s'appliquent.
-- ---------------------------------------------------------------------
use role ANALYST_ROLE;
use secondary roles none;

select * from RETAIL_DB.ANALYTICS.FACT_SALES limit 5;       -- ✅ autorisé
delete from RETAIL_DB.ANALYTICS.FACT_SALES;                  -- ❌ refusé (lecture seule)
select * from RETAIL_DB.STAGING.RAW_TRANSACTIONS limit 5;    -- ❌ refusé (pas d'accès à STAGING)

use secondary roles all;
use role sysadmin;

-- ---------------------------------------------------------------------
-- Après 04 : Stream et Task
-- ---------------------------------------------------------------------
select count(*) as LIGNES_DANS_STREAM                        -- attendu : 0 après la Task
from RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM;

select count(*), sum(NB_ITEMS), sum(TOTAL_AMOUNT)             -- attendu : 550 / 1758 / 80487.40
from RETAIL_DB.ANALYTICS.FACT_SALES;

-- Les ventes ajoutées par la Task (LOADED_AT le plus récent)
select TRANSACTION_ID, COUNTRY, TOTAL_AMOUNT, NB_ITEMS, LOADED_AT
from RETAIL_DB.ANALYTICS.FACT_SALES
order by LOADED_AT desc
limit 10;

-- ---------------------------------------------------------------------
-- Contrôle final du projet
--   PROD    : 550 lignes, 80 487,40 €
--   STAGING : 550 lignes
--   STREAM  : 0
--   DEV     : 344 lignes (ventes France supprimées dans le clone)
-- ---------------------------------------------------------------------
select 'PROD - FACT_SALES' as CONTROLE, count(*) as LIGNES, sum(TOTAL_AMOUNT) as CA
from RETAIL_DB.ANALYTICS.FACT_SALES
union all
select 'STAGING - RAW', count(*), null
from RETAIL_DB.STAGING.RAW_TRANSACTIONS
union all
select 'STREAM (doit être vide)', count(*), null
from RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM
union all
select 'DEV - FACT_SALES (clone modifié)', count(*), sum(TOTAL_AMOUNT)
from RETAIL_DB_DEV.ANALYTICS.FACT_SALES;

show tasks in schema RETAIL_DB.ANALYTICS;   -- state attendu : suspended
