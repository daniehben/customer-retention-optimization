-- ============================================================
-- 00_setup.sql
-- Project: Customer Retention & Incentive Optimization
-- Purpose: Environment setup & reproducibility
-- Author: Danieh Ben Otman
-- ============================================================

-- -------------------------
-- 1. Schema setup
-- -------------------------

CREATE SCHEMA IF NOT EXISTS churn;
SET search_path TO churn;



-- -------------------------
-- 2. Safety & consistency
-- -------------------------

-- Avoid accidental writes outside schema
SET search_path TO churn, public;

-- Standardize date behavior
SET datestyle = 'ISO, MDY';

-- -------------------------
-- 3. Project metadata
-- -------------------------

COMMENT ON SCHEMA churn IS
'Customer churn & retention analysis schema.
SQL-first project focused on decision optimization and incentive ROI.';
