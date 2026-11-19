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
using System.Collections.Generic;
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
        [Update(1.3, "lucasCore 1.3: the forested wetland classes Wetland: Spruce/Fir Group, Wetland: Oak/Gum/Cypress Group and Wetland: Elm/Ash/Cottonwood Group with their Ag Contraction transition types; Data Sources Histosol share; the groups and diagram cell of the DOM: Peat stock, and the peat fire and drained peat flows")]
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

            // peat (tools/make_organic_soil.R): the DOM: Peat stock's groups and diagram cell, and the flows that take from it (fire,
            // drainage under cropland and pasture): flow types, their groups, memberships, order and filters
            string[] gas = { "CO2", "CO", "CH4" }; string[] co2e = { "3.67", "4.66", "33.5" };
            const string drain = "Emission: Drained Organic Soil -> Atmosphere", peat = "DOM: Peat";
            AddStockMembership(store, peat, "DOM: Soil", "NULL");
            AddStockMembership(store, peat, "Total Ecosystem", "NULL");
            AddScenarioRow(store, "stsim_FlowPathwayDiagram", "FlowPathwayDiagramId", "StockTypeId", "stsim_StockType", "StockTypeId", peat, "Location", "'F6'");
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "LULC: Emission Peat", "Description", "Peat burned by fire", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", "LULC: Emission Peat (CO2e)", "Description", "Peat burned by fire (CO2e)", false);
            for (int i = 0; i < 3; i++)
            {
                string f = "LULC: Emission Peat " + gas[i], m = "-" + co2e[i];
                AddNamed(store, "stsim_FlowType", "FlowTypeId", f, "Description", "Peat (DOM: Peat) burned by fire", false);
                AddNamed(store, "stsim_FlowGroup", "FlowGroupId", f + " [Type]", null, null, true);
                string[] mem = { "Emission: Total|1", "Emission: Total (CO2e)|" + co2e[i], "LULC: Emission|1", "LULC: Emission (CO2e)|" + co2e[i],
                                 "LULC: Emission " + gas[i] + "|1", "LULC: Emission " + gas[i] + " (CO2e)|" + co2e[i], "LULC: Emission Peat|1",
                                 "LULC: Emission Peat (CO2e)|" + co2e[i], "Net Biome Productivity|-1", "Net Biome Productivity (CO2e)|" + m };
                foreach (string g in mem) { string[] p = g.Split('|'); AddMembership(store, f, p[0], p[1]); }
                AddFlowOrder(store, f, 11);
                AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", f + " [Type]", false);
            }
            AddNamed(store, "stsim_FlowType", "FlowTypeId", drain, "Description", "Oxidation of drained peat (DOM: Peat) under cropland and pasture", false);
            AddNamed(store, "stsim_FlowGroup", "FlowGroupId", drain + " [Type]", null, null, true);
            string[] dm = { "Emission: Total|1", "Emission: Total (CO2e)|3.67", "Emission: Total Rh|1", "Emission: Total Rh (CO2e)|3.67",
                            "Net Biome Productivity|-1", "Net Biome Productivity (CO2e)|-3.67", "Net Ecosystem Productivity|-1", "Net Ecosystem Productivity (CO2e)|-3.67" };
            foreach (string g in dm) { string[] p = g.Split('|'); AddMembership(store, drain, p[0], p[1]); }
            AddFlowOrder(store, drain, 5);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", drain + " [Type]", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "LULC: Emission Peat", false);
            AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", "LULC: Emission Peat (CO2e)", false);
        }

        // ---- 1.4 (to-do 57): the post-disturbance classes (tools/make_post_disturbance.R). The description must not hold an apostrophe:
        // SyncroSim writes it into the library unquoted (1.3.0) ---------------------------------------------------------------------
        [Update(1.4, "lucasCore 1.4: the Disturbed state classes of every forest type group, forested wetland and five shrub classes, with the transition types and groups that return them to their type or convert them; the Reforestation transitions; the Management replanting transitions and their costs; and the Compare Carbon Summary columns for harvested wood products")]
        public static void Update_1_400(DataStore store)
        {
            // harvested wood products (to-do 59): stage 18's sheets are new (SyncroSim makes their tables); Compare Runs' carbon summary
            // gains the wood products columns
            AddColumn(store, "lucasCore_OutputCompareCarbon", "HwpStored", "DOUBLE");
            AddColumn(store, "lucasCore_OutputCompareCarbon", "HwpStockChange", "DOUBLE");
            AddColumn(store, "lucasCore_OutputCompareCarbon", "NbpWithProducts", "DOUBLE");
            AddNamed(store, "stsim_StateLabelX", "StateLabelXId", "Disturbed", null, null, false);
            AddStateAttributeType(store, "Live Forest", "State Class", "1 on forest type group classes (Ids 100-999), written by stage 10: the live forest share around a disturbed forest cell drives its return multiplier (to-do 57)");
            string[] grps = { "Post-disturbance", "Post-disturbance: Forest Return", "Post-disturbance: Shrub Return", "Post-disturbance: Conversion" };
            foreach (string g in grps) AddNamed(store, "stsim_TransitionGroup", "TransitionGroupId", g, null, null, false);
            for (int i = 1; i < grps.Length; i++)
            {
                AddTransitionType(store, grps[i], null);
                AddTypeToGroup(store, grps[i], grps[i]); AddTypeToGroup(store, grps[i], grps[0]);
            }
            // one disturbed class per forest class (Id 100-999) and per shrub class below, named by its Y label (a wetland twin, whose Y
            // label is the upland type, takes "Wetland <type>"), Id 2000 + its own
            string[] shrubs = { "Shrubland: Sage", "Shrubland: Native Sage Steppe", "Shrubland: Invaded Sage Steppe", "Shrubland: Non-sage", "Shrubland: Chaparral" };
            string sh = ""; foreach (string s in shrubs) sh += (sh.Length > 0 ? ", " : "") + Q(s);
            if (!store.TableExists("stsim_StateClass")) return;
            DataTable c = Rows(store, "SELECT DISTINCT c.Id AS Id, x.Name AS X, y.Name AS Y FROM stsim_StateClass c JOIN stsim_StateLabelX x ON x.StateLabelXId = c.StateLabelXId " +
                                      "JOIN stsim_StateLabelY y ON y.StateLabelYId = c.StateLabelYId WHERE (c.Id BETWEEN 100 AND 999) OR c.Name IN (" + sh + ")");
            foreach (DataRow r in c.Rows)
            {
                long id = Convert.ToInt64(r["Id"], CultureInfo.InvariantCulture);
                string y = Convert.ToString(r["Y"], CultureInfo.InvariantCulture);
                if (Convert.ToString(r["X"], CultureInfo.InvariantCulture) == "Wetland") y = "Wetland " + y;
                AddNamed(store, "stsim_StateLabelY", "StateLabelYId", y, "Description", "Disturbed", false);
                AddStateClass(store, "Disturbed: " + y, "Disturbed", y, (2000 + id).ToString(CultureInfo.InvariantCulture), id >= 100 ? "255,196,170,120" : "255,236,220,170");
            }

            // reforestation (to-do 57 steps 1-5, tools/make_reforestation.R): LANDFIRE BpS as a Data Source, the stage 5 maps of each
            // cell's destination forest type and BpS forest share, and the Reforestation group with one type per forest class
            // ("Reforestation: <Y label>", a wetland twin "Reforestation: Wetland <type>"). (The Reforestation Options sheet is a new
            // table, which SyncroSim adds by itself.)
            AddColumn(store, "lucasCore_DataSource", "BpsFile", "TEXT");
            AddColumn(store, "lucasCore_ManagementAction", "StratumId", "INTEGER");   // (the sheet is new in 1.4; a development library made it before this column)
            AddColumn(store, "lucasCore_ManagementAction", "Cost", "DOUBLE");
            AddColumn(store, "lucasCore_ManagementAction", "SitePrepCost", "DOUBLE");
            AddColumn(store, "lucasCore_OutputManagementAction", "CostPerArea", "DOUBLE");
            AddColumn(store, "lucasCore_ManagementAction", "Revenue", "DOUBLE");
            AddColumn(store, "lucasCore_ManagementAction", "CostRange", "INTEGER");
            AddColumn(store, "lucasCore_ManagementAction", "Budget", "DOUBLE");
            AddColumn(store, "lucasCore_OutputManagementAction", "RevenuePerArea", "DOUBLE");
            AddColumn(store, "lucasCore_DataSource", "RcmapCoverFolder", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "RpaLandUseFile", "TEXT");   // (Land Use Demand, 2026-11-14)
            AddColumn(store, "lucasCore_DataSource", "RpaForestProductsFolder", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "IclusCountyFile", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "PopulationProjectionFile", "TEXT");
            AddColumn(store, "lucasCore_DataSource", "CensusPopulationFile", "TEXT");
            AddColumn(store, "lucasCore_LandUseDemand", "AgChangeMethod", "INTEGER");
            AddColumn(store, "lucasCore_LandUseDemand", "AgChangeBalance", "DOUBLE");
            AddColumn(store, "lucasCore_OutputLandCoverLayers", "ReforestTypeFileName", "TEXT");
            AddColumn(store, "lucasCore_OutputLandCoverLayers", "BpsForestShareFileName", "TEXT");
            AddColumn(store, "lucasCore_OutputLandCoverLayers", "StartRuleFileName", "TEXT");
            AddColumn(store, "lucasCore_OutputLandCoverLayers", "FirstForestYearFileName", "TEXT");
            AddNamed(store, "stsim_TransitionGroup", "TransitionGroupId", "Reforestation", null, null, false);
            foreach (DataRow r in c.Rows)
            {
                if (Convert.ToInt64(r["Id"], CultureInfo.InvariantCulture) < 100) continue;
                string y = Convert.ToString(r["Y"], CultureInfo.InvariantCulture);
                if (Convert.ToString(r["X"], CultureInfo.InvariantCulture) == "Wetland") y = "Wetland " + y;
                AddTransitionType(store, "Reforestation: " + y, null);
                AddTypeToGroup(store, "Reforestation: " + y, "Reforestation");
            }
            // a transition simulation group, as Ag Contraction: ST-Sim writes transition maps only for these and [Type] groups
            AddSimulationGroup(store, "Reforestation");
            // Ag Change is no longer a simulation group (user 2026-11-13, a colleague's 1.3.2 projection warned "At least one Transition
            // Target has been defined with a non-primary Transition Group"): its targets are on its two types' [Type] groups (one area
            // per county each, defaults/projection/transitions.csv), but a type in a listed user group has that group as its primary
            // group, and ST-Sim's spatial allocation uses only the primary group's target, so the two types ran at their pathway
            // probability and stage 10's multipliers, with no target. Without it each type's [Type] group is its primary group, by
            // default (user: "With Ag Change removed the types inherit the default behavior"). The Ag Change group still summarizes
            // both; its two [Type] groups are mapped through the output filter (below)
            string[] agTypes = { "Ag Change: Cropland to Pasture [Type]", "Ag Change: Pasture to Cropland [Type]" };
            if (store.TableExists("stsim_TransitionSimulationGroup"))
                foreach (DataRow r in Rows(store, "SELECT ProjectId FROM core_Project").Rows)
                {
                    string g = IdOf(store, "stsim_TransitionGroup", "TransitionGroupId", Id(r["ProjectId"]), "Ag Change");
                    if (g != null) store.ExecuteNonQuery("DELETE FROM stsim_TransitionSimulationGroup WHERE ProjectId = " + Id(r["ProjectId"]) + " AND TransitionGroupId = " + g);
                }

            // management (to-do 58, tools/make_management.R): six replanting types (with or without site preparation, planted or failed),
            // their group and the two site preparation groups that carry its carbon flows. (The Management Actions sheets are new
            // tables, which SyncroSim adds by itself.)
            string[] grpM = { "Management: Replanting", "Site Preparation: Burn", "Site Preparation: Mechanical" };
            foreach (string g in grpM) AddNamed(store, "stsim_TransitionGroup", "TransitionGroupId", g, null, null, false);
            string[] preps = { "", " after Burn Site Prep", " after Mechanical Site Prep" };
            for (int i = 0; i < preps.Length; i++)
                foreach (string end in new[] { "", " (failed)" })
                {
                    string t = "Management: Replanting" + preps[i] + end;
                    AddTransitionType(store, t, null);
                    AddTypeToGroup(store, t, grpM[0]);
                    if (i > 0) AddTypeToGroup(store, t, grpM[i]);
                }
            // fuel treatments (tools/make_fuel_treatments.R): three types on upland forest in group Fuel Treatment; their pathways come with
            // the next Build (stage 6 reads the package pathways), their time since treatment with the Projection Setup (stage 9)
            AddNamed(store, "stsim_TransitionGroup", "TransitionGroupId", "Fuel Treatment", null, null, false);
            string[] ftTypes = { "Fuel Treatment: Mechanical Thinning", "Fuel Treatment: Prescribed Burn", "Fuel Treatment: Thin and Burn" };
            foreach (string t in ftTypes) { AddTransitionType(store, t, null); AddTypeToGroup(store, t, "Fuel Treatment"); }
            // rangeland restoration (tools/make_rangeland_restoration.R): four treatments, each established or failed, in group
            // Management: Rangeland Restoration; their pathways come with the next Build
            AddNamed(store, "stsim_TransitionGroup", "TransitionGroupId", "Management: Rangeland Restoration", null, null, false);
            var rrTypes = new List<string>();
            foreach (string b in new[] { "Management: Aerial Seeding", "Management: Drill Seeding", "Management: Sagebrush Planting", "Management: Herbicide and Seeding" })
                foreach (string end in new[] { "", " (failed)" }) rrTypes.Add(b + end);
            foreach (string t in rrTypes) { AddTransitionType(store, t, null); AddTypeToGroup(store, t, "Management: Rangeland Restoration"); }
            // management costs (tools/make_management.R): a Management Cost attribute group and four transition attribute types, USD:
            // three costs and the salvaged timber's revenue (net = revenue - costs)
            AddNamed(store, "stsim_AttributeGroup", "AttributeGroupId", "Management Cost", null, null, false);
            if (store.TableExists("stsim_TransitionAttributeType"))
            {
                string[,] costs = { { "Management Cost: Planting", "Replanting: seedlings and planting, per unit area planted (planted and failed alike)" },
                                    { "Management Cost: Site Preparation", "Site preparation before replanting (pile and burn, or mechanical), per unit area" },
                                    { "Management Cost: Salvage Logging", "Salvage logging and haul cost per unit area (its timber revenue is Management Revenue: Salvage Timber)" },
                                    { "Management Revenue: Salvage Timber", "Revenue from the salvaged timber per unit area, falling with years since the fire (net = revenue - costs)" },
                                    { "Management Revenue: Harvest Timber", "Stumpage revenue of clearcut and selection harvest per unit area harvested: merchantable volume x removal share x regional stumpage price (src/forest-management.R)" },
                                    { "Management Cost: Fuel Treatment", "Fuel treatment (mechanical thinning, prescribed burn, thin and burn) per unit area treated (src/fuel-treatments.R)" },
                                    { "Management Cost: Rangeland Restoration", "Rangeland restoration (aerial or drill seeding, sagebrush planting, herbicide and seeding) per unit area treated, established and failed alike (src/management.R)" } };
                foreach (DataRow r in Rows(store, "SELECT ProjectId FROM core_Project").Rows)
                {
                    string pr = Id(r["ProjectId"]), ag = IdOf(store, "stsim_AttributeGroup", "AttributeGroupId", pr, "Management Cost");
                    for (int i = 0; i < costs.GetLength(0); i++)
                    {
                        string have = IdOf(store, "stsim_TransitionAttributeType", "TransitionAttributeTypeId", pr, costs[i, 0]);
                        if (have != null) { store.ExecuteNonQuery("UPDATE stsim_TransitionAttributeType SET Description = " + Q(costs[i, 1]) + " WHERE TransitionAttributeTypeId = " + have); continue; }
                        store.ExecuteNonQuery("INSERT INTO stsim_TransitionAttributeType (TransitionAttributeTypeId, ProjectId, Name, AttributeGroupId, Units, Description) VALUES (" +
                                              NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + Q(costs[i, 0]) + ", " + (ag ?? "NULL") + ", 'USD', " + Q(costs[i, 1]) + ")");
                    }
                }
            }
            // ST-Sim summarizes only the groups in a scenario's transition output filter, and a library's filter was written when the
            // library was made (Lassen 2026-11-13: replanting ran but was not reported). Every scenario with a filter gets the new groups,
            // summary on (src/transition-filter.R)
            if (store.TableExists("stsim_OutputFilterTransitionGroups") && store.TableExists("core_Scenario"))
            {
                // mapped (Spatial and Spatial Probability on), as defaults/stockflow/main-transition-groups.csv: the replanting family and
                // its [Type] groups (each is simulated on its own target, and ST-Sim maps by simulation unit) and salvage's [Type] group;
                // the two site preparation groups are summarized only
                var names = new List<string>(grpM); var mapped = new HashSet<string> { grpM[0], "Forest Harvest: Salvage Logging [Type]" };
                names.Add("Forest Harvest: Salvage Logging [Type]");
                foreach (string n in agTypes) { names.Add(n); mapped.Add(n); }
                foreach (string t in ftTypes) { names.Add(t + " [Type]"); mapped.Add(t + " [Type]"); }   // (fuel treatments: summarized and mapped)
                names.Add("Management: Rangeland Restoration"); mapped.Add("Management: Rangeland Restoration");
                foreach (string t in rrTypes) { names.Add(t + " [Type]"); mapped.Add(t + " [Type]"); }   // (rangeland restoration: summarized and mapped)
                for (int i = 0; i < preps.Length; i++)
                    foreach (string end in new[] { "", " (failed)" }) { string n = "Management: Replanting" + preps[i] + end + " [Type]"; names.Add(n); mapped.Add(n); }
                foreach (DataRow r in Rows(store, "SELECT DISTINCT f.ScenarioId AS S, s.ProjectId AS P FROM stsim_OutputFilterTransitionGroups f JOIN core_Scenario s ON s.ScenarioId = f.ScenarioId").Rows)
                {
                    string sc = Id(r["S"]), pr = Id(r["P"]);
                    foreach (string n in names)
                    {
                        string g = IdOf(store, "stsim_TransitionGroup", "TransitionGroupId", pr, n); if (g == null) continue;
                        string m = mapped.Contains(n) ? "-1" : "0";
                        if (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM stsim_OutputFilterTransitionGroups WHERE ScenarioId = " + sc + " AND TransitionGroupId = " + g), CultureInfo.InvariantCulture) > 0)
                        {
                            if (m == "-1") store.ExecuteNonQuery("UPDATE stsim_OutputFilterTransitionGroups SET Spatial = -1, SpatialProbability = -1 WHERE ScenarioId = " + sc + " AND TransitionGroupId = " + g);
                            continue;
                        }
                        store.ExecuteNonQuery("INSERT INTO stsim_OutputFilterTransitionGroups (OutputFilterTransitionGroupsId, ScenarioId, TransitionGroupId, Summary, SummaryByStateClass, TimeSinceTransition, Spatial, SpatialEvents, SpatialTimeSinceTransition, SpatialProbability, AvgSpatialTimeSinceTransition) VALUES (" +
                                              NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + sc + ", " + g + ", -1, 0, 0, " + m + ", 0, 0, " + m + ", 0)");
                    }
                }
            }
        }

        // ---- 1.6 (forest cover, 2026-11): Data Sources holds the USFS Tree Canopy Cover folder (Forest Cover page: canopy forest,
        // recovery and stocking; src/forest-cover.R). The Forest Cover, Stand Age and Carbon Capacity sheets and their outputs are
        // new tables, which SyncroSim adds by itself. No apostrophe in the description ------------------------------------------------
        [Update(1.6, "lucasCore 1.6: Data Sources folder for the USFS Tree Canopy Cover (forest by tree canopy cover, recovery after disturbance and forest stocking on the Forest Cover page)")]
        public static void Update_1_600(DataStore store)
        {
            AddColumn(store, "lucasCore_DataSource", "TreeCanopyFolder", "TEXT");
        }

        // ---- 1.5 (wetland methane, 2026-11): wetland classes release part of what their soil and litter emit as CH4 (src/flows.R,
        // src/nonforest-solve.R). The rows are the ones defaults/stsim and defaults/stockflow gained (generated from them). The three
        // Wetland Methane sheets are new tables, which SyncroSim adds by itself. A library keeps running on its earlier Builds; the
        // methane comes with its next Build (stages 0 and 3). No apostrophe in the description -----------------------------------------
        [Update(1.5, "lucasCore 1.5: wetland methane - the CO2 and CH4 emission flow types of wetland soil, root litter and forest floor with their groups, orders and output filters; the Q10 Wetland Soil and Q10 Wetland CH4 groups; the Marsh Salinity and Methane Uncertainty flow multiplier types; and the Climate Options wetland growth choice")]
        public static void Update_1_500(DataStore store)
        {
            AddColumn(store, "lucasCore_ClimateOptions", "WetlandGrowthModel", "INTEGER");
            string[,] types = {
                { "Emission: BG Slow -> Atmosphere (Wetland)", "Emergent wetlands: soil carbon released as CO2, with a temperature response of its own (Q10 Wetland Soil)" },
                { "Emission: BG Slow -> Atmosphere CH4", "Emergent wetlands: soil carbon released as methane" },
                { "Emission: BG Very Fast -> Atmosphere CH4", "Emergent wetlands: root litter carbon released as methane" },
                { "Emission: BG Very Fast -> Atmosphere (Wetland)", "Emergent and forested wetlands: root litter carbon released as CO2 (the same response as every class, by a flow type of their own so a wetland cell can be told apart)" },
                { "Emission: AG Very Fast -> Atmosphere (Wetland)", "Forested wetlands: ag very fast (forest floor) carbon released as CO2, by a flow type of their own so a wetland cell can be told apart" },
                { "Emission: AG Fast -> Atmosphere (Wetland)", "Forested wetlands: ag fast (forest floor) carbon released as CO2, by a flow type of their own so a wetland cell can be told apart" },
                { "Emission: AG Slow -> Atmosphere (Wetland)", "Forested wetlands: ag slow (forest floor) carbon released as CO2, by a flow type of their own so a wetland cell can be told apart" },
                { "Emission: AG Very Fast -> Atmosphere CH4", "Forested wetlands: ag very fast (forest floor) carbon released as methane" },
                { "Emission: AG Fast -> Atmosphere CH4", "Forested wetlands: ag fast (forest floor) carbon released as methane" },
                { "Emission: AG Slow -> Atmosphere CH4", "Forested wetlands: ag slow (forest floor) carbon released as methane" }
 };
            for (int i = 0; i < types.GetLength(0); i++)
            {
                AddNamed(store, "stsim_FlowType", "FlowTypeId", types[i, 0], "Description", types[i, 1], false);
                AddNamed(store, "stsim_FlowGroup", "FlowGroupId", types[i, 0] + " [Type]", null, null, true);
            }
            string[,] groups = {
                { "Q10 Wetland Soil", "Temperature response of CO2 release from emergent wetland soil (BG Slow)" },
                { "Q10 Wetland CH4", "Temperature response of methane release from emergent wetland soil and root litter" },
                { "Emission: Wetland CH4", "Methane from emergent wetlands in C" },
                { "Emission: Wetland CH4 (CO2e)", "Methane from emergent wetlands in CO2e" },
                { "Emission: Wetland Methane Source CO2", "CO2 from the wetland pools that also release methane, in C: soil and root litter, and in forested wetlands the forest floor (the flows a marsh salinity or methane uncertainty multiplier adjusts)" }
 };
            for (int i = 0; i < groups.GetLength(0); i++) AddNamed(store, "stsim_FlowGroup", "FlowGroupId", groups[i, 0], "Description", groups[i, 1], false);
            foreach (string m in new[] { "Marsh Salinity", "Methane Uncertainty" }) AddNamed(store, "stsim_FlowMultiplierType", "FlowMultiplierTypeId", m, null, null, false);
            // stock-flow rows of the scenarios that hold their own (a library made in Studio has none: stage 0 writes them into each Build)
            string[] memberships = {
                "Emission: BG Slow -> Atmosphere (Wetland)|BG Slow ->|1", "Emission: BG Slow -> Atmosphere (Wetland)|Emission: Total|1", "Emission: BG Slow -> Atmosphere (Wetland)|Emission: Total (CO2e)|3.67",
                "Emission: BG Slow -> Atmosphere (Wetland)|Emission: Total Rh|1", "Emission: BG Slow -> Atmosphere (Wetland)|Emission: Total Rh (CO2e)|3.67", "Emission: BG Slow -> Atmosphere (Wetland)|Net Biome Productivity|-1",
                "Emission: BG Slow -> Atmosphere (Wetland)|Net Biome Productivity (CO2e)|-3.67", "Emission: BG Slow -> Atmosphere (Wetland)|Net Ecosystem Productivity|-1", "Emission: BG Slow -> Atmosphere (Wetland)|Net Ecosystem Productivity (CO2e)|-3.67",
                "Emission: BG Slow -> Atmosphere (Wetland)|Q10 Wetland Soil|1", "Emission: BG Slow -> Atmosphere CH4|BG Slow ->|1", "Emission: BG Slow -> Atmosphere CH4|Q10 Wetland CH4|1",
                "Emission: BG Slow -> Atmosphere CH4|Emission: Wetland CH4|1", "Emission: BG Slow -> Atmosphere CH4|Emission: Wetland CH4 (CO2e)|33.5", "Emission: BG Slow -> Atmosphere CH4|Emission: Total|1",
                "Emission: BG Slow -> Atmosphere CH4|Emission: Total (CO2e)|33.5", "Emission: BG Slow -> Atmosphere CH4|Emission: Total Rh|1", "Emission: BG Slow -> Atmosphere CH4|Emission: Total Rh (CO2e)|33.5",
                "Emission: BG Slow -> Atmosphere CH4|Net Biome Productivity|-1", "Emission: BG Slow -> Atmosphere CH4|Net Biome Productivity (CO2e)|-33.5", "Emission: BG Slow -> Atmosphere CH4|Net Ecosystem Productivity|-1",
                "Emission: BG Slow -> Atmosphere CH4|Net Ecosystem Productivity (CO2e)|-33.5", "Emission: BG Very Fast -> Atmosphere CH4|BG Very Fast ->|1", "Emission: BG Very Fast -> Atmosphere CH4|Q10 Wetland CH4|1",
                "Emission: BG Very Fast -> Atmosphere CH4|Emission: Wetland CH4|1", "Emission: BG Very Fast -> Atmosphere CH4|Emission: Wetland CH4 (CO2e)|33.5", "Emission: BG Very Fast -> Atmosphere CH4|Emission: Total|1",
                "Emission: BG Very Fast -> Atmosphere CH4|Emission: Total (CO2e)|33.5", "Emission: BG Very Fast -> Atmosphere CH4|Emission: Total Rh|1", "Emission: BG Very Fast -> Atmosphere CH4|Emission: Total Rh (CO2e)|33.5",
                "Emission: BG Very Fast -> Atmosphere CH4|Net Biome Productivity|-1", "Emission: BG Very Fast -> Atmosphere CH4|Net Biome Productivity (CO2e)|-33.5", "Emission: BG Very Fast -> Atmosphere CH4|Net Ecosystem Productivity|-1",
                "Emission: BG Very Fast -> Atmosphere CH4|Net Ecosystem Productivity (CO2e)|-33.5", "Emission: BG Very Fast -> Atmosphere (Wetland)|BG Very Fast ->|1", "Emission: BG Very Fast -> Atmosphere (Wetland)|Emission: Total|1",
                "Emission: BG Very Fast -> Atmosphere (Wetland)|Emission: Total (CO2e)|3.67", "Emission: BG Very Fast -> Atmosphere (Wetland)|Emission: Total Rh|1", "Emission: BG Very Fast -> Atmosphere (Wetland)|Emission: Total Rh (CO2e)|3.67",
                "Emission: BG Very Fast -> Atmosphere (Wetland)|Net Biome Productivity|-1", "Emission: BG Very Fast -> Atmosphere (Wetland)|Net Biome Productivity (CO2e)|-3.67", "Emission: BG Very Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity|-1",
                "Emission: BG Very Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity (CO2e)|-3.67", "Emission: BG Very Fast -> Atmosphere (Wetland)|Q10 Slow Flows|1", "Emission: BG Slow -> Atmosphere (Wetland)|Emission: Wetland Methane Source CO2|1",
                "Emission: BG Very Fast -> Atmosphere (Wetland)|Emission: Wetland Methane Source CO2|1", "Emission: AG Very Fast -> Atmosphere (Wetland)|AG Very Fast ->|1", "Emission: AG Very Fast -> Atmosphere (Wetland)|Emission: Total|1",
                "Emission: AG Very Fast -> Atmosphere (Wetland)|Emission: Total (CO2e)|3.67", "Emission: AG Very Fast -> Atmosphere (Wetland)|Emission: Total Rh|1", "Emission: AG Very Fast -> Atmosphere (Wetland)|Emission: Total Rh (CO2e)|3.67",
                "Emission: AG Very Fast -> Atmosphere (Wetland)|Net Biome Productivity|-1", "Emission: AG Very Fast -> Atmosphere (Wetland)|Net Biome Productivity (CO2e)|-3.67", "Emission: AG Very Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity|-1",
                "Emission: AG Very Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity (CO2e)|-3.67", "Emission: AG Very Fast -> Atmosphere (Wetland)|Q10 Fast Flows|1", "Emission: AG Very Fast -> Atmosphere (Wetland)|Emission: Wetland Methane Source CO2|1",
                "Emission: AG Very Fast -> Atmosphere CH4|AG Very Fast ->|1", "Emission: AG Very Fast -> Atmosphere CH4|Emission: Total|1", "Emission: AG Very Fast -> Atmosphere CH4|Emission: Total (CO2e)|33.5",
                "Emission: AG Very Fast -> Atmosphere CH4|Emission: Total Rh|1", "Emission: AG Very Fast -> Atmosphere CH4|Emission: Total Rh (CO2e)|33.5", "Emission: AG Very Fast -> Atmosphere CH4|Net Biome Productivity|-1",
                "Emission: AG Very Fast -> Atmosphere CH4|Net Biome Productivity (CO2e)|-33.5", "Emission: AG Very Fast -> Atmosphere CH4|Net Ecosystem Productivity|-1", "Emission: AG Very Fast -> Atmosphere CH4|Net Ecosystem Productivity (CO2e)|-33.5",
                "Emission: AG Very Fast -> Atmosphere CH4|Q10 Wetland CH4|1", "Emission: AG Very Fast -> Atmosphere CH4|Emission: Wetland CH4|1", "Emission: AG Very Fast -> Atmosphere CH4|Emission: Wetland CH4 (CO2e)|33.5",
                "Emission: AG Fast -> Atmosphere (Wetland)|Emission: Total|1", "Emission: AG Fast -> Atmosphere (Wetland)|Emission: Total (CO2e)|3.67", "Emission: AG Fast -> Atmosphere (Wetland)|Emission: Total Rh|1",
                "Emission: AG Fast -> Atmosphere (Wetland)|Emission: Total Rh (CO2e)|3.67", "Emission: AG Fast -> Atmosphere (Wetland)|Net Biome Productivity|-1", "Emission: AG Fast -> Atmosphere (Wetland)|Net Biome Productivity (CO2e)|-3.67",
                "Emission: AG Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity|-1", "Emission: AG Fast -> Atmosphere (Wetland)|Net Ecosystem Productivity (CO2e)|-3.67", "Emission: AG Fast -> Atmosphere (Wetland)|Q10 Slow Flows|1",
                "Emission: AG Fast -> Atmosphere (Wetland)|Emission: Wetland Methane Source CO2|1", "Emission: AG Fast -> Atmosphere CH4|Emission: Total|1", "Emission: AG Fast -> Atmosphere CH4|Emission: Total (CO2e)|33.5",
                "Emission: AG Fast -> Atmosphere CH4|Emission: Total Rh|1", "Emission: AG Fast -> Atmosphere CH4|Emission: Total Rh (CO2e)|33.5", "Emission: AG Fast -> Atmosphere CH4|Net Biome Productivity|-1",
                "Emission: AG Fast -> Atmosphere CH4|Net Biome Productivity (CO2e)|-33.5", "Emission: AG Fast -> Atmosphere CH4|Net Ecosystem Productivity|-1", "Emission: AG Fast -> Atmosphere CH4|Net Ecosystem Productivity (CO2e)|-33.5",
                "Emission: AG Fast -> Atmosphere CH4|Q10 Wetland CH4|1", "Emission: AG Fast -> Atmosphere CH4|Emission: Wetland CH4|1", "Emission: AG Fast -> Atmosphere CH4|Emission: Wetland CH4 (CO2e)|33.5",
                "Emission: AG Slow -> Atmosphere (Wetland)|Emission: Total|1", "Emission: AG Slow -> Atmosphere (Wetland)|Emission: Total (CO2e)|3.67", "Emission: AG Slow -> Atmosphere (Wetland)|Emission: Total Rh|1",
                "Emission: AG Slow -> Atmosphere (Wetland)|Emission: Total Rh (CO2e)|3.67", "Emission: AG Slow -> Atmosphere (Wetland)|Net Biome Productivity|-1", "Emission: AG Slow -> Atmosphere (Wetland)|Net Biome Productivity (CO2e)|-3.67",
                "Emission: AG Slow -> Atmosphere (Wetland)|Net Ecosystem Productivity|-1", "Emission: AG Slow -> Atmosphere (Wetland)|Net Ecosystem Productivity (CO2e)|-3.67", "Emission: AG Slow -> Atmosphere (Wetland)|Q10 Fast Flows|1",
                "Emission: AG Slow -> Atmosphere (Wetland)|Emission: Wetland Methane Source CO2|1", "Emission: AG Slow -> Atmosphere CH4|Emission: Total|1", "Emission: AG Slow -> Atmosphere CH4|Emission: Total (CO2e)|33.5",
                "Emission: AG Slow -> Atmosphere CH4|Emission: Total Rh|1", "Emission: AG Slow -> Atmosphere CH4|Emission: Total Rh (CO2e)|33.5", "Emission: AG Slow -> Atmosphere CH4|Net Biome Productivity|-1",
                "Emission: AG Slow -> Atmosphere CH4|Net Biome Productivity (CO2e)|-33.5", "Emission: AG Slow -> Atmosphere CH4|Net Ecosystem Productivity|-1", "Emission: AG Slow -> Atmosphere CH4|Net Ecosystem Productivity (CO2e)|-33.5",
                "Emission: AG Slow -> Atmosphere CH4|Q10 Wetland CH4|1", "Emission: AG Slow -> Atmosphere CH4|Emission: Wetland CH4|1", "Emission: AG Slow -> Atmosphere CH4|Emission: Wetland CH4 (CO2e)|33.5"
 };
            foreach (string m in memberships) { string[] p = m.Split('|'); AddMembership(store, p[0], p[1], p[2]); }
            string[] orders = {
                "Emission: BG Slow -> Atmosphere (Wetland)|5", "Emission: BG Slow -> Atmosphere CH4|5", "Emission: BG Very Fast -> Atmosphere CH4|6.5",
                "Emission: BG Very Fast -> Atmosphere (Wetland)|6.5", "Emission: AG Very Fast -> Atmosphere (Wetland)|6.5", "Emission: AG Fast -> Atmosphere (Wetland)|6.5",
                "Emission: AG Slow -> Atmosphere (Wetland)|6.6", "Emission: AG Very Fast -> Atmosphere CH4|6.5", "Emission: AG Fast -> Atmosphere CH4|6.5",
                "Emission: AG Slow -> Atmosphere CH4|6.6"
 };
            foreach (string o in orders) { string[] p = o.Split('|'); AddScenarioRow(store, "stsim_FlowOrder", "FlowOrderId", "FlowTypeId", "stsim_FlowType", "FlowTypeId", p[0], "\"Order\"", p[1]); }
            string[] filters = {
                "Emission: Wetland CH4", "Emission: Wetland CH4 (CO2e)", "Emission: BG Slow -> Atmosphere (Wetland) [Type]",
                "Emission: BG Slow -> Atmosphere CH4 [Type]", "Emission: BG Very Fast -> Atmosphere CH4 [Type]", "Emission: Wetland Methane Source CO2",
                "Emission: BG Very Fast -> Atmosphere (Wetland) [Type]", "Emission: AG Very Fast -> Atmosphere (Wetland) [Type]", "Emission: AG Fast -> Atmosphere (Wetland) [Type]",
                "Emission: AG Slow -> Atmosphere (Wetland) [Type]", "Emission: AG Very Fast -> Atmosphere CH4 [Type]", "Emission: AG Fast -> Atmosphere CH4 [Type]",
                "Emission: AG Slow -> Atmosphere CH4 [Type]"
 };
            foreach (string f in filters) AddFilter(store, "stsim_OutputFilterFlows", "OutputFilterFlowsId", "FlowGroupId", "stsim_FlowGroup", f, false);
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
                if (likeType == null) continue;
                string like = IdOf(store, "stsim_TransitionType", "TransitionTypeId", pr, likeType);
                if (like == null) continue;
                DataTable g = Rows(store, "SELECT TransitionGroupId FROM stsim_TransitionTypeGroup WHERE ProjectId = " + pr + " AND TransitionTypeId = " + like + " AND IsAuto IS NULL");
                foreach (DataRow gr in g.Rows)
                    store.ExecuteNonQuery("INSERT INTO stsim_TransitionTypeGroup (TransitionTypeGroupId, ProjectId, TransitionTypeId, TransitionGroupId) VALUES (" +
                                          NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + tt + ", " + Id(gr["TransitionGroupId"]) + ")");
            }
        }

        // a state attribute type in its attribute group, in every project that has the group and lacks the type
        private static void AddStateAttributeType(DataStore store, string name, string group, string description)
        {
            if (!store.TableExists("stsim_StateAttributeType")) return;
            DataTable p = Rows(store, "SELECT ProjectId FROM core_Project WHERE ProjectId NOT IN (SELECT ProjectId FROM stsim_StateAttributeType WHERE Name = " + Q(name) + ")");
            foreach (DataRow r in p.Rows)
            {
                string pr = Id(r["ProjectId"]), g = IdOf(store, "stsim_AttributeGroup", "AttributeGroupId", pr, group);
                if (g == null) continue;
                store.ExecuteNonQuery("INSERT INTO stsim_StateAttributeType (StateAttributeTypeId, ProjectId, Name, AttributeGroupId, Description) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + Q(name) + ", " + g + ", " + Q(description) + ")");
            }
        }

        // a transition type's membership of a named transition group, in every project that has both and lacks it
        private static void AddTypeToGroup(DataStore store, string type, string group)
        {
            if (!store.TableExists("stsim_TransitionTypeGroup")) return;
            foreach (DataRow r in Rows(store, "SELECT ProjectId FROM core_Project").Rows)
            {
                string pr = Id(r["ProjectId"]);
                string t = IdOf(store, "stsim_TransitionType", "TransitionTypeId", pr, type), g = IdOf(store, "stsim_TransitionGroup", "TransitionGroupId", pr, group);
                if (t == null || g == null) continue;
                if (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM stsim_TransitionTypeGroup WHERE ProjectId = " + pr + " AND TransitionTypeId = " + t + " AND TransitionGroupId = " + g), CultureInfo.InvariantCulture) > 0) continue;
                store.ExecuteNonQuery("INSERT INTO stsim_TransitionTypeGroup (TransitionTypeGroupId, ProjectId, TransitionTypeId, TransitionGroupId) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + t + ", " + g + ")");
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
        // a project's transition simulation group (if the group exists and is not listed yet)
        private static void AddSimulationGroup(DataStore store, string name)
        {
            if (!store.TableExists("stsim_TransitionSimulationGroup")) return;
            foreach (DataRow r in Rows(store, "SELECT ProjectId FROM core_Project").Rows)
            {
                string pr = Id(r["ProjectId"]), g = IdOf(store, "stsim_TransitionGroup", "TransitionGroupId", pr, name);
                if (g == null || Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM stsim_TransitionSimulationGroup WHERE ProjectId = " + pr + " AND TransitionGroupId = " + g), CultureInfo.InvariantCulture) > 0) continue;
                store.ExecuteNonQuery("INSERT INTO stsim_TransitionSimulationGroup (TransitionSimulationGroupId, ProjectId, TransitionGroupId) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + pr + ", " + g + ")");
            }
        }

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

        // a stock type's membership in a stock group (Value NULL: counted whole), in each scenario holding its own stock-flow definitions
        private static void AddStockMembership(DataStore store, string stockType, string stockGroup, string value)
        {
            const string t = "stsim_StockTypeGroupMembership";
            if (!store.TableExists(t)) return;
            foreach (DataRow s in Holders(store, t).Rows)
            {
                string sc = Id(s["ScenarioId"]), pr = Id(s["ProjectId"]);
                string st = IdOf(store, "stsim_StockType", "StockTypeId", pr, stockType), sg = IdOf(store, "stsim_StockGroup", "StockGroupId", pr, stockGroup);
                if (st == null || sg == null) continue;
                if (Convert.ToInt64(store.ExecuteScalar("SELECT COUNT(*) FROM " + t + " WHERE ScenarioId = " + sc + " AND StockTypeId = " + st + " AND StockGroupId = " + sg), CultureInfo.InvariantCulture) > 0) continue;
                store.ExecuteNonQuery("INSERT INTO " + t + " (StockTypeGroupMembershipId, ScenarioId, StockTypeId, StockGroupId, Value) VALUES (" +
                                      NewId(store).ToString(CultureInfo.InvariantCulture) + ", " + sc + ", " + st + ", " + sg + ", " + value + ")");
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
