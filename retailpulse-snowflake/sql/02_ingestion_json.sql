-- =====================================================================
-- RetailPulse - 02 : Ingestion des données semi-structurées (JSON)
-- ---------------------------------------------------------------------
-- Chaîne : fichier JSON -> stage -> format de fichier -> table VARIANT
-- =====================================================================
use role sysadmin;
use warehouse RETAIL_WH;

-- ---------------------------------------------------------------------
-- 1. Stage interne : zone de dépôt des fichiers JSON
-- ---------------------------------------------------------------------
create stage if not exists RETAIL_DB.STAGING.SALES_STAGE
  comment = 'Fichiers JSON de ventes de l''application mobile';

-- ---------------------------------------------------------------------
-- 2. Stage externe (démonstration) : bucket S3 public
--    En production, on pointerait vers son propre bucket
--    avec une STORAGE INTEGRATION.
-- ---------------------------------------------------------------------
create stage if not exists RETAIL_DB.STAGING.EXTERNAL_S3_STAGE
  url     = 's3://uni-lab-files'
  comment = 'Démo stage externe sur un bucket S3 public';

list @RETAIL_DB.STAGING.EXTERNAL_S3_STAGE;

-- ---------------------------------------------------------------------
-- 3. Format de fichier JSON
--    STRIP_OUTER_ARRAY = TRUE : le fichier est une liste [ {...}, {...} ]
--    -> une ligne par vente au lieu d'une seule ligne pour tout le fichier
-- ---------------------------------------------------------------------
create or replace file format RETAIL_DB.STAGING.JSON_FF
  type              = 'JSON'
  strip_outer_array = TRUE;

-- ---------------------------------------------------------------------
-- 4. Téléverser data/retailpulse_sales_batch1.json dans SALES_STAGE
--    (Catalog > RETAIL_DB > STAGING > Stages > SALES_STAGE > + Files)
--    puis vérifier :
-- ---------------------------------------------------------------------
list @RETAIL_DB.STAGING.SALES_STAGE;

-- Tester la lecture du fichier AVANT de le charger (attendu : 500)
select count(*)
from @RETAIL_DB.STAGING.SALES_STAGE/retailpulse_sales_batch1.json
(file_format => RETAIL_DB.STAGING.JSON_FF);

-- ---------------------------------------------------------------------
-- 5. Table des données brutes
-- ---------------------------------------------------------------------
create or replace table RETAIL_DB.STAGING.RAW_TRANSACTIONS (
  RAW        variant,                                    -- la fiche JSON complète
  FILE_NAME  varchar,                                    -- fichier d'origine
  LOADED_AT  timestamp_ltz default current_timestamp()   -- date du chargement
);

-- ---------------------------------------------------------------------
-- 6. Chargement avec COPY INTO
--    METADATA$FILENAME : nom du fichier source, fourni par Snowflake
-- ---------------------------------------------------------------------
copy into RETAIL_DB.STAGING.RAW_TRANSACTIONS (RAW, FILE_NAME)
from (
  select $1, metadata$filename
  from @RETAIL_DB.STAGING.SALES_STAGE
)
file_format = (format_name = RETAIL_DB.STAGING.JSON_FF)
files = ('retailpulse_sales_batch1.json');
