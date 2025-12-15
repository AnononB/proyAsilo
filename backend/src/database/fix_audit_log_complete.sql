-- Script completo para crear audit_log y configurar soft delete
-- Este script es seguro de ejecutar múltiples veces (idempotente)
-- Ejecuta TODO en el orden correcto

USE AsiloDB
GO

PRINT '========================================';
PRINT 'INICIANDO CONFIGURACIÓN COMPLETA';
PRINT '========================================';
PRINT '';

-- ============================================
-- 1. CREAR TABLA audit_log SI NO EXISTE
-- ============================================
PRINT '1. Verificando tabla audit_log...';
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[audit_log]') AND type in (N'U'))
BEGIN
    PRINT '   Creando tabla audit_log...';
    
    CREATE TABLE audit_log (
        id NVARCHAR(36) PRIMARY KEY DEFAULT NEWID(),
        tabla_afectada NVARCHAR(100) NOT NULL,
        registro_id NVARCHAR(36) NOT NULL,
        accion NVARCHAR(50) NOT NULL,
        datos_anteriores NVARCHAR(MAX) NULL,
        usuario_id NVARCHAR(36) NULL,
        usuario_nombre NVARCHAR(255) NULL,
        fecha_accion DATETIME2 DEFAULT GETDATE(),
        ip_address NVARCHAR(50) NULL,
        observaciones NVARCHAR(MAX) NULL,
        CONSTRAINT FK_audit_log_usuario FOREIGN KEY (usuario_id) REFERENCES users(id)
    );
    
    CREATE INDEX idx_audit_log_tabla ON audit_log(tabla_afectada);
    CREATE INDEX idx_audit_log_registro ON audit_log(registro_id);
    CREATE INDEX idx_audit_log_usuario ON audit_log(usuario_id);
    CREATE INDEX idx_audit_log_fecha ON audit_log(fecha_accion);
    CREATE INDEX idx_audit_log_accion ON audit_log(accion);
    
    PRINT '   ✓ Tabla audit_log creada correctamente.';
END
ELSE
BEGIN
    PRINT '   ✓ Tabla audit_log ya existe.';
END
GO

-- ============================================
-- 2. AGREGAR CAMPOS PARA SOFT DELETE EN PATIENTS
-- ============================================
PRINT '';
PRINT '2. Verificando columnas de soft delete en patients...';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'patients' AND COLUMN_NAME = 'eliminado')
BEGIN
    PRINT '   Agregando columna eliminado...';
    ALTER TABLE patients ADD eliminado BIT NOT NULL DEFAULT 0;
    PRINT '   ✓ Columna eliminado agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna eliminado ya existe.';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'patients' AND COLUMN_NAME = 'fecha_eliminacion')
BEGIN
    PRINT '   Agregando columna fecha_eliminacion...';
    ALTER TABLE patients ADD fecha_eliminacion DATETIME2 NULL;
    PRINT '   ✓ Columna fecha_eliminacion agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna fecha_eliminacion ya existe.';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'patients' AND COLUMN_NAME = 'eliminado_por')
BEGIN
    PRINT '   Agregando columna eliminado_por...';
    ALTER TABLE patients ADD eliminado_por NVARCHAR(36) NULL;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_patients_eliminado_por')
    BEGIN
        ALTER TABLE patients ADD CONSTRAINT FK_patients_eliminado_por FOREIGN KEY (eliminado_por) REFERENCES users(id);
    END
    
    PRINT '   ✓ Columna eliminado_por agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna eliminado_por ya existe.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_patients_eliminado' AND object_id = OBJECT_ID('patients'))
BEGIN
    PRINT '   Creando índice idx_patients_eliminado...';
    CREATE INDEX idx_patients_eliminado ON patients(eliminado, fecha_eliminacion);
    PRINT '   ✓ Índice creado.';
END
ELSE
BEGIN
    PRINT '   ✓ Índice idx_patients_eliminado ya existe.';
END
GO

-- ============================================
-- 3. AGREGAR CAMPOS PARA SOFT DELETE EN USERS
-- ============================================
PRINT '';
PRINT '3. Verificando columnas de soft delete en users...';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'eliminado')
BEGIN
    PRINT '   Agregando columna eliminado...';
    ALTER TABLE users ADD eliminado BIT NOT NULL DEFAULT 0;
    PRINT '   ✓ Columna eliminado agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna eliminado ya existe.';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'fecha_eliminacion')
BEGIN
    PRINT '   Agregando columna fecha_eliminacion...';
    ALTER TABLE users ADD fecha_eliminacion DATETIME2 NULL;
    PRINT '   ✓ Columna fecha_eliminacion agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna fecha_eliminacion ya existe.';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'eliminado_por')
BEGIN
    PRINT '   Agregando columna eliminado_por...';
    ALTER TABLE users ADD eliminado_por NVARCHAR(36) NULL;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_users_eliminado_por')
    BEGIN
        ALTER TABLE users ADD CONSTRAINT FK_users_eliminado_por FOREIGN KEY (eliminado_por) REFERENCES users(id);
    END
    
    PRINT '   ✓ Columna eliminado_por agregada.';
END
ELSE
BEGIN
    PRINT '   ✓ Columna eliminado_por ya existe.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_users_eliminado' AND object_id = OBJECT_ID('users'))
BEGIN
    PRINT '   Creando índice idx_users_eliminado...';
    CREATE INDEX idx_users_eliminado ON users(eliminado, fecha_eliminacion);
    PRINT '   ✓ Índice creado.';
END
ELSE
BEGIN
    PRINT '   ✓ Índice idx_users_eliminado ya existe.';
END
GO

-- ============================================
-- 4. CREAR/ACTUALIZAR TRIGGER DE PATIENTS
-- ============================================
PRINT '';
PRINT '4. Creando/actualizando trigger TRG_patients_before_delete...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TRG_patients_before_delete')
BEGIN
    DROP TRIGGER TRG_patients_before_delete;
    PRINT '   Trigger anterior eliminado.';
END
GO

CREATE TRIGGER TRG_patients_before_delete
ON patients
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @userId NVARCHAR(36) = NULL;
    DECLARE @userName NVARCHAR(255) = NULL;
    
    -- Registrar en audit_log solo si la tabla existe
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'audit_log')
    BEGIN
        BEGIN TRY
            INSERT INTO audit_log (
                tabla_afectada,
                registro_id,
                accion,
                datos_anteriores,
                usuario_id,
                usuario_nombre,
                fecha_accion,
                observaciones
            )
            SELECT 
                'patients',
                d.id,
                'SOFT_DELETE',
                (
                    SELECT 
                        d.id as id,
                        d.nombre as nombre,
                        d.fecha_nacimiento as fecha_nacimiento,
                        d.edad as edad,
                        d.curp as curp,
                        d.rfc as rfc,
                        d.fecha_ingreso as fecha_ingreso,
                        d.estado as estado,
                        d.doctor_id as doctor_id,
                        d.enfermero_id as enfermero_id,
                        d.fecha_creacion as fecha_creacion
                    FOR JSON PATH
                ),
                @userId,
                @userName,
                GETDATE(),
                'Paciente marcado como eliminado (soft delete)'
            FROM deleted d;
        END TRY
        BEGIN CATCH
            PRINT 'Advertencia: No se pudo registrar en audit_log: ' + ERROR_MESSAGE();
        END CATCH
    END
    
    -- SOFT DELETE: Marcar como eliminado en lugar de borrar
    UPDATE p
    SET 
        eliminado = 1,
        fecha_eliminacion = GETDATE(),
        eliminado_por = @userId,
        estado = 'baja'
    FROM patients p
    INNER JOIN deleted d ON p.id = d.id
    WHERE p.eliminado = 0 OR p.eliminado IS NULL;
END;
GO

PRINT '   ✓ Trigger TRG_patients_before_delete creado.';
GO

-- ============================================
-- 5. CREAR/ACTUALIZAR TRIGGER DE USERS
-- ============================================
PRINT '';
PRINT '5. Creando/actualizando trigger TRG_users_before_delete...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TRG_users_before_delete')
BEGIN
    DROP TRIGGER TRG_users_before_delete;
    PRINT '   Trigger anterior eliminado.';
END
GO

CREATE TRIGGER TRG_users_before_delete
ON users
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @userId NVARCHAR(36) = NULL;
    
    -- Verificar si el usuario tiene pacientes asignados
    IF EXISTS (
        SELECT 1 
        FROM patients 
        WHERE (doctor_id IN (SELECT id FROM deleted) OR enfermero_id IN (SELECT id FROM deleted))
          AND (eliminado = 0 OR eliminado IS NULL)
    )
    BEGIN
        RAISERROR('No se puede eliminar el usuario porque tiene pacientes asignados. Primero reasigna los pacientes.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    
    -- Registrar en audit_log solo si la tabla existe
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'audit_log')
    BEGIN
        BEGIN TRY
            INSERT INTO audit_log (
                tabla_afectada,
                registro_id,
                accion,
                datos_anteriores,
                usuario_id,
                fecha_accion,
                observaciones
            )
            SELECT 
                'users',
                d.id,
                'SOFT_DELETE',
                (
                    SELECT 
                        d.id as id,
                        d.nombre as nombre,
                        d.rol as rol,
                        d.email as email,
                        d.fecha_creacion as fecha_creacion
                    FOR JSON PATH
                ),
                @userId,
                GETDATE(),
                'Usuario marcado como eliminado (soft delete)'
            FROM deleted d;
        END TRY
        BEGIN CATCH
            PRINT 'Advertencia: No se pudo registrar en audit_log: ' + ERROR_MESSAGE();
        END CATCH
    END
    
    -- SOFT DELETE: Marcar como eliminado
    UPDATE u
    SET 
        eliminado = 1,
        fecha_eliminacion = GETDATE(),
        eliminado_por = @userId
    FROM users u
    INNER JOIN deleted d ON u.id = d.id
    WHERE u.eliminado = 0 OR u.eliminado IS NULL;
END;
GO

PRINT '   ✓ Trigger TRG_users_before_delete creado.';
GO

-- ============================================
-- RESUMEN
-- ============================================
PRINT '';
PRINT '========================================';
PRINT 'CONFIGURACIÓN COMPLETA FINALIZADA';
PRINT '========================================';
PRINT '';
PRINT 'Resumen de cambios:';
PRINT '  ✓ Tabla audit_log creada/verificada';
PRINT '  ✓ Columnas de soft delete en patients creadas/verificadas';
PRINT '  ✓ Columnas de soft delete en users creadas/verificadas';
PRINT '  ✓ Triggers actualizados';
PRINT '';
PRINT 'El sistema ahora puede eliminar pacientes sin errores.';
PRINT '';

