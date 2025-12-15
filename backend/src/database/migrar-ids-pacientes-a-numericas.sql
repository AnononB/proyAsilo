-- ============================================
-- SCRIPT DE MIGRACIÓN: Convertir IDs UUID a numéricas
-- ⚠️ ADVERTENCIA: Este script modifica las IDs de los pacientes
-- ⚠️ Solo ejecutar si estás seguro de que quieres migrar todos los UUIDs a números
-- ⚠️ Asegúrate de hacer un BACKUP antes de ejecutar este script
-- ============================================

-- ============================================
-- PASO 1: Verificar estado actual
-- ============================================
PRINT '=== VERIFICANDO ESTADO ACTUAL ===';

DECLARE @uuidCount INT;
SELECT @uuidCount = COUNT(*)
FROM patients
WHERE id LIKE '%-%-%-%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

PRINT 'Pacientes con UUID encontrados: ' + CAST(@uuidCount AS NVARCHAR(10));

IF @uuidCount = 0
BEGIN
    PRINT 'No hay pacientes con UUID para migrar. El script terminará.';
    RETURN;
END

-- ============================================
-- PASO 2: Crear tabla temporal para mapeo de IDs
-- ============================================
PRINT '';
PRINT '=== CREANDO TABLA TEMPORAL DE MAPEO ===';

IF OBJECT_ID('tempdb..#id_mapping') IS NOT NULL
    DROP TABLE #id_mapping;

CREATE TABLE #id_mapping (
    old_id NVARCHAR(36),
    new_id NVARCHAR(36),
    orden INT IDENTITY(1,1)
);

-- Obtener el máximo número actual
DECLARE @maxNum INT;
SELECT @maxNum = MAX(CAST(id AS INT))
FROM patients
WHERE ISNUMERIC(id) = 1 AND id NOT LIKE '%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

IF @maxNum IS NULL
    SET @maxNum = 0;

PRINT 'Máximo número actual: ' + CAST(@maxNum AS NVARCHAR(10));

-- Insertar mapeo de IDs (UUID -> número secuencial)
INSERT INTO #id_mapping (old_id, new_id)
SELECT 
    id AS old_id,
    CAST(@maxNum + ROW_NUMBER() OVER (ORDER BY fecha_creacion, id) AS NVARCHAR(36)) AS new_id
FROM patients
WHERE id LIKE '%-%-%-%-%'
    AND (eliminado = 0 OR eliminado IS NULL)
ORDER BY fecha_creacion, id;

PRINT 'IDs preparadas para migración: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- ============================================
-- PASO 3: Deshabilitar constraints temporalmente
-- ============================================
PRINT '';
PRINT '=== DESHABILITANDO CONSTRAINTS ===';

-- Deshabilitar foreign keys que referencian patients.id
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql = @sql + 
    'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + 
    QUOTENAME(OBJECT_NAME(parent_object_id)) + 
    ' NOCHECK CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.foreign_keys
WHERE referenced_object_id = OBJECT_ID('patients');

IF LEN(@sql) > 0
BEGIN
    EXEC sp_executesql @sql;
    PRINT 'Constraints deshabilitadas';
END
ELSE
    PRINT 'No se encontraron constraints para deshabilitar';

-- ============================================
-- PASO 4: Actualizar referencias en tablas relacionadas
-- ============================================
PRINT '';
PRINT '=== ACTUALIZANDO REFERENCIAS EN TABLAS RELACIONADAS ===';

-- Actualizar contacts
UPDATE c
SET c.paciente_id = m.new_id
FROM contacts c
INNER JOIN #id_mapping m ON c.paciente_id = m.old_id;
PRINT 'Contacts actualizados: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Actualizar entry_requests
UPDATE e
SET e.paciente_id = m.new_id
FROM entry_requests e
INNER JOIN #id_mapping m ON e.paciente_id = m.old_id;
PRINT 'Entry_requests actualizados: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Actualizar patient_medications
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'patient_medications')
BEGIN
    UPDATE pm
    SET pm.paciente_id = m.new_id
    FROM patient_medications pm
    INNER JOIN #id_mapping m ON pm.paciente_id = m.old_id;
    PRINT 'Patient_medications actualizados: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));
END

-- Actualizar personal_objects
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'personal_objects')
BEGIN
    UPDATE po
    SET po.paciente_id = m.new_id
    FROM personal_objects po
    INNER JOIN #id_mapping m ON po.paciente_id = m.old_id;
    PRINT 'Personal_objects actualizados: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));
END

-- ============================================
-- PASO 5: Actualizar IDs en la tabla patients
-- ============================================
PRINT '';
PRINT '=== ACTUALIZANDO IDs EN TABLA PATIENTS ===';

UPDATE p
SET p.id = m.new_id
FROM patients p
INNER JOIN #id_mapping m ON p.id = m.old_id;

PRINT 'Patients actualizados: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- ============================================
-- PASO 6: Rehabilitar constraints
-- ============================================
PRINT '';
PRINT '=== REHABILITANDO CONSTRAINTS ===';

SET @sql = '';

SELECT @sql = @sql + 
    'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + 
    QUOTENAME(OBJECT_NAME(parent_object_id)) + 
    ' CHECK CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.foreign_keys
WHERE referenced_object_id = OBJECT_ID('patients');

IF LEN(@sql) > 0
BEGIN
    EXEC sp_executesql @sql;
    PRINT 'Constraints rehabilitadas';
END

-- ============================================
-- PASO 7: Verificar resultado
-- ============================================
PRINT '';
PRINT '=== VERIFICACIÓN FINAL ===';

DECLARE @numericCount INT;
SELECT @numericCount = COUNT(*)
FROM patients
WHERE ISNUMERIC(id) = 1 AND id NOT LIKE '%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

DECLARE @uuidCountAfter INT;
SELECT @uuidCountAfter = COUNT(*)
FROM patients
WHERE id LIKE '%-%-%-%-%'
    AND (eliminado = 0 OR eliminado IS NULL);

PRINT 'Pacientes con ID numérica: ' + CAST(@numericCount AS NVARCHAR(10));
PRINT 'Pacientes con ID UUID: ' + CAST(@uuidCountAfter AS NVARCHAR(10));

IF @uuidCountAfter = 0
    PRINT '✓ Migración completada exitosamente';
ELSE
    PRINT '⚠ Aún quedan pacientes con UUID';

-- Limpiar tabla temporal
DROP TABLE #id_mapping;

PRINT '';
PRINT '=== MIGRACIÓN FINALIZADA ===';
PRINT 'IMPORTANTE: Verifica que todo funcione correctamente antes de continuar usando el sistema.';
GO


