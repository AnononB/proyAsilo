-- ============================================
-- Script para agregar columna dosis_sugerida a entrada_items
-- ============================================
-- Este script es idempotente: se puede ejecutar múltiples veces sin causar errores

PRINT '========================================';
PRINT 'AGREGANDO COLUMNA dosis_sugerida A entrada_items';
PRINT '========================================';
PRINT '';

-- Verificar si la columna dosis_sugerida existe
IF NOT EXISTS (
    SELECT * 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'entrada_items' 
      AND COLUMN_NAME = 'dosis_sugerida'
)
BEGIN
    PRINT 'Columna dosis_sugerida no existe. Agregándola...';
    
    ALTER TABLE entrada_items 
    ADD dosis_sugerida NVARCHAR(255) NULL;
    
    PRINT '✓ Columna dosis_sugerida agregada correctamente.';
END
ELSE
BEGIN
    PRINT '✓ Columna dosis_sugerida ya existe. No se realizaron cambios.';
END
GO

PRINT '';
PRINT '========================================';
PRINT 'SCRIPT COMPLETADO';
PRINT '========================================';
PRINT 'La columna dosis_sugerida está disponible en entrada_items.';
PRINT 'Ahora puedes guardar la dosis sugerida al crear entradas.';
PRINT '';

