// =============================================================================
// LucasCoreUpdates.cs - brings a library made with an earlier lucasCore up to this version when SyncroSim opens it
// =============================================================================
// package.xml names this class as the update provider. SyncroSim records each package's schema version (major.minor) in the
// library (core_Package.SchemaVersion) and runs every [Update(v)] method with v above it, in order, inside one transaction, when the
// library is opened with a newer package. SyncroSim makes the tables of new datasheets itself; a new column of an existing table,
// a project definition or a stock-flow row the package's defaults gained is the update's to add.
// Every step checks first, so a library that already has a change (one brought up to date by tools/sync-library.R, or made by a
// development copy of the package between releases) is left as it is. tools/sync-library.R stays for the steps written in R (the
// Carbon Assumptions scenario, legacy non-forest rows).
// C# 5 (the .NET Framework compiler of tools/build_ui.ps1): no string interpolation.
// =============================================================================
using System;
using System.Data;
using System.Globalization;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class LucasCoreUpdates : DotNetUpdateProvider
    {
        // ---- 1.1 (lucasCore 1.1.0): was updates/update-1.1000.xml under SyncroSim's XML update provider, moved here when the package
        // took this class as its provider (a package names one) ---------------------------------------------------------------------
        [Update(1.1, "lucasCore 1.1: Study Area page - the single-row Study Area options sheet holding the kind of unit chosen")]
        public void Update_1_100(DataStore store)
        {
            if (!store.TableExists("lucasCore_StudyAreaOptions"))
                store.ExecuteNonQuery("CREATE TABLE lucasCore_StudyAreaOptions(StudyAreaOptionsId INTEGER PRIMARY KEY, ScenarioId INTEGER, SourceId INTEGER)");
        }

        // ---- 1.2 (lucasCore 1.2.0, 2026-11): everything the package gained since 1.1 ------------------------------------------
        [Update(1.2, "lucasCore 1.2: Data Sources folders for RAP NPP, the Cropland Data Layer and the tidal marsh NPP map; Build Options site productivity choices for grass and shrub, cropland and tidal marsh; Projection Climate CO2 settings; the agriculture stock, flows and flow groups; the Flow Multiplier Types of CO2, the non-forest productivity maps, Crop Yield and Crop Mix")]
        public void Update_1_200(DataStore store)
        {
            // new columns of existing datasheets (the tables of new datasheets SyncroSim makes itself)
            AddColumn(store, "lucasCore_DataSource", "RapNppFolder", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "CdlFolder", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "TidalMarshNppFolder", "TEXT");
            AddColumn(store, "lucasCore_BuildOptions", "GrassShrubProductivity", "INTEGER");
            AddColumn(store, "lucasCore_BuildOptions", "CropProductivity", "INTEGER");
            AddColumn(store, "lucasCore_BuildOptions", "TidalMarshProductivity", "INTEGER");
            AddColumn(store, "lucasCore_ProjectionClimate", "Co2Series", "INTEGER");
            AddColumn(store, "lucasCore_ProjectionClimate", "Co2Ceiling", "DOUBLE");
            AddColumn(store, "lucasCore_ProjectionClimate", "Co2Reference", "DOUBLE");

            // project definitions (defaults/stsim/*.csv): agriculture (to-do 39 step 6) and the new Flow Multiplier Types. ST-Sim keeps
            // a "<name> [Type]" group for every stock and flow type (IsAuto); it adds them when types are saved through ST-Sim, not when
            // a row is written here, so they are written too.
            const string sector = "Carbon removed from cropland and pasture by crop harvest and hay and grazing removal";
            AddNamed(store, "stsim_StockType", "StockTypeId", "Agriculture Sector", "Description", sector, false);
            AddNamed(store, "stsim_StockGroup", "StockGroupId", "Agriculture Sector [Type]", null, null, true);
            string[] flows = { "Net Growth Agriculture: Atmosphere -> Fine Roots", "Net Growth Agriculture: Atmosphere -> Foliage", "Harvest: Foliage -> Agriculture Sector" };
            foreach (string f in flows)
            {
                AddNamed(store, "stsim_FlowType", "FlowTypeId", f, null, null, false);
                AddNamed(store, "stsim_FlowGroup", "FlowGroupId", f + " [Type]", null, null, true);
            }
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "Net Growth Agriculture: Total", "Description", "Net uptake of carbon by cropland and pasture (NASS county yields)", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "Harvest: Agriculture", "Description", sector, false);
            string[] multipliers = { "CO2", "Grass and Shrub Productivity", "Crop Yield", "Cropland Productivity", "Crop Harvest", "Crop Mix", "Tidal Marsh Productivity" };
            foreach (string m in multipliers) AddNamed(store, "stsim_FlowMultiplierType", "FlowMultiplierTypeId", m, null, null, false);

            // stock-flow rows (defaults/stockflow/*.csv) for the scenarios that hold their own stock-flow definitions: a library made by
            // tools/new-library.R has a Stock-Flow Definitions scenario; one made in Studio has none (stage 0 writes the package's rows
            // into each Build) and gets nothing here. Results keep the rows they ran with.
            string[] growth = { "Net Biome Productivity|1", "Net Biome Productivity (CO2e)|3.67", "Net Ecosystem Productivity|1", "Net Ecosystem Productivity (CO2e)|3.67",
                                "Net Growth Agriculture: Total|1", "Net Growth: Total|1", "Net Growth: Total (CO2e)|3.67", "Net Primary Productivity|1", "Net Primary Productivity (CO2e)|3.67" };
            for (int i = 0; i < 2; i++)
                foreach (string g in growth) { string[] p = g.Split('|'); AddMembership(store, flows[i], p[0], p[1]); }
            AddMembership(store, flows[2], "Harvest: Agriculture", "1");
            AddMembership(store, flows[2], "Net Biome Productivity", "-1");
            AddMembership(store, flows[2], "Net Biome Productivity (CO2e)", "-3.67");
            AddFlowOrder(store, flows[0], 1); AddFlowOrder(store, flows[1], 1); AddFlowOrder(store, flows[2], 2);
            AddScenarioRow(store, "stsim_FlowPathwayDiagram", "FlowPathwayDiagramId", "StockTypeId", "stsim_StockType", "StockTypeId", "Agriculture Sector", "Location", "'A3'");
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", flows[0] + " [Type]", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", flows[1] + " [Type]", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "Net Growth Agriculture: Total", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", flows[2] + " [Type]", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "Harvest: Agriculture", true);
            AddFilter(store, "stsim_OutputFilterStocks", "OutputFilterStocksId", "StockGroupId", "stsim_StockGroup", "Agriculture Sector [Type]", false);
        }

        // ---- helpers ------------------------------------------------------------------------------------------------------------
        private static string Q(string s) { return "'" + s.Replace("'", "''") + "'"; }

        private static bool HasColumn(DataStore store, string table, string column)
        {
            DataTable t = store.CreateDataTableFromQuery("PRAGMA table_info(" + Q(table) + ")", "cols");
            foreach (DataRow r in t.Rows) if (string.Equals(Convert.ToString(r["name"], CultureInfo.InvariantCulture), column, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        private static void AddColumn(DataStore store, string table, string column, string type)
        {
            if (store.TableExists(table) && !HasColumn(store, table, column))
                store.ExecuteNonQuery("ALTER TABLE " + table + " ADD COLUMN " + column + " " + type);
        }

        // a new id from the library's id counter, as SyncroSim's own rows get theirs
        private static long NewId(DataStore store)
        {
            store.ExecuteNonQuery("INSERT INTO core_Sequence (Value) VALUES (0)");
            long id = Convert.ToInt64(store.ExecuteScalar("SELECT MAX(Id) FROM core_Sequence"), CultureInfo.InvariantCulture);
            store.ExecuteNonQuery("DELETE FROM core_Sequence WHERE Id < " + id.ToString(CultureInfo.InvariantCulture));
            return id;
        }

        private static DataTable Rows(DataStore store, string sql) { return store.CreateDataTableFromQuery(sql, "rows"); }
        private static string Id(object v) { return Convert.ToInt64(v, CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture); }

        // a project definition (Name, an optional extra column, IsAuto for ST-Sim's own type groups) in every project that lacks it
        private static void AddNamed(DataStore store, string table, string idCol, string name, string extraCol, string extraVal, bool isAuto)
        {
            if (!store.TableExists(table)) return;
            DataTable p = Rows(store, "SELECT ProjectId FROM core_Project WHERE ProjectId NOT IN (SELECT ProjectId FROM " + table + " WHERE Name = " + Q(name) + ")");
            foreach (DataRow r in p.Rows)
            {
                string cols = idCol + ", ProjectId, Name", vals = NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + Id(r["ProjectId"]) + ", " + Q(name);
                if (extraCol != null) { cols += ", " + extraCol; vals += ", " + Q(extraVal); }
                if (isAuto) { cols += ", IsAuto"; vals += ", -1"; }
                store.ExecuteNonQuery("INSERT INTO " + table + " (" + cols + ") VALUES (" + vals + ")");
            }
        }

        // the non-result scenarios that hold rows of a scenario sheet (their own stock-flow definitions), with their project
        private static DataTable Holders(DataStore store, string table)
        {
            return Rows(store, "SELECT s.ScenarioId, s.ProjectId FROM core_Scenario s WHERE s.ScenarioId NOT IN (SELECT ResultId FROM core_ScenarioResult)" +
                               " AND EXISTS (SELECT 1 FROM " + table + " x WHERE x.ScenarioId = s.ScenarioId)");
        }

        private static string IdOf(DataStore store, string table, string idCol, string project, string name)
        {
            object v = store.ExecuteScalar("SELECT " + idCol + " FROM " + table + " WHERE ProjectId = " + project + " AND Name = " + Q(name));
            return (v == null || v is DBNull) ? null : Id(v);
        }

        private static void AddMembership(DataStore store, string flowType, string flowGroup, string value)
        {
            const string t = "stsim_FlowTypeGroupMembership";
            if (!store.TableExists(t)) return;
            foreach (DataRow s in Holders(store, t).Rows)
            {
                string sc = Id(s["ScenarioId"]), pr = Id(s["ProjectId"]);
                string ft = IdOf(store, "stsim_FlowType", "FlowTypeId", pr, flowType), fg = IdOf(store, "stsim_FlowGroup", "FlowGroupId", pr, flowGroup);
                if (ft == null || fg == null) continue;
                if (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM " + t + " WHERE ScenarioId = " + sc + " AND FlowTypeId = " + ft + " AND FlowGroupId = " + fg), CultureInfo.InvariantCulture) > 0) continue;
                store.ExecuteNonQuery("INSERT INTO " + t + " (FlowTypeGroupMembershipId, ScenarioId, FlowTypeId, FlowGroupId, Value) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + sc + ", " + ft + ", " + fg + ", " + value + ")");
            }
        }

        private static void AddFlowOrder(DataStore store, string flowType, int order)
        {
            AddScenarioRow(store, "stsim_FlowOrder", "FlowOrderId", "FlowTypeId", "stsim_FlowType", "FlowTypeId", flowType, "\"Order\"", order.ToString(CultureInfo.InvariantCulture));
        }

        private static void AddFilter(DataStore store, string table, string idCol, string keyCol, string listTable, string name, bool spatial)
        {
            string v = spatial ? "-1, -1, -1" : "-1, 0, 0";
            AddScenarioRow(store, table, idCol, keyCol, listTable, keyCol, name, "Summary, Spatial, AvgSpatial", v);
        }

        // one row keyed on a named definition, in each scenario that holds the sheet and lacks the key
        private static void AddScenarioRow(DataStore store, string table, string idCol, string keyCol, string listTable, string listId, string name, string otherCols, string otherVals)
        {
            if (!store.TableExists(table)) return;
            foreach (DataRow s in Holders(store, table).Rows)
            {
                string sc = Id(s["ScenarioId"]), key = IdOf(store, listTable, listId, Id(s["ProjectId"]), name);
                if (key == null) continue;
                if (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM " + table + " WHERE ScenarioId = " + sc + " AND " + keyCol + " = " + key), CultureInfo.InvariantCulture) > 0) continue;
                store.ExecuteNonQuery("INSERT INTO " + table + " (" + idCol + ", ScenarioId, " + keyCol + ", " + otherCols + ") VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + sc + ", " + key + ", " + otherVals + ")");
            }
        }
    }
}
