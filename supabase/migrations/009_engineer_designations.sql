-- ============================================================
-- EAM Platform - Migration 009
-- Adds: engineer designation options (machine_config rows with
--       config_type 'engineer_designation') for the engineer form's
--       Designation dropdown. Admins add more with "+ Add Another".
-- ============================================================

INSERT INTO public.machine_config (config_type, value, sort_order, is_active)
SELECT 'engineer_designation', d.value, d.sort_order, true
  FROM (VALUES
          ('Jr Sub. Assistant Engineer', 1),
          ('Jr Assistant Engineer',      2),
          ('Asst. Service Engineer',     3),
          ('Service In Charge',          4)
       ) AS d(value, sort_order)
 WHERE NOT EXISTS (
         SELECT 1 FROM public.machine_config c
          WHERE c.config_type = 'engineer_designation'
            AND lower(c.value) = lower(d.value)
       );

-- Keep designations engineers already have, after the defaults.
INSERT INTO public.machine_config (config_type, value, sort_order, is_active)
SELECT 'engineer_designation', e.designation, 100 + row_number() OVER (ORDER BY e.designation), true
  FROM (SELECT DISTINCT trim(designation) AS designation
          FROM public.engineers
         WHERE coalesce(trim(designation), '') <> '') e
 WHERE NOT EXISTS (
         SELECT 1 FROM public.machine_config c
          WHERE c.config_type = 'engineer_designation'
            AND lower(c.value) = lower(e.designation)
       );
