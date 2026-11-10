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

        // ---- 1.3 (lucasCore 1.3.0): forested wetland twins and organic soils (to-do 53) -----------------------------------------
        [Update(1.3, "lucasCore 1.3: the forested wetland classes Wetland: Spruce/Fir Group, Wetland: Oak/Gum/Cypress Group and Wetland: Elm/Ash/Cottonwood Group with their Ag Contraction transition types; Data Sources Histosol share")]
        public static void Update_1_300(DataStore store)
        {
            AddColumn(store, "lucasCore_DataSource", "HistosolFile", "TEXT");
            string[,] tw = { { "Spruce/Fir Group", "121", "255,140,170,60" }, { "Oak/Gum/Cypress Group", "601", "255,40,120,130" }, { "Elm/Ash/Cottonwood Group", "701", "255,140,90,40" } };
            for (int i = 0; i < 3; i++)
            {
                AddStateClass(store, "Wetland: " + tw[i, 0], "Wetland", tw[i, 0], tw[i, 1], tw[i, 2]);
                foreach (string use in new[] { "Cropland", "Pasture" })
                {
                    string up = "Ag Contraction " + use + ": " + tw[i, 0], tt = "Ag Contraction " + use + ": Wetland " + tw[i, 0];
                    AddTransitionType(store, tt, up);
                }
            }

            // peat fire and drained organic soils (tools/make_organic_soil.R): flow types, their groups, memberships, order and filters
            string[] gas = { "CO2", "CO", "CH4" }; string[] co2e = { "3.67", "4.66", "33.5" };
            const string drain = "Emission: Drained Organic Soil -> Atmosphere";
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "Organic Soil", "Description", "The flows on organic soil only (peat fire, drained organic soil): the group of the Organic Soil Share spatial multiplier", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "LULC: Emission Peat", "Description", "Peat burned by fire", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "LULC: Emission Peat (CO2e)", "Description", "Peat burned by fire (CO2e)", false);
            AddNamed(store, "stsim_FlowMultiplierType", "FlowMultiplierTypeId", "Organic Soil Share", null, null, false);
            for (int i = 0; i < 3; i++)
            {
                string f = "LULC: Emission Peat " + gas[i], m = "-" + co2e[i];
                AddNamed(store, "stsim_FlowType", "FlowTypeId", f, "Description", "Peat burned by fire on organic soil (forested wetland twins; Organic Soil Share map)", false);
                AddNamed(store, "stsim_FlowGroup", "FlowGroupId", f + " [Type]", null, null, true);
                string[] mem = { "Emission: Total|1", "Emission: Total (CO2e)|" + co2e[i], "LULC: Emission|1", "LULC: Emission (CO2e)|" + co2e[i],
                                 "LULC: Emission " + gas[i] + "|1", "LULC: Emission " + gas[i] + " (CO2e)|" + co2e[i], "LULC: Emission Peat|1",
                                 "LULC: Emission Peat (CO2e)|" + co2e[i], "Net Biome Productivity|-1", "Net Biome Productivity (CO2e)|" + m, "Organic Soil|1" };
                foreach (string g in mem) { string[] p = g.Split('|'); AddMembership(store, f, p[0], p[1]); }
                AddFlowOrder(store, f, 11);
                AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", f + " [Type]", false);
            }
            AddNamed(store, "stsim_FlowType", "FlowTypeId", drain, "Description", "Oxidation of drained organic soil under cropland and pasture (Organic Soil Share map)", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", drain + " [Type]", null, null, true);
            string[] dm = { "BG Slow ->|1", "Emission: Total|1", "Emission: Total (CO2e)|3.67", "Emission: Total Rh|1", "Emission: Total Rh (CO2e)|3.67",
                            "Net Biome Productivity|-1", "Net Biome Productivity (CO2e)|-3.67", "Net Ecosystem Productivity|-1", "Net Ecosystem Productivity (CO2e)|-3.67", "Organic Soil|1" };
            foreach (string g in dm) { string[] p = g.Split('|'); AddMembership(store, drain, p[0], p[1]); }
            AddFlowOrder(store, drain, 5);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", drain + " [Type]", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "LULC: Emission Peat", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "LULC: Emission Peat (CO2e)", false);
        }

        // a state class (with its Id, labels by name) in every project that lacks it
        private static void AddStateClass(DataStore store, string name, string labelX, string labelY, string id, string color)
        {
            if (!store.TableExists("stsim_StateClass")) return;
            DataTable p = Rows(store, "SELECT ProjectId FROM core_Project WHERE ProjectId NOT IN (SELECT ProjectId FROM stsim_StateClass WHERE Name = " + Q(name) + ")");
            foreach (DataRow r in p.Rows)
            {
                string pr = Id(r["ProjectId"]);
                string x = IdOf(store, "stsim_StateLabelX", "StateLabelXId", pr, labelX), y = IdOf(store, "stsim_StateLabelY", "StateLabelYId", pr, labelY);
                if (x == null || y == null) continue;
                store.ExecuteNonQuery("INSERT INTO stsim_StateClass (StateClassId, ProjectId, Name, StateLabelXId, StateLabelYId, Id, Color) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + Q(name) + ", " + x + ", " + y + ", " + id + ", " + Q(color) + ")");
            }
        }

        // a transition type in every project that lacks it, with a free Id, ST-Sim's own [Type] group, and the named groups of the
        // type it copies (likeType: Ag Contraction, Ag Contraction: Cropland ...)
        private static void AddTransitionType(DataStore store, string name, string likeType)
        {
            if (!store.TableExists("stsim_TransitionType")) return;
            DataTable p = Rows(store, "SELECT ProjectId FROM core_Project WHERE ProjectId NOT IN (SELECT ProjectId FROM stsim_TransitionType WHERE Name = " + Q(name) + ")");
            foreach (DataRow r in p.Rows)
            {
                string pr = Id(r["ProjectId"]);
                long free = 1009;
                while (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM stsim_TransitionType WHERE ProjectId = " + pr + " AND Id = " + free.ToString(CultureInfo.InvariantCulture)), CultureInfo.InvariantCulture) > 0) free++;
                string tt = NewId(store).ToString(CultureInfo.InvariantCulture);
                store.ExecuteNonQuery("INSERT INTO stsim_TransitionType (TransitionTypeId, ProjectId, Name, Id) VALUES (" + tt + ", " + pr + ", " + Q(name) + ", " + free.ToString(CultureInfo.InvariantCulture) + ")");
                string auto = NewId(store).ToString(CultureInfo.InvariantCulture);
                store.ExecuteNonQuery("INSERT INTO stsim_TransitionGroup (TransitionGroupId, ProjectId, Name, IsAuto) VALUES (" + auto + ", " + pr + ", " + Q(name + " [Type]") + ", -1)");
                store.ExecuteNonQuery("INSERT INTO stsim_TransitionTypeGroup (TransitionTypeGroupId, ProjectId, TransitionTypeId, TransitionGroupId, IsAuto) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + tt + ", " + auto + ", -1)");
                string like = IdOf(store, "stsim_TransitionType", "TransitionTypeId", pr, likeType);
                if (like == null) continue;
                DataTable g = Rows(store, "SELECT TransitionGroupId FROM stsim_TransitionTypeGroup WHERE ProjectId = " + pr + " AND TransitionTypeId = " + like + " AND IsAuto IS NULL");
                foreach (DataRow gr in g.Rows)
                    store.ExecuteNonQuery("INSERT INTO stsim_TransitionTypeGroup (TransitionTypeGroupId, ProjectId, TransitionTypeId, TransitionGroupId) VALUES (" +
                                          NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + tt + ", " + Id(gr["TransitionGroupId"]) + ")");
            }
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
