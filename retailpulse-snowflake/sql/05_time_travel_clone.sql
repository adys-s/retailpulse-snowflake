-- =====================================================================
-- RetailPulse - 05 : Time Travel & Zero-Copy Clone
-- ---------------------------------------------------------------------
-- À exécuter dans la même session (les variables $ts_avant et
-- $update_qid n'existent que pendant la session en cours).
-- =====================================================================
use role sysadmin;
use warehouse RETAIL_WH;

-- =====================================================================
-- PARTIE 1 : TIME TRAVEL
-- =====================================================================

-- 1. Noter l'heure AVANT la modification
set ts_avant = current_timestamp();

-- 2. Mise à jour simulée : -10 % sur les ventes en France
update RETAIL_DB.ANALYTICS.FACT_SALES
set TOTAL_AMOUNT = TOTAL_AMOUNT * 0.9
where COUNTRY = 'France';

-- 3. Mémoriser l'identifiant de l'UPDATE (à exécuter juste après lui)
set update_qid = last_query_id();

-- 4. Comparer le présent et le passé
select sum(TOTAL_AMOUNT) as CA_ACTUEL                 -- après l'UPDATE
from RETAIL_DB.ANALYTICS.FACT_SALES;

select sum(TOTAL_AMOUNT) as CA_AVANT_AT               -- AT : à l'heure notée
from RETAIL_DB.ANALYTICS.FACT_SALES at(timestamp => $ts_avant);

select sum(TOTAL_AMOUNT) as CA_AVANT_BEFORE           -- BEFORE : juste avant l'UPDATE
from RETAIL_DB.ANALYTICS.FACT_SALES before(statement => $update_qid);

-- 5. Annuler la modification grâce à Time Travel
insert overwrite into RETAIL_DB.ANALYTICS.FACT_SALES
select * from RETAIL_DB.ANALYTICS.FACT_SALES before(statement => $update_qid);

-- =====================================================================
-- PARTIE 2 : ZERO-COPY CLONE
-- =====================================================================

-- 1. Environnement de test : copie instantanée, sans dupliquer le stockage
--    (les Tasks clonées sont créées en pause)
create or replace database RETAIL_DB_DEV clone RETAIL_DB;

-- 2. Prouver que le clone est indépendant de la production
delete from RETAIL_DB_DEV.ANALYTICS.FACT_SALES where COUNTRY = 'France';

select count(*) as LIGNES_DEV  from RETAIL_DB_DEV.ANALYTICS.FACT_SALES;  -- moins de lignes
select count(*) as LIGNES_PROD from RETAIL_DB.ANALYTICS.FACT_SALES;      -- inchangé : 550

-- =====================================================================
-- FIN DU PROJET : mettre la Task en pause pour ne plus consommer
-- =====================================================================
alter task RETAIL_DB.ANALYTICS.LOAD_FACT_SALES_TASK suspend;
