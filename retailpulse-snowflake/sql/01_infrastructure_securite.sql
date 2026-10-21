-- =====================================================================
-- RetailPulse - 01 : Infrastructure & sécurité de base
-- ---------------------------------------------------------------------
-- Crée le warehouse, la base RETAIL_DB, les schémas STAGING / ANALYTICS
-- et le rôle ANALYST_ROLE (lecture seule sur ANALYTICS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Warehouse dédié au projet
-- ---------------------------------------------------------------------
use role sysadmin;

create warehouse if not exists RETAIL_WH
  warehouse_type      = standard
  warehouse_size      = 'XSMALL'
  auto_suspend        = 60      -- s'éteint après 60 s d'inactivité
  auto_resume         = true    -- se rallume automatiquement
  initially_suspended = true;   -- créé éteint : aucun coût tant qu'il ne sert pas

-- ---------------------------------------------------------------------
-- 2. Base de données et schémas
-- ---------------------------------------------------------------------
create database if not exists RETAIL_DB;

create schema if not exists RETAIL_DB.STAGING;    -- données brutes (JSON)
create schema if not exists RETAIL_DB.ANALYTICS;  -- données transformées

-- ---------------------------------------------------------------------
-- 3. Rôle analyste en lecture seule
--    (SECURITYADMIN gère les rôles et les droits)
-- ---------------------------------------------------------------------
use role securityadmin;

create role if not exists ANALYST_ROLE;

-- Bonne pratique : rattacher tout nouveau rôle à la hiérarchie SYSADMIN
grant role ANALYST_ROLE to role SYSADMIN;

-- Droits d'accès ("pouvoir entrer")
grant usage on warehouse RETAIL_WH          to role ANALYST_ROLE;
grant usage on database  RETAIL_DB          to role ANALYST_ROLE;
grant usage on schema    RETAIL_DB.ANALYTICS to role ANALYST_ROLE;
-- Aucun droit sur RETAIL_DB.STAGING : l'analyste ne voit pas les données brutes

-- Lecture seule sur les tables et vues actuelles ET futures d'ANALYTICS
grant select on all tables    in schema RETAIL_DB.ANALYTICS to role ANALYST_ROLE;
grant select on future tables in schema RETAIL_DB.ANALYTICS to role ANALYST_ROLE;
grant select on all views     in schema RETAIL_DB.ANALYTICS to role ANALYST_ROLE;
grant select on future views  in schema RETAIL_DB.ANALYTICS to role ANALYST_ROLE;

-- Attribuer le rôle à un utilisateur pour pouvoir le tester
-- (nom entre guillemets car l'utilisateur a été créé en minuscules ;
--  remplacer par votre propre utilisateur : select current_user();)
grant role ANALYST_ROLE to user "adodosilvera5";
