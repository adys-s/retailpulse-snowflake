-- =====================================================================
-- RetailPulse - 03 : Transformation SQL & extraction du JSON
-- ---------------------------------------------------------------------
-- STAGING.RAW_TRANSACTIONS (VARIANT)  ->  ANALYTICS.FACT_SALES
-- =====================================================================
use role sysadmin;
use warehouse RETAIL_WH;

-- ---------------------------------------------------------------------
-- Étape A : extraire les champs simples
--   :  -> lire une clé       .  -> descendre dans un objet
--   :: -> convertir dans un type SQL
-- ---------------------------------------------------------------------
select
  RAW:transaction_id::string          as TRANSACTION_ID,
  RAW:customer_info.id::string        as CUSTOMER_ID,
  RAW:customer_info.country::string   as COUNTRY,
  RAW:total_amount::number(10,2)      as TOTAL_AMOUNT,
  RAW:event_timestamp::timestamp_ntz  as EVENT_TIMESTAMP
from RETAIL_DB.STAGING.RAW_TRANSACTIONS
limit 5;

-- ---------------------------------------------------------------------
-- Étape B : déplier la liste des articles avec LATERAL FLATTEN
--   -> une ligne par produit de chaque commande
-- ---------------------------------------------------------------------
select
  RAW:transaction_id::string       as TRANSACTION_ID,
  item.value:product_name::string  as PRODUCT_NAME,
  item.value:quantity::number      as QUANTITY
from RETAIL_DB.STAGING.RAW_TRANSACTIONS,
lateral flatten(input => RAW:items) item
order by TRANSACTION_ID
limit 10;

-- ---------------------------------------------------------------------
-- Étape C : une ligne par commande, avec le nombre d'articles
--   NB_LINES = nombre de produits différents
--   NB_ITEMS = nombre total d'articles (somme des quantités)
-- ---------------------------------------------------------------------
select
  RAW:transaction_id::string         as TRANSACTION_ID,
  RAW:customer_info.id::string       as CUSTOMER_ID,
  RAW:customer_info.country::string  as COUNTRY,
  RAW:total_amount::number(10,2)     as TOTAL_AMOUNT,
  count(*)                           as NB_LINES,
  sum(item.value:quantity::number)   as NB_ITEMS
from RETAIL_DB.STAGING.RAW_TRANSACTIONS,
lateral flatten(input => RAW:items) item
group by 1, 2, 3, 4
order by TRANSACTION_ID;

-- ---------------------------------------------------------------------
-- Étape D : table de faits ANALYTICS.FACT_SALES
-- ---------------------------------------------------------------------
create or replace table RETAIL_DB.ANALYTICS.FACT_SALES (
  TRANSACTION_ID   varchar(10),
  CUSTOMER_ID      varchar(10),
  COUNTRY          varchar(50),
  TOTAL_AMOUNT     number(10,2),
  NB_LINES         number,
  NB_ITEMS         number,
  EVENT_TIMESTAMP  timestamp_ntz,
  LOADED_AT        timestamp_ltz default current_timestamp()
);

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
from RETAIL_DB.STAGING.RAW_TRANSACTIONS,
lateral flatten(input => RAW:items) item
group by 1, 2, 3, 4, 7;
