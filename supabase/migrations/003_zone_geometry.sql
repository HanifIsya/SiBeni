-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) — PT Consnet Mining
-- Migration 003: Site geometry lives in the database
-- ==============================================================================
-- Rationale
--   Zone footprints were previously hardcoded inside the Flutter client, which
--   meant relocating or reshaping a site required an app release. This
--   migration moves that geometry into `mining_zones.polygon_coordinates` so
--   the map is fully data-driven.
--
--   JSONB contract consumed by ZoneGeometry (frontend/lib/core/zone_model.dart):
--     {
--       "center":   [lat, lng],     -- canonical marker position
--       "polygon":  [[lat, lng], …], -- closed ring, rendered as a risk-coloured area
--       "assembly": [lat, lng]      -- evacuation assembly point for this zone
--     }
--
--   All coordinates are WGS84 (EPSG:4326), which is what every slippy tile
--   provider expects.
-- ==============================================================================

-- Warehouse & explosives magazine
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1412000,115.3435000],"polygon":[[-2.1412000,115.3415133],[-2.1386455,115.3428861],[-2.1396212,115.3451072],[-2.1427788,115.3451072],[-2.1437545,115.3428861]],"assembly":[-2.1382566,115.3455624]}'::jsonb
WHERE code = 'ZONE_WAREHOUSE';

-- Site office, clinic & mess
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1425000,115.3452000],"polygon":[[-2.1425000,115.3438246],[-2.1407315,115.3447750],[-2.1414070,115.3463127],[-2.1435930,115.3463127],[-2.1442685,115.3447750]],"assembly":[-2.1428687,115.3441863]}'::jsonb
WHERE code = 'ZONE_SUPPORT';

-- Heavy equipment workshop
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1435000,115.3468000],"polygon":[[-2.1435000,115.3451190],[-2.1413385,115.3462805],[-2.1421641,115.3481600],[-2.1448359,115.3481600],[-2.1456615,115.3462805]],"assembly":[-2.1436174,115.3481433]}'::jsonb
WHERE code = 'ZONE_WORKSHOP';

-- Active pit
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1458291,115.3489124],"polygon":[[-2.1458291,115.3449391],[-2.1407201,115.3476846],[-2.1426716,115.3521269],[-2.1489866,115.3521269],[-2.1509381,115.3476846]],"assembly":[-2.1469044,115.3459558]}'::jsonb
WHERE code = 'ZONE_PIT';

-- Haul road corridor
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1492000,115.3524000],"polygon":[[-2.1492000,115.3494964],[-2.1454665,115.3515027],[-2.1468926,115.3547491],[-2.1515074,115.3547491],[-2.1529335,115.3515027]],"assembly":[-2.1526407,115.3552891]}'::jsonb
WHERE code = 'ZONE_HAUL_ROAD';

-- Stockpile / ROM pad
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1528000,115.3561000],"polygon":[[-2.1528000,115.3535020],[-2.1494595,115.3552972],[-2.1507355,115.3582018],[-2.1548645,115.3582018],[-2.1561405,115.3552972]],"assembly":[-2.1515424,115.3539202]}'::jsonb
WHERE code = 'ZONE_STOCKPILE';

-- Crusher plant
UPDATE mining_zones SET polygon_coordinates = '{"center":[-2.1550000,115.3585000],"polygon":[[-2.1550000,115.3562077],[-2.1520525,115.3577916],[-2.1531784,115.3603545],[-2.1568216,115.3603545],[-2.1579475,115.3577916]],"assembly":[-2.1531429,115.3591764]}'::jsonb
WHERE code = 'ZONE_PROCESSING';

-- Safety-net trigger: warn loudly if a new zone is ever added without geometry.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM mining_zones WHERE polygon_coordinates IS NULL) THEN
        RAISE WARNING 'mining_zones contains rows without polygon_coordinates';
    END IF;
END $$;