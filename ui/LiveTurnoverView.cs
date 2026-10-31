// =============================================================================
// LiveTurnoverView.cs - Carbon Assumptions > Live Turnover: every live turnover rate of a forest type, where it comes from, and its override
// =============================================================================
// Sheet lucasCore_LiveTurnover (Ecodivision, Forest Type, ten rates). Nothing here is calibrated, so the page works the rates out as stage
// 3 does (src/flows.R turnover_rates): CBM-CFS3's ecozone and species type rates, through CBM Crosswalk and Growth Inputs (softwood or
// hardwood, deciduous share), then the sheet's values - an ecodivision row's, else the forest type's all-ecodivisions row's, column by
// column. With FIA measured dead wood an EMPTY sheet means the package's rows (FIA stem turnover, 151 rows); a sheet with rows uses only
// its rows. So the first value typed on an empty page writes the package rows first, and the page shows the FIA ones as such.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class LiveTurnoverView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_LiveTurnover"; } }

        // sheet column, label, format
        private static readonly string[][] Rates = {
            new[] { "FoliageTurnover", "Foliage turnover (/yr, to AG Very Fast)", "0.0000" },
            new[] { "BranchTurnover", "Branch turnover (/yr)", "0.0000" },
            new[] { "BranchToSnag", "Branches: share to Snag Branch (rest to AG Fast)", "0.00" },
            new[] { "StemTurnover", "Stem turnover (/yr, to Snag Stem)", "0.0000" },
            new[] { "FineRootTurnover", "Fine root turnover (/yr)", "0.0000" },
            new[] { "FineRootToAG", "Fine roots: share to AG Very Fast (rest to BG Very Fast)", "0.00" },
            new[] { "CoarseRootTurnover", "Coarse root turnover (/yr)", "0.0000" },
            new[] { "CoarseRootToAG", "Coarse roots: share to AG Fast (rest to BG Fast)", "0.00" },
            new[] { "StemSnagFall", "Stem snag fall (/yr, to AG Medium)", "0.0000" },
            new[] { "BranchSnagFall", "Branch snag fall (/yr, to AG Fast)", "0.0000" } };
        private static IEnumerable<string> Columns { get { return Rates.Select(r => r[0]); } }

        private class Item { public int? Key; public string Name; public override string ToString() { return Name; } }

        private readonly ComboBox m_type = List(320);
        private readonly ComboBox m_eco = List(240);
        private readonly Label m_map = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 6), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };
        private readonly DataGridView m_grid = new DataGridView
        {
            Height = 290, Dock = DockStyle.Top, AllowUserToAddRows = false, AllowUserToDeleteRows = false, AllowUserToResizeRows = false, RowHeadersVisible = false,
            SelectionMode = DataGridViewSelectionMode.CellSelect, BackgroundColor = SystemColors.Window, BorderStyle = BorderStyle.FixedSingle,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill, EditMode = DataGridViewEditMode.EditOnEnter
        };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private readonly Panel m_all = GridHost(220);
        private string m_note = "";

        // package tables, read once
        private static Dictionary<string, Dictionary<string, double>> s_eco, s_species;
        private static Dictionary<string, string[]> s_cbmMap;                       // forest type name -> ecozone, species type
        private static Dictionary<string, KeyValuePair<bool, double>> s_growth;    // forest type name -> softwood, deciduous share
        private static List<string[]> s_fia;                                       // the package rows (ecodivision name, type name, values)

        public LiveTurnoverView()
        {
            this.SuspendLayout();
            var pick = Row();
            pick.Controls.AddRange(new Control[] { Caption("Forest type"), m_type, Caption("Ecodivision"), m_eco });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Rate", HeaderText = "Rate", ReadOnly = true, FillWeight = 150 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Used", HeaderText = "Value used", ReadOnly = true, FillWeight = 45, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight } });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "From", HeaderText = "Comes from", ReadOnly = true, FillWeight = 140 });
            m_grid.Columns.Add(new DataGridViewTextBoxColumn { Name = "Row", HeaderText = "This row (blank = not set)", FillWeight = 55, DefaultCellStyle = { Alignment = DataGridViewContentAlignment.MiddleRight, BackColor = Color.FromArgb(255, 252, 230) } });
            foreach (DataGridViewColumn c in m_grid.Columns) c.SortMode = DataGridViewColumnSortMode.NotSortable;
            AddGroup(Group("Live turnover (stage 3)", ProjectionTransitionsView.Stack(
                Note("How fast each live pool of a forest type is shed each year, and where it goes. Nothing here is calibrated by the Build: the rates are CBM-CFS3's for the CBM ecozone and species type the forest type maps to (CBM Crosswalk), softwood or hardwood and the deciduous share from Growth Inputs. With FIA measured dead wood, stem turnover comes from FIA's background mortality instead (151 package rows, per forest type and, where FIA has enough plots, per ecodivision)."),
                Note("Empty page: every rate as shown below. Type a value in This row to replace one rate for the forest type, in all ecodivisions or in the one picked; clear it to go back. An ecodivision row wins over the all-ecodivisions row, rate by rate."),
                pick, m_map, m_grid, m_state)));
            var c2 = Column();
            c2.Controls.Add(Wrapped("Every row of the sheet. A row with rates for several forest types or ecodivisions can be edited here too; the table above shows how they combine.", 720));
            c2.Controls.Add(m_all);
            AddGroup(Group("All rows", c2));
            EndGroups();
            m_type.SelectedIndexChanged += (s, e) => { if (!Refreshing) RefreshControls(); };
            m_eco.SelectedIndexChanged += (s, e) => { if (!Refreshing) RefreshControls(); };
            // apply an edit after the grid has finished with it (rewriting the rows inside its own event is a reentrant call)
            m_grid.CellEndEdit += (s, e) =>
            {
                if (Refreshing || e.ColumnIndex != m_grid.Columns["Row"].Index) return;
                string col = Convert.ToString(m_grid.Rows[e.RowIndex].Tag), text = Convert.ToString(m_grid.Rows[e.RowIndex].Cells["Row"].Value);
                this.BeginInvoke(new Action(() => Edit(col, text)));
            };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadTables();
            var types = CarbonPages.ForestTypes(Sheet);
            m_type.Items.Clear(); foreach (var t in types) m_type.Items.Add(new Item { Key = t.Key, Name = t.Value.Replace("Forest: ", "") });
            m_eco.Items.Clear(); m_eco.Items.Add(new Item { Key = null, Name = "All ecodivisions" });
            foreach (var kv in CarbonPages.Names(Sheet, "StratumId").OrderBy(x => x.Value)) m_eco.Items.Add(new Item { Key = kv.Key, Name = kv.Value });
            if (m_type.Items.Count > 0) m_type.SelectedIndex = 0;
            m_eco.SelectedIndex = 0;
            LoadGrid(m_all, SheetName);
            RefreshControls();
        }

        // ---- the package tables ---------------------------------------------------------------------------------------------
        private static Dictionary<string, Dictionary<string, double>> Table(string file, string key)
        {
            List<string[]> rows = Defaults.ReadCsv(Defaults.PackageFile("defaults", "cbm", file));
            var d = new Dictionary<string, Dictionary<string, double>>(StringComparer.OrdinalIgnoreCase);
            int k = Array.IndexOf(rows[0], key);
            foreach (string[] r in rows.Skip(1))
            {
                var v = new Dictionary<string, double>();
                for (int j = 0; j < rows[0].Length && j < r.Length; j++) { double x; if (double.TryParse(r[j], NumberStyles.Float, CultureInfo.InvariantCulture, out x)) v[rows[0][j]] = x; }
                d[r[k].Trim()] = v;
            }
            return d;
        }

        private static void LoadTables()
        {
            if (s_eco != null) return;
            s_eco = Table("tblEcoBoundaryDefault.csv", "EcoBoundaryName");
            s_species = Table("tblSpeciesTypeDefault.csv", "SpeciesTypeName");
            s_cbmMap = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            List<string[]> cw = Defaults.ReadCsv(Defaults.PackageFile("defaults", "cbm", "species-crosswalk.csv"));
            foreach (string[] r in cw.Skip(1)) s_cbmMap[r[0].Trim()] = new[] { r[1].Trim(), r[3].Trim() };
            s_growth = new Dictionary<string, KeyValuePair<bool, double>>(StringComparer.OrdinalIgnoreCase);
            var lag = Defaults.ReadCsv(Defaults.PackageFile("defaults", "growth", "forest-type-crosswalk.csv")).Skip(1).ToDictionary(r => r[1].Trim(), r => r[3].Trim().EndsWith("Softwood"));
            foreach (string[] r in Defaults.ReadCsv(Defaults.PackageFile("defaults", "growth", "merch-carbon-density.csv")).Skip(1))
            {
                bool sw; double dec;
                if (lag.TryGetValue(r[1].Trim(), out sw) && double.TryParse(r[6], NumberStyles.Float, CultureInfo.InvariantCulture, out dec)) s_growth["Forest: " + r[1].Trim()] = new KeyValuePair<bool, double>(sw, dec);
            }
            s_fia = Defaults.ReadCsv(Defaults.PackageFile("defaults", "carbon-assumptions", "fia-measured", "live-turnover.csv"));
        }

        // ---- what stage 3 uses -------------------------------------------------------------------------------------------------
        private Item Type { get { return m_type.SelectedItem as Item; } }
        private Item Eco { get { return m_eco.SelectedItem as Item; } }

        // the CBM ecozone and species type of a forest type in an ecodivision: CBM Crosswalk's row (ecodivision, else all), else the package's
        private string[] CbmMap(int? eco, int type, string typeName)
        {
            DataSheet cx = this.DataFeed.GetDataSheet("lucasCore_CbmCrosswalk");
            if (cx != null && cx.HasData())
            {
                DataRow r = (eco.HasValue ? CarbonPages.Find(cx, eco, type) : null) ?? CarbonPages.Find(cx, null, type);
                if (r == null) return null;
                var ez = CarbonPages.Names(cx, "CbmEcozoneId"); var sp = CarbonPages.Names(cx, "CbmSpeciesTypeId"); string a, b;
                return new[] { ez.TryGetValue(Convert.ToInt32(r["CbmEcozoneId"]), out a) ? a : "?", sp.TryGetValue(Convert.ToInt32(r["CbmSpeciesTypeId"]), out b) ? b : "?" };
            }
            string[] m; return s_cbmMap.TryGetValue(typeName, out m) ? m : null;
        }

        // softwood and deciduous share: Growth Inputs' row, else the package's
        private KeyValuePair<bool, double>? Growth(int type, string typeName)
        {
            DataSheet gi = this.DataFeed.GetDataSheet("lucasCore_GrowthInput");
            DataRow r = CarbonPages.Rows(gi).FirstOrDefault(x => x["StateClassId"] != DBNull.Value && Convert.ToInt32(x["StateClassId"]) == type);
            if (r != null && r["GrowthClass"] != DBNull.Value && r["DeciduousShare"] != DBNull.Value)
            { int g = Convert.ToInt32(r["GrowthClass"]); return new KeyValuePair<bool, double>(g == 1 || g == 3, Convert.ToDouble(r["DeciduousShare"])); }
            KeyValuePair<bool, double> p; return s_growth.TryGetValue(typeName, out p) ? p : (KeyValuePair<bool, double>?)null;
        }

        // CBM's ten rates (src/flows.R cbm_turnover_rates, with the root splits at 0.5)
        private static Dictionary<string, double> Cbm(string[] map, bool softwood, double deciduous)
        {
            Dictionary<string, double> e, s;
            if (map == null || !s_eco.TryGetValue(map[0], out e) || !s_species.TryGetValue(map[1], out s)) return null;
            string sw = softwood ? "Softwood" : "Hardwood";
            return new Dictionary<string, double> {
                { "FoliageTurnover", deciduous * e["HardwoodFoliageFallRate"] + (1 - deciduous) * e["SoftwoodFoliageFallRate"] },
                { "BranchTurnover", e[sw + "BranchTurnOverRate"] }, { "BranchToSnag", s["BranchesToBranchSnag"] }, { "StemTurnover", e["StemAnnualTurnOverRate"] },
                { "FineRootTurnover", s["FineRootTurnPropSlope"] }, { "FineRootToAG", 0.5 }, { "CoarseRootTurnover", s["CoarseRootTurnProp"] }, { "CoarseRootToAG", 0.5 },
                { "StemSnagFall", e[sw + "StemSnagToDOM"] }, { "BranchSnagFall", e[sw + "BranchSnagToDOM"] } };
        }

        // the package FIA rows as (ecodivision id or null, type id) -> column -> value, for the names this library defines
        private Dictionary<string, Dictionary<string, double>> PackageRows()
        {
            var d = new Dictionary<string, Dictionary<string, double>>();
            Dictionary<string, int> eco = CarbonPages.Ids(Sheet, "StratumId"), type = CarbonPages.Ids(Sheet, "StateClassId");
            string[] head = s_fia[0];
            foreach (string[] r in s_fia.Skip(1))
            {
                int t, e = 0; bool all = r[0].Trim().Length == 0;
                if (!type.TryGetValue(r[1].Trim(), out t) || (!all && !eco.TryGetValue(r[0].Trim(), out e))) continue;
                var v = new Dictionary<string, double>();
                for (int j = 2; j < head.Length && j < r.Length; j++) { double x; if (double.TryParse(r[j], NumberStyles.Float, CultureInfo.InvariantCulture, out x)) v[head[j]] = x; }
                d[Key(all ? (int?)null : e, t)] = v;
            }
            return d;
        }
        private static string Key(int? eco, int type) { return (eco.HasValue ? eco.Value.ToString() : "") + "|" + type; }

        // ---- editing ---------------------------------------------------------------------------------------------------------
        private void Edit(string column, string text)
        {
            if (Type == null || !Type.Key.HasValue || column == null) return;
            double? v = CarbonPages.Parse(text);
            if (text.Trim().Length > 0 && (!v.HasValue || v < 0 || v > 1)) { m_note = "Not a rate between 0 and 1: " + text.Trim(); RefreshControls(); return; }
            // an empty sheet means the package's FIA rows; a sheet with rows uses only its rows, so they are written first
            if (!Sheet.HasData() && CarbonPages.Method(this.DataFeed) == 4)
            {
                List<string> p = Defaults.Load(Sheet, Defaults.PackageFile("defaults", "carbon-assumptions", "fia-measured", "live-turnover.csv"), null);
                m_note = "The page was empty, which means the package's FIA stem turnover rows; they were written first so they still apply" + (p.Count > 0 ? string.Format(" ({0} could not be matched)", p.Count) : "") + ". ";
            }
            CarbonPages.SetValue(Sheet, Eco == null ? null : Eco.Key, Type.Key.Value, column, v.HasValue ? (object)v.Value : DBNull.Value, Columns);
            LoadGrid(m_all, SheetName);
            RefreshControls();
        }

        // ---- the table -------------------------------------------------------------------------------------------------------
        protected override void ShowData()
        {
            m_grid.Rows.Clear();
            Item t = Type, e = Eco;
            if (t == null || !t.Key.HasValue) { m_map.Text = "No forest types in this library."; return; }
            int type = t.Key.Value; int? eco = e == null ? null : e.Key; string typeName = "Forest: " + t.Name;
            string[] map = CbmMap(eco, type, typeName);
            KeyValuePair<bool, double>? g = Growth(type, typeName);
            Dictionary<string, double> cbm = g.HasValue ? Cbm(map, g.Value.Key, g.Value.Value) : null;
            m_map.Text = map == null || !g.HasValue ? "This forest type has no CBM Crosswalk or Growth Inputs entry." :
                string.Format("CBM ecozone {0}, species type {1}; {2}, deciduous share {3:0.00}", map[0], map[1], g.Value.Key ? "softwood" : "hardwood", g.Value.Value);

            bool method4 = CarbonPages.Method(this.DataFeed) == 4, empty = !Sheet.HasData();
            Dictionary<string, Dictionary<string, double>> pkg = method4 ? PackageRows() : new Dictionary<string, Dictionary<string, double>>();
            // the rows stage 3 reads: the sheet's, or the package's when the sheet is empty
            Func<int?, Dictionary<string, double>> rowOf = k =>
            {
                if (empty) { Dictionary<string, double> p; return pkg.TryGetValue(Key(k, type), out p) ? p : null; }
                DataRow r = CarbonPages.Find(Sheet, k, type);
                return r == null ? null : Columns.Where(c => r[c] != DBNull.Value).ToDictionary(c => c, c => Convert.ToDouble(r[c]));
            };
            Dictionary<string, double> own = eco.HasValue ? rowOf(eco) : null, all = rowOf(null);
            DataRow exact = empty ? null : CarbonPages.Find(Sheet, eco, type);
            string where = eco.HasValue ? e.Name : "all ecodivisions";
            double? stemFall = null; bool stemFallSet = false;
            foreach (string[] rate in Rates)
            {
                string c = rate[0]; double x; double? used = null; string from;
                Func<int?, Dictionary<string, double>, string> label = (k, row) =>
                {
                    Dictionary<string, double> p; bool isPkg = pkg.TryGetValue(Key(k, type), out p) && p.ContainsKey(c) && Math.Abs(p[c] - row[c]) < 1e-9;
                    string at = k.HasValue ? e.Name : "all ecodivisions";
                    return isPkg ? "FIA background mortality (" + at + (empty ? ", package" : "") + ")" : "your value (" + at + " row)";
                };
                if (own != null && own.TryGetValue(c, out x)) { used = x; from = label(eco, own); }
                else if (all != null && all.TryGetValue(c, out x)) { used = x; from = label(null, all); }
                else if (cbm != null) { used = cbm[c]; from = c.EndsWith("ToAG") ? "LUCAS default (half and half)" : string.Format("CBM ({0}, {1})", map[1], map[0]); }
                else from = "";
                if (c == "StemSnagFall") { stemFall = used; stemFallSet = from.StartsWith("your") || from.StartsWith("FIA"); }
                // a stem snag fall set without a branch one: branch snags fall faster in proportion (src/flows.R turnover_rates)
                if (c == "BranchSnagFall" && from.StartsWith("CBM") && stemFallSet && cbm != null && stemFall.HasValue)
                { used = cbm[c] * stemFall.Value / cbm["StemSnagFall"]; from = "CBM, scaled with the stem snag fall"; }
                int i = m_grid.Rows.Add(rate[1], CarbonPages.Format(used, rate[2]), from, exact == null ? "" : CarbonPages.Format(CarbonPages.Num(exact[c]), rate[2]));
                m_grid.Rows[i].Tag = c;
                if (from.StartsWith("your")) m_grid.Rows[i].Cells["Used"].Style.Font = new Font(m_grid.Font, FontStyle.Bold);
            }
            m_grid.Columns["Row"].HeaderText = "This row: " + where + " (blank = not set)";
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_grid.Columns["Row"].ReadOnly = !edit;
            int n = CarbonPages.Rows(Sheet).Count;
            m_state.Text = m_note + (n == 0 ? (method4 ? "The sheet is empty: the Build uses CBM's rates with FIA's stem turnover (the package rows), as shown." : "The sheet is empty: the Build uses CBM's rates, as shown.")
                                         : string.Format("{0} row{1} in the sheet; only these apply on top of CBM's rates.", n, n == 1 ? "" : "s"));
            m_note = "";
        }
    }
}
