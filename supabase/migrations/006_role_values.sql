-- ============================================================
-- EAM Platform - Migration 006
-- Adds: data_entry and super_admin values to app_role
--
-- Roles (lowest → highest):
--   user        Viewer: clients + basic machine info + warranty
--   data_entry  Data entry operator: viewer + submits new data
--   admin       Admin: data entry + approvals + creates users
--   super_admin Super admin: everything
--
-- Run this on its own before 007: a new enum value can't be
-- used in the same transaction that adds it.
-- ============================================================

ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'data_entry';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'super_admin';
