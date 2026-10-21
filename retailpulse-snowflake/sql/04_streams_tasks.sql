-- =====================================================================
-- RetailPulse - 04 : Automatisation & CDC (Streams & Tasks)
-- ---------------------------------------------------------------------
-- Le Stream note les nouvelles lignes de STAGING,
-- la Task les insère automatiquement dans ANALYTICS.FACT_SALES.
-- =====================================================================
use role sysadmin;
use warehouse RETAIL_WH;

-- ---------------------------------------------------------------------
-- 1. Stream : capture uniquement les insertions (CDC)
--    Il surveille la table à partir de sa création :
--    les lignes déjà chargées n'y apparaissent pas.
-- ---------------------------------------------------------------------
create or replace stream RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM
  on table RETAIL_DB.STAGING.RAW_TRANSACTIONS
  append_only = TRUE;

-- ---------------------------------------------------------------------
-- 2. Droit d'exécuter des Tasks pour SYSADMIN
-- ---------------------------------------------------------------------
use role accountadmin;
grant execute task on account to role SYSADMIN;
use role sysadmin;

-- ---------------------------------------------------------------------
-- 3. Task planifiée toutes les heures
--    WHEN : ne démarre le warehouse que si le Stream contient des données
--    Après l'INSERT, le Stream se vide automatiquement.
-- ---------------------------------------------------------------------
create or replace task RETAIL_DB.ANALYTICS.LOAD_FACT_SALES_TASK
  warehouse = RETAIL_WH
  schedule  = '60 MINUTE'
  when SYSTEM$STREAM_HAS_DATA('RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM')
as
insert into RETAIL_DB.ANALYTICS.FACT_SALES
  (TRANSACTION_ID, CUSTOMER_ID, COUNTRY, TOTAL_AMOUNT, NB_LINES, NB_ITEMS, EVENT_TIMESTAMP)
select
  RAW:transaction_id::string,
  RAW:customer_info.id::string,
  RAW:customer_info.country::string,
  RAW:total_amount::number(10,2),
  count(*),
  sum(item.value:quantity::number),
  RAW:event_timestamp::timestamp_ntz
from RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM,
lateral flatten(input => RAW:items) item
group by 1, 2, 3, 4, 7;

-- Une Task est créée en pause : on l'active
alter task RETAIL_DB.ANALYTICS.LOAD_FACT_SALES_TASK resume;

-- ---------------------------------------------------------------------
-- 4. Simulation de nouvelles ventes
--    Téléverser data/retailpulse_sales_batch2.json dans SALES_STAGE,
--    puis le charger dans STAGING :
-- ---------------------------------------------------------------------
copy into RETAIL_DB.STAGING.RAW_TRANSACTIONS (RAW, FILE_NAME)
from (
  select $1, metadata$filename
  from @RETAIL_DB.STAGING.SALES_STAGE
)
file_format = (format_name = RETAIL_DB.STAGING.JSON_FF)
files = ('retailpulse_sales_batch2.json');

-- Le Stream contient maintenant 50 nouvelles lignes
select RAW:transaction_id::string as TRANSACTION_ID, FILE_NAME, METADATA$ACTION
from RETAIL_DB.STAGING.RAW_TRANSACTIONS_STREAM
limit 5;

-- ---------------------------------------------------------------------
-- 5. Exécution à la demande (sans attendre l'heure suivante)
-- ---------------------------------------------------------------------
execute task RETAIL_DB.ANALYTICS.LOAD_FACT_SALES_TASK;

-- Historique d'exécution (attendre ~1 min, attendu : SUCCEEDED)
select name, state, scheduled_time, completed_time, error_message
from table(RETAIL_DB.information_schema.task_history(
  task_name => 'LOAD_FACT_SALES_TASK'))
order by scheduled_time desc;
