-- ============================================================
-- EAM Platform - Migration 013
-- Adds: accountant value to app_role
--
-- Accountant = viewer + purchase bills (add / edit). See 014.
--
-- Run this on its own before 014: a new enum value can't be
-- used in the same transaction that adds it.
-- ============================================================

ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'accountant';
