import { useEffect, useMemo, useState } from "react";
import {
  TextField,
  Button,
  Stack,
  Typography,
  Paper,
  Chip,
  Alert,
  MenuItem,
  Box,
  IconButton
} from "@mui/material";
import {
  Search as SearchIcon,
  Warning as WarningIcon,
  Delete as DeleteIcon,
  FileDownload as FileDownloadIcon
} from "@mui/icons-material";
import * as XLSX from 'xlsx';
import { AnimatePresence, motion } from "framer-motion";
import Page from "../components/Page";
import { Table } from "../components/Table";
import { api } from "../api/client";
import { Medication } from "../types";
import { useAuth } from "../contexts/AuthContext";

export default function MedsPage() {
  const { user } = useAuth();

  const [items, setItems] = useState<Medication[]>([]);
  const [filteredItems, setFilteredItems] = useState<Medication[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isExpired = useMemo(
    () => (date: string) => {
      const expiry = new Date(date);
      const now = new Date();
      // Resetear horas para comparar solo fechas
      expiry.setHours(0, 0, 0, 0);
      now.setHours(0, 0, 0, 0);
      return expiry <= now;
    },
    []
  );

  const isExpiringSoon = useMemo(
    () => (date: string) => {
      const expiry = new Date(date);
      const now = new Date();
      const threeMonthsFromNow = new Date(now);
      threeMonthsFromNow.setMonth(now.getMonth() + 3);
      return expiry >= now && expiry <= threeMonthsFromNow;
    },
    []
  );

  const getExpiryChip = (date: string) => {
    if (isExpired(date)) {
      return <Chip label="CADUCADO" color="error" size="small" icon={<WarningIcon />} />;
    }
    if (isExpiringSoon(date)) {
      return <Chip label="Por caducar" color="warning" size="small" icon={<WarningIcon />} />;
    }
    return <Chip label="Vigente" color="success" size="small" />;
  };

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const medications = await api.listMeds();
      setItems(medications);
      setFilteredItems(medications);
    } catch (error: any) {
      console.error("Error al cargar medicamentos:", error);
      const errorMessage = error?.message || "Error desconocido al cargar los medicamentos";
      setError(`Error al cargar los medicamentos: ${errorMessage}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) {
      setFilteredItems(items);
      return;
    }
    setFilteredItems(
      items.filter(m =>
        m.name.toLowerCase().includes(q) ||
        m.unit?.toLowerCase().includes(q) ||
        m.dosage?.toLowerCase().includes(q) ||
        m.barcode?.toLowerCase().includes(q)
      )
    );
  }, [items, searchQuery]);

  const expiredCount = items.filter(m => isExpired(m.expiresAt)).length;
  const expiringSoonCount = items.filter(m => !isExpired(m.expiresAt) && isExpiringSoon(m.expiresAt)).length;

  const handleDeleteMed = async (medId: string, medName: string) => {
    if (!window.confirm(`¿Estás seguro de que deseas eliminar el medicamento "${medName}"?`)) {
      return;
    }
    try {
      await api.deleteMed(medId);
      await load();
    } catch (error: any) {
      console.error("Error al eliminar medicamento:", error);
      const errorMessage = error?.message || "Error desconocido al eliminar el medicamento";
      alert(`Error al eliminar el medicamento: ${errorMessage}`);
    }
  };

  const handleExportToExcel = () => {
    try {
      // Preparar los datos para Excel
      const excelData = filteredItems.map(med => {
        const expiryDate = med.expiresAt ? new Date(med.expiresAt) : null;
        let estado = "Vigente";
        if (expiryDate) {
          const now = new Date();
          now.setHours(0, 0, 0, 0);
          expiryDate.setHours(0, 0, 0, 0);
          if (expiryDate <= now) {
            estado = "CADUCADO";
          } else {
            const threeMonthsFromNow = new Date(now);
            threeMonthsFromNow.setMonth(now.getMonth() + 3);
            if (expiryDate >= now && expiryDate <= threeMonthsFromNow) {
              estado = "Por caducar";
            }
          }
        }

        return {
          "Medicamento": med.name,
          "Cantidad": med.qty,
          "Unidad": med.unit || "-",
          "Dosis": med.dosage || "-",
          "Fecha de Caducidad": med.expiresAt ? new Date(med.expiresAt).toLocaleDateString() : "-",
          "Estado": estado,
          "Código de Barras": med.barcode || "-",
          "Fecha de Creación": med.createdAt ? new Date(med.createdAt).toLocaleDateString() : "-",
          "Creado por": med.createdByName || "-"
        };
      });

      // Crear el libro de trabajo
      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.json_to_sheet(excelData);

      // Ajustar el ancho de las columnas
      const colWidths = [
        { wch: 30 }, // Medicamento
        { wch: 12 }, // Cantidad
        { wch: 15 }, // Unidad
        { wch: 15 }, // Dosis
        { wch: 18 }, // Fecha de Caducidad
        { wch: 15 }, // Estado
        { wch: 20 }, // Código de Barras
        { wch: 18 }, // Fecha de Creación
        { wch: 20 }  // Creado por
      ];
      ws['!cols'] = colWidths;

      // Agregar la hoja al libro
      XLSX.utils.book_append_sheet(wb, ws, "Stock de Medicamentos");

      // Generar el nombre del archivo con fecha
      const fecha = new Date().toISOString().split('T')[0];
      const fileName = `Stock_Medicamentos_${fecha}.xlsx`;

      // Descargar el archivo
      XLSX.writeFile(wb, fileName);
      
      alert(`Reporte exportado correctamente: ${fileName}`);
    } catch (error) {
      console.error("Error al exportar a Excel:", error);
      alert("Error al exportar el reporte a Excel");
    }
  };

  return (
    <Page>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
        <Typography variant="h5" fontWeight={700}>Medicamentos</Typography>
        <Button
          variant="outlined"
          startIcon={<FileDownloadIcon />}
          onClick={handleExportToExcel}
          disabled={loading || filteredItems.length === 0}
        >
          Exportar a Excel
        </Button>
      </Stack>
      
      <Alert severity="info" sx={{ mb: 2 }}>
        Para agregar nuevos medicamentos, ve al apartado de <strong>Entradas y Salidas</strong> y selecciona "Entrada" al crear un nuevo registro.
      </Alert>

      {expiredCount > 0 && (
        <Alert severity="error" icon={<WarningIcon />} sx={{ mb: 2 }}>
          <Typography variant="body2" fontWeight={600}>
            ¡Atención! Hay {expiredCount} medicamento(s) CADUCADO(S)
          </Typography>
        </Alert>
      )}

      {expiringSoonCount > 0 && (
        <Alert severity="warning" icon={<WarningIcon />} sx={{ mb: 2 }}>
          <Typography variant="body2" fontWeight={600}>
            Hay {expiringSoonCount} medicamento(s) por caducar en los próximos 3 meses
          </Typography>
        </Alert>
      )}

      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>Buscar medicamento</Typography>
        <TextField
          placeholder="Buscar por nombre, unidad, dosis o código de barras..."
          size="small"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          fullWidth
          InputProps={{
            startAdornment: <SearchIcon sx={{ mr: 1, color: "text.secondary" }} />
          }}
        />
      </Paper>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Typography variant="body2" color="text.secondary" mb={1}>
        {loading ? "Cargando..." : `Mostrando ${filteredItems.length} de ${items.length} medicamentos`}
      </Typography>

      <Table headers={user?.role === "admin" ? ["Medicamento", "Cantidad", "Unidad", "Dosis", "Caducidad", "Estado", "Código", "Acciones"] : ["Medicamento", "Cantidad", "Unidad", "Dosis", "Caducidad", "Estado", "Código"]}>
        <AnimatePresence initial={false}>
          {filteredItems.map(med => (
            <motion.tr
              key={med.id}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.25 }}
            >
              <td style={{ padding: 8, fontWeight: 600 }}>{med.name}</td>
              <td style={{ padding: 8 }}>{med.qty}</td>
              <td style={{ padding: 8 }}>{med.unit || "-"}</td>
              <td style={{ padding: 8, fontSize: 12 }}>{med.dosage || "-"}</td>
              <td style={{ padding: 8, fontSize: 12 }}>
                {new Date(med.expiresAt).toLocaleDateString()}
              </td>
              <td style={{ padding: 8 }}>{getExpiryChip(med.expiresAt)}</td>
              <td style={{ padding: 8, fontFamily: "monospace", fontSize: 12 }}>
                {med.barcode || "-"}
              </td>
              {user?.role === "admin" && (
                <td style={{ padding: 8 }}>
                  <IconButton
                    size="small"
                    color="error"
                    onClick={() => handleDeleteMed(med.id, med.name)}
                    title="Eliminar medicamento"
                  >
                    <DeleteIcon fontSize="small" />
                  </IconButton>
                </td>
              )}
            </motion.tr>
          ))}
        </AnimatePresence>
      </Table>

      {!loading && filteredItems.length === 0 && (
        <Alert severity="info" sx={{ mt: 2 }}>
          No se encontraron medicamentos.
        </Alert>
      )}
    </Page>
  );
}
