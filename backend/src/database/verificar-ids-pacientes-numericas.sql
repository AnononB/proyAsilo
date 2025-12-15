-- Script para verificar y diagnosticar el estado de las IDs de pacientes
-- Este script te ayudará a entender qué está pasando con las IDs en tu base de datos remota

-- ============================================
-- 1. VERIFICAR TIPO DE DATOS DE LA COLUMNA ID
-- ============================================
PRINT '=== VERIFICACIÓN DE TIPO DE DATOS ===';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'patients' AND COLUMN_NAME = 'id';
GO

-- ============================================
-- 2. CONTAR PACIENTES CON IDs NUMÉRICAS vs UUIDs
-- ============================================
PRINT '';
PRINT '=== ANÁLISIS DE IDs DE PACIENTES ===';

-- Contar pacientes con IDs numéricas (solo números)
SELECT 
    'Pacientes con ID numérica' AS Tipo,
    COUNT(*) AS Cantidad
FROM patients
WHERE ISNUMERIC(id) = 1 AND id NOT LIKE '%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

-- Contar pacientes con IDs UUID (formato con guiones)
SELECT 
    'Pacientes con ID UUID' AS Tipo,
    COUNT(*) AS Cantidad
FROM patients
WHERE id LIKE '%-%-%-%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

-- Mostrar algunos ejemplos de cada tipo
PRINT '';
PRINT '=== EJEMPLOS DE IDs NUMÉRICAS ===';
SELECT TOP 10
    id,
    nombre,
    fecha_creacion
FROM patients
WHERE ISNUMERIC(id) = 1 AND id NOT LIKE '%-%'
    AND (eliminado = 0 OR eliminado IS NULL)
ORDER BY CAST(id AS INT) DESC;

PRINT '';
PRINT '=== EJEMPLOS DE IDs UUID ===';
SELECT TOP 10
    id,
    nombre,
    fecha_creacion
FROM patients
WHERE id LIKE '%-%-%-%-%'
    AND (eliminado = 0 OR eliminado IS NULL)
ORDER BY fecha_creacion DESC;

-- ============================================
-- 3. ENCONTRAR EL MÁXIMO NÚMERO ACTUAL
-- ============================================
PRINT '';
PRINT '=== PRÓXIMO NÚMERO DISPONIBLE ===';
DECLARE @maxNum INT;
SELECT @maxNum = MAX(CAST(id AS INT))
FROM patients
WHERE ISNUMERIC(id) = 1 AND id NOT LIKE '%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

IF @maxNum IS NULL
    SET @maxNum = 0;

PRINT 'Máximo número encontrado: ' + CAST(@maxNum AS NVARCHAR(10));
PRINT 'Próximo número disponible: ' + CAST(@maxNum + 1 AS NVARCHAR(10));
GO

-- ============================================
-- 4. VERIFICAR SI HAY CONFLICTOS POTENCIALES
-- ============================================
PRINT '';
PRINT '=== VERIFICACIÓN DE CONFLICTOS ===';

-- Verificar si hay IDs duplicadas
SELECT 
    id,
    COUNT(*) AS Cantidad
FROM patients
WHERE (eliminado = 0 OR eliminado IS NULL)
GROUP BY id
HAVING COUNT(*) > 1;

IF @@ROWCOUNT = 0
    PRINT '✓ No se encontraron IDs duplicadas';
ELSE
    PRINT '⚠ ADVERTENCIA: Se encontraron IDs duplicadas';

GO


