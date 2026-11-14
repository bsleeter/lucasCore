// =============================================================================
// ManagementActionsView.cs - Management Actions: replanting, site preparation and salvage logging after a disturbance (to-do 58)
// =============================================================================
// Sheet lucasCore_ManagementAction (Action, Start and End Year, Area per Year, Secondary and Tertiary Stratum, years since the
// disturbance, Priority, Survival, Site Preparation). Stage 9 turns each row into ST-Sim targets on the disturbed forest classes
// (src/management.R) and stage 10 sets the replanting priority.
// The page walks through each action's choices with their explanation beside them (user 2026-11-13: "having them walk through the
// various parameters with explanations sitting next to their choices is better for clarity"); Add writes the choices as a row of the
// grid below, and can be used again with other choices (another range of years, another unit). The grid is the record of the
// choices, and can still be edited directly.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class ManagementActionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ManagementAction"; } }

        // ---- what the model uses: the Build's strata sources, the units with land in the study area, and the spatial tiles ------
        // Read from the Projection Setup's dependencies as Run Settings does (src/1-study-area.R writes the units with land to Build
        // Results > Strata Summary). With spatial tiles a target must sit inside one tile, so an action names one unit of the tile level
        // (user 2026-11-13: "if using spatial multiprocessing, these area targets ... MUST be specified at the same strata"); stage 9
        // checks the same (src/management.R)
        internal class ModelStrata
        {
            public static readonly string[] Levels = { "Primary", "Secondary", "Tertiary" };
            public static readonly string[] Columns = { "StratumId", "SecondaryStratumId", "TertiaryStratumId" };
            public readonly string[] Source = { "FIA ecodivisions", "States", "Federal Lands" };
            public readonly List<string>[] Units = { new List<string>(), new List<string>(), new List<string>() };   // names with land, by level
            public readonly Dictionary<string, int>[] Keys = { new Dictionary<string, int>(), new Dictionary<string, int>(), new Dictionary<string, int>() };
            public int TileLevel = -1;   // 0-2 with tiles, -1 without
            public bool FromBuild;       // the units come from the Build result's Strata Summary (else none: only (any))

            private static DataRow First(Scenario s, string sheet)
            {
                if (s == null) return null;
                DataSheet ds = s.GetDataSheet(sheet); if (ds == null) return null;
                return ds.GetData().Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted);
            }
            private static DataRow Own(Scenario sc, string sheet)
            {
                DataRow r = First(sc, sheet); if (r != null || sc == null) return r;
                foreach (Scenario d in sc.Dependencies) { r = First(d, sheet); if (r != null) return r; }
                return null;
            }

            public void Load(Project p, Scenario sc)
            {
                DataTable src = p.GetDataSheet("lucasCore_StratumSource").GetData();
                Func<object, string, string> name = (k, d) => { if (k == null || k == DBNull.Value) return d;
                    DataRow r = src.Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted && Convert.ToInt32(x["StratumSourceId"]) == Convert.ToInt32(k)); return r == null ? d : Convert.ToString(r["Name"]); };
                DataRow bo = Own(sc, "lucasCore_BuildOptions");
                if (bo != null) { Source[1] = name(bo["SecondarySourceId"], Source[1]); Source[2] = name(bo["TertiarySourceId"], Source[2]); } else { Source[1] = null; Source[2] = null; }   // (no Build: its sources are not known)
                // tiles: the projection's own (Run Settings), else the Build's; on when 0 (automatic) or more than 1
                DataRow po = First(sc, "lucasCore_ProjectionOptions");
                Func<DataRow, string, object> v = (r, c) => r != null && r.Table.Columns.Contains(c) ? r[c] : DBNull.Value;
                object tiles = v(po, "SpatialTiles") != DBNull.Value ? v(po, "SpatialTiles") : v(bo, "SpatialTiles");
                object lvl = v(po, "SpatialTiles") != DBNull.Value ? v(po, "SpatialTilesStrata") : v(bo, "SpatialTilesStrata");
                bool on = tiles != DBNull.Value && (Convert.ToInt32(tiles) == 0 || Convert.ToInt32(tiles) > 1);
                TileLevel = on ? Math.Max(0, Math.Min(2, (lvl == DBNull.Value ? 2 : Convert.ToInt32(lvl)) - 1)) : -1;
                // keys of every unit by name, at each level
                string[] lists = { "stsim_Stratum", "stsim_SecondaryStratum", "stsim_TertiaryStratum" };
                var ids = new Dictionary<string, long>[] { new Dictionary<string, long>(), new Dictionary<string, long>(), new Dictionary<string, long>() };
                for (int i = 0; i < 3; i++)
                    foreach (DataRow r in Live(p.GetDataSheet(lists[i]).GetData()))
                    { string n = Convert.ToString(r["Name"]); Keys[i][n] = Convert.ToInt32(r[Columns[i]]); if (r["ID"] != DBNull.Value) ids[i][n] = Convert.ToInt64(r["ID"]); }
                // the units with land in the study area (the Build result's Strata Summary); with no Build result, none (user 2026-11-13:
                // the choices offered in this model only, not the national lists)
                DataSheet ss = null;
                if (sc != null) { if (HasRows(sc, "lucasCore_OutputStrataSummary")) ss = sc.GetDataSheet("lucasCore_OutputStrataSummary");
                                  else foreach (Scenario d in sc.Dependencies) if (HasRows(d, "lucasCore_OutputStrataSummary")) { ss = d.GetDataSheet("lucasCore_OutputStrataSummary"); break; } }
                FromBuild = ss != null;
                for (int i = 0; i < 3; i++) Units[i].Clear();
                if (ss != null)
                    foreach (DataRow r in Live(ss.GetData()))
                    { int i = Array.IndexOf(Levels, Convert.ToString(r["Level"])); string n = Convert.ToString(r["Name"]); if (i >= 0 && Keys[i].ContainsKey(n) && !Units[i].Contains(n)) Units[i].Add(n); }
                for (int i = 0; i < 3; i++) Units[i].Sort(StringComparer.CurrentCultureIgnoreCase);
            }

            private static bool HasRows(Scenario s, string sheet) { DataSheet ds = s.GetDataSheet(sheet); return ds != null && ds.HasData(); }
        }

        // ---- where an action applies: a unit at any of the three strata levels, or "(any)" there; all "(any)" = the whole study
        // area (user 2026-11-13: "the management could also be specified by a) the tiling strata and b) the other strata", e.g. County A
        // with Federal Land Type A, then County A with Type B). With spatial tiles the tile level's unit is required ----------------
        internal class WherePicker
        {
            private const string ANY = "(any)";
            public readonly Label[] Captions = new Label[3];
            public readonly ComboBox[] Units = new ComboBox[3];
            public readonly Label Info = Note("");   // the Where line's note: beside the boxes, to the right edge
            private ModelStrata m_ms;

            public WherePicker()
            {
                for (int i = 0; i < 3; i++)
                {
                    Captions[i] = new Label { AutoSize = true, Margin = new Padding(3, 7, 6, 3), Tag = Fit.Fixed };
                    Units[i] = new ComboBox { Width = 260, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3), AutoCompleteMode = AutoCompleteMode.SuggestAppend,
                                              AutoCompleteSource = AutoCompleteSource.ListItems, MaxDropDownItems = 20 };
                }
            }

            public Control Panel()
            {
                var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 2, Margin = new Padding(0) };
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                for (int i = 0; i < 3; i++) { t.RowCount = i + 1; t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.Controls.Add(Captions[i], 0, i); t.Controls.Add(Units[i], 1, i); }
                return t;
            }

            public void Load(ModelStrata ms)
            {
                m_ms = ms;
                for (int i = 0; i < 3; i++)
                {
                    bool req = i == ms.TileLevel;
                    Captions[i].Text = (ms.Source[i] == null ? ModelStrata.Levels[i] : string.Format("{0} ({1})", ModelStrata.Levels[i], ms.Source[i])) + (req ? ", required:" : ":");
                    ComboBox c = Units[i]; c.BeginUpdate(); c.Items.Clear(); if (!req) c.Items.Add(ANY);
                    foreach (string n in ms.Units[i]) c.Items.Add(n);
                    c.EndUpdate(); c.Text = ""; if (!req) c.SelectedIndex = 0;
                }
                Info.Text = (ms.TileLevel >= 0
                    ? string.Format("Required: a {0} unit (the projection runs in {0} tiles); the other levels are optional.", ms.Source[ms.TileLevel])
                    : "(any) everywhere = the whole study area; or name a unit at one or more levels, e.g. a county and a federal owner in it.")
                    + (ms.FromBuild ? " Lists: units with land in the study area." : " To choose units, run the Build and set its result as this Projection Setup's dependency; until then only (any), the whole study area.");
            }

            // the row's stratum columns, or an error message
            public string Apply(DataRow nr)
            {
                for (int i = 0; i < 3; i++)
                {
                    string col = ModelStrata.Columns[i]; if (nr.Table.Columns.Contains(col)) nr[col] = DBNull.Value;
                    string txt = Units[i].Text.Trim();
                    if (txt.Length == 0 || txt == ANY)
                    { if (i == m_ms.TileLevel) return m_ms.FromBuild ? string.Format("choose a {0} unit (the projection's tiles need one)", m_ms.Source[i]) : "the projection runs in tiles, so each action needs a unit: run the Build and set its result as this Projection Setup's dependency first"; continue; }
                    string n = m_ms.Units[i].FirstOrDefault(x => string.Equals(x, txt, StringComparison.OrdinalIgnoreCase));
                    if (n == null) return string.Format("{0} is not a {1} unit with land in the study area", txt, m_ms.Source[i]);
                    if (!nr.Table.Columns.Contains(col)) return "this library's Management Actions sheet has no " + ModelStrata.Levels[i] + " column (update the package)";
                    nr[col] = m_ms.Keys[i][n];
                }
                return null;
            }
        }

        // ---- one action's form ----------------------------------------------------------------------------------------------
        private class ActionForm
        {
            public readonly TextBox Start = Box(60), End = Box(60), Area = Box(80), From = Box(40), To = Box(40), Survival = Box(50), Cost = Box(70), PrepCost = Box(70), Revenue = Box(70), Budget = Box(90);
            public readonly ComboBox Priority = List(330), Prep = List(250), Range = List(280);
            public readonly WherePicker Where = new WherePicker();
            public readonly Button Add;
            public readonly Label Said = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
            public ActionForm(string addText) { Add = new Button { Text = addText, AutoSize = true, Margin = new Padding(3, 6, 6, 3) }; }
        }

        private readonly ActionForm m_rep = new ActionForm("Add replanting");
        private readonly ActionForm m_sal = new ActionForm("Add salvage logging");
        // costs (user 2026-11-13: "start with costs per hectare and research defaults"; ranges: "Transition Attribute Values ... can
        // also hold a distribution of cost values"): USD per hectare. A blank box = the package default of the cell's cost region
        // (defaults/management/costs.csv, each ecodivision's region in cost-regions.csv), applied by stage 9; a value typed in is the
        // row's own. The notes show the defaults of the model's region (with several regions in the study area, the national ones)
        private const string UNIT = "hectare";
        private readonly Label m_repCostNote = Note(""), m_salCostNote = Note("");
        private readonly Dictionary<string, double[]> m_cost = new Dictionary<string, double[]>();   // "region|item" -> central, low, high
        private readonly Dictionary<string, string> m_regionOf = new Dictionary<string, string>();   // ecodivision -> cost region
        private string m_costYear = "", m_region = "All", m_regionNote = "";
        private void LoadCosts()
        {
            m_cost.Clear(); m_regionOf.Clear();
            try
            {
                List<string[]> rows = Defaults.ReadCsv(Defaults.PackageFile("defaults", "management", "costs.csv"));
                int ir = Array.IndexOf(rows[0], "Region"), ii = Array.IndexOf(rows[0], "Item"), ic = Array.IndexOf(rows[0], "Central"), il = Array.IndexOf(rows[0], "Low"), ih = Array.IndexOf(rows[0], "High"), iy = Array.IndexOf(rows[0], "DollarYear");
                Func<string[], int, double> d = (r, k) => { double v; return k >= 0 && r.Length > k && double.TryParse(r[k], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out v) ? v : double.NaN; };
                foreach (string[] r in rows.Skip(1))
                {
                    if (r.Length <= Math.Max(ir, ii)) continue;
                    m_cost[r[ir].Trim() + "|" + r[ii].Trim()] = new[] { d(r, ic), d(r, il), d(r, ih) };
                    if (iy >= 0 && r.Length > iy && m_costYear.Length == 0) m_costYear = r[iy];
                }
                List<string[]> reg = Defaults.ReadCsv(Defaults.PackageFile("defaults", "management", "cost-regions.csv"));
                foreach (string[] r in reg.Skip(1)) if (r.Length > 1) m_regionOf[r[0].Trim()] = r[1].Trim();
            }
            catch (Exception) { }
        }
        // the study area's cost region: one region for all its ecodivisions, else the national defaults (stage 9 applies each one's)
        private void SetRegions(List<string> ecodivisions)
        {
            var regs = ecodivisions.Select(e => m_regionOf.ContainsKey(e) ? m_regionOf[e] : "All").Distinct().ToList();
            m_region = regs.Count == 1 ? regs[0] : "All";
            m_regionNote = regs.Count == 1 ? (m_region == "All" ? "" : " (" + m_region + ")") : regs.Count > 1 ? " (national; this study area spans " + string.Join(", ", regs) + ", each ecodivision gets its own)" : "";
            CostNotes();
        }
        private double[] Cost(string item) { double[] v; return m_cost.TryGetValue(m_region + "|" + item, out v) || m_cost.TryGetValue("All|" + item, out v) ? v : null; }
        private string CostText(string item)
        {
            double[] v = Cost(item); if (v == null) return "?";
            Func<double, string> f = x => x.ToString("#,0", System.Globalization.CultureInfo.InvariantCulture);
            return string.Format("{0} ({1}-{2})", f(v[0]), f(v[1]), f(v[2]));
        }
        private static readonly string[] PREP_ITEM = { null, "Site preparation: Pile and burn", "Site preparation: Mechanical" };
        private void ShowPrepCost() { int p = m_rep.Prep.SelectedIndex; m_rep.PrepCost.Enabled = p > 0; if (p <= 0) m_rep.PrepCost.Text = ""; }
        private void CostNotes()
        {
            string yr = m_costYear.Length > 0 ? m_costYear + " " : "";
            m_repCostNote.Text = string.Format("Blank = default{0}, {1}USD: planting {2}, pile and burn {3}, mechanical {4}. Paid on failed plantings too. Provisional.", m_regionNote, yr, CostText("Planting"), CostText(PREP_ITEM[1]), CostText(PREP_ITEM[2]));
            m_salCostNote.Text = string.Format("Blank = default{0}, {1}USD: logging and haul {2}; revenue {3} in the fire year, 25% less each year after. Provisional.", m_regionNote, yr, CostText("Salvage logging"), CostText("Salvage timber revenue"));
        }
        private readonly Panel m_grid = GridHost(200);
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Label m_rows = new Label { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(3, 4, 3, 6) };

        // a parameter line: a fixed-width caption, the control, then its note, which Fit widens to the page's right edge
        internal static FlowLayoutPanel Line(string caption, Control c, Label note)
        {
            var r = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 0, 0, 4) };
            r.Controls.Add(new Label { Text = caption, AutoSize = false, Size = new Size(150, 24), Margin = new Padding(3, 6, 3, 0), Tag = Fit.Fixed });
            r.Controls.Add(c);
            if (note != null) { note.Margin = new Padding(10, 6, 3, 3); r.Controls.Add(note); }
            return r;
        }
        internal static FlowLayoutPanel Lines(params Control[] lines) { var c = Column(); foreach (Control l in lines) c.Controls.Add(l); return c; }
        private static FlowLayoutPanel ActionRow(ActionForm a) { var r = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(150, 2, 0, 0) }; r.Controls.Add(a.Add); r.Controls.Add(a.Said); return r; }

        internal static FlowLayoutPanel Pair(TextBox a, string mid, TextBox b, string after)
        {
            var r = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0) };   // (not a wrapping row: Fit would widen it to the page and squeeze the notes column)
            a.Margin = new Padding(3, 3, 3, 3); b.Margin = new Padding(3, 3, 3, 3);
            r.Controls.Add(a); r.Controls.Add(new Label { Text = mid, AutoSize = true, Margin = new Padding(3, 7, 3, 3) }); r.Controls.Add(b);
            if (after != null) r.Controls.Add(new Label { Text = after, AutoSize = true, Margin = new Padding(3, 7, 3, 3) });
            return r;
        }

        public ManagementActionsView()
        {
            this.SuspendLayout();
            AddGroup(Group("What management does in a projection", ProjectionTransitionsView.Stack(
                Note("Management acts on forest a high-severity fire has put into its disturbed class, while it waits to return or convert. Set an action below and add it; add it again for other years or places. No rows = the baseline. Areas are on top of the historical rate (the fitted natural return already includes past planting)."))));

            // replanting: caption, control, then its note to the right edge
            AddGroup(Group("Replanting", Lines(
                Line("Years:", Pair(m_rep.Start, "to", m_rep.End, null), Note("Blank = from the projection start, or to its end.")),
                Line("Area per year:", m_rep.Area, Note("In the library's units (hectares). Less is planted when less land is eligible; the run reports what was done.")),
                Line("Or a budget:", m_rep.Budget, Note("USD a year instead of an area (leave the area blank): the area it pays for at the central cost per hectare, planting + site preparation.")),
                Line("Where:", m_rep.Where.Panel(), m_rep.Where.Info),
                Line("Years since disturbance:", Pair(m_rep.From, "to", m_rep.To, null), Note("Ages a disturbed cell can be planted (0 = the fire year). Default 1-5, before shrubs and grass take the site.")),
                Line("Survival:", m_rep.Survival, Note("Share that takes: back to its own forest type at age 0. The rest stays disturbed and can still return or convert. Default 0.8.")),
                Line("Priority:", m_rep.Priority, Note("Random, or first where natural return is least likely (far from live forest). One priority for all replanting rows.")),
                Line("Site preparation:", m_rep.Prep, Note("Carbon on the planted area. Pile and burn: cover burned (96% emitted), roots die, half the litter and fine woody debris and 30% of branch snags burn. Mechanical: cover to litter and fine woody debris, roots die. Provisional.")),
                Line("Cost per " + UNIT + ":", Pair(m_rep.Cost, "planting +", m_rep.PrepCost, "site preparation"), m_repCostNote),
                Line("Cost range:", m_rep.Range, Note("Default: each cost a Beta over its low-high range, drawn once per iteration; run several iterations to see the spread. Fixed: the values alone.")),
                ActionRow(m_rep))));

            // salvage
            AddGroup(Group("Salvage logging", Lines(
                Line("Years:", Pair(m_sal.Start, "to", m_sal.End, null), Note("Blank = from the projection start, or to its end.")),
                Line("Area per year:", m_sal.Area, Note("In the library's units (hectares). Takes mostly snags to the forestry sector; the cell stays disturbed with its age.")),
                Line("Or a budget:", m_sal.Budget, Note("USD a year instead of an area (leave the area blank): the area it pays for at the central logging cost per hectare.")),
                Line("Where:", m_sal.Where.Panel(), m_sal.Where.Info),
                Line("Years since disturbance:", Pair(m_sal.From, "to", m_sal.To, null), Note("Soon after the fire, before the snags lose value. Default 0-2.")),
                Line("Per " + UNIT + ":", Pair(m_sal.Cost, "logging cost,", m_sal.Revenue, "timber revenue"), m_salCostNote),
                Line("Cost range:", m_sal.Range, Note("As for replanting. Net = revenue - cost, in the transition attribute outputs.")),
                ActionRow(m_sal))));

            // the rows
            var r = Row(); r.Controls.Add(m_clear); r.Controls.Add(m_state);
            AddGroup(Group("Actions (what the Projection Setup uses)", ProjectionTransitionsView.Stack(m_rows, m_grid, r,
                Wrapped("Edit here directly if you like. Projection Results > Management Actions (as set up) lists what each row became.", 760))));
            EndGroups();

            m_rep.Priority.Items.AddRange(new object[] { "None (random among eligible cells)", "Far from live forest (least likely to return on its own)" });
            m_rep.Prep.Items.AddRange(new object[] { "None", "Pile and burn", "Mechanical (mastication)" });
            foreach (ComboBox c in new[] { m_rep.Range, m_sal.Range }) c.Items.AddRange(new object[] { "Default ranges (sampled per iteration)", "Fixed values" });
            LoadCosts(); FillDefaults(); CostNotes();
            m_rep.Prep.SelectedIndexChanged += (s, e) => ShowPrepCost();
            m_rep.Add.Click += (s, e) => AddRow(1, m_rep);
            m_sal.Add.Click += (s, e) => AddRow(2, m_sal);
            m_clear.Click += (s, e) => ClearAll();
            this.ResumeLayout(false);
        }

        private void FillDefaults()
        {
            m_rep.Area.Text = "100"; m_rep.Budget.Text = ""; m_rep.From.Text = "1"; m_rep.To.Text = "5"; m_rep.Survival.Text = "0.8"; m_rep.Priority.SelectedIndex = 0; m_rep.Prep.SelectedIndex = 0;
            m_sal.Area.Text = "100"; m_sal.From.Text = "0"; m_sal.To.Text = "2";
            m_rep.Range.SelectedIndex = 0; m_sal.Range.SelectedIndex = 0; ShowPrepCost();
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            Project p = this.Scenario != null ? this.Scenario.Project : this.DataFeed.Project;
            if (p != null) { var ms = new ModelStrata(); try { ms.Load(p, this.Scenario); } catch (Exception) { } m_rep.Where.Load(ms); m_sal.Where.Load(ms); SetRegions(ms.Units[0]); }
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }

        // a blank box is DBNull; a bad entry is an error message
        private static string ReadNumber(TextBox t, string what, bool integer, bool required, double min, double max, out object value)
        {
            value = DBNull.Value; string v = t.Text.Trim(); double d;
            if (v.Length == 0) return required ? what + " is needed" : null;
            if (!double.TryParse(v, out d) || (integer && d != Math.Floor(d)) || d < min || d > max) return string.Format("{0} must be {1} from {2} to {3}", what, integer ? "a whole number" : "a number", min, max);
            value = integer ? (object)Convert.ToInt32(d) : d; return null;
        }

        // the form's choices as a new row of the grid
        private void AddRow(int action, ActionForm a)
        {
            bool rep = action == 1; object start = DBNull.Value, end = DBNull.Value, area = DBNull.Value, from = DBNull.Value, to = DBNull.Value, surv = DBNull.Value, budget = DBNull.Value;
            string err = ReadNumber(a.Start, "the start year", true, false, 1900, 2200, out start) ?? ReadNumber(a.End, "the end year", true, false, 1900, 2200, out end)
                      ?? ReadNumber(a.Budget, "the budget", false, false, 0, 1e13, out budget) ?? ReadNumber(a.Area, "the area per year", false, a.Budget.Text.Trim().Length == 0, 0, 1e12, out area) ?? ReadNumber(a.From, "the first year since the disturbance", true, false, 0, 500, out from)
                      ?? ReadNumber(a.To, "the last year since the disturbance", true, false, 0, 500, out to)
                      ?? (rep ? ReadNumber(a.Survival, "survival", false, false, 0, 1, out surv) : null);
            if (err == null && start != DBNull.Value && end != DBNull.Value && (int)start > (int)end) err = "the start year is after the end year";
            if (err == null && area != DBNull.Value && budget != DBNull.Value) err = "give an area or a budget, not both";
            if (err == null && from != DBNull.Value && to != DBNull.Value && (int)from > (int)to) err = "the window runs backwards";
            DataTable dt = Sheet.GetData(); DataRow nr = dt.NewRow();
            if (err == null) err = a.Where.Apply(nr);
            if (err != null) { a.Said.ForeColor = Color.Firebrick; a.Said.Text = "Not added: " + err + "."; return; }
            nr["ActionId"] = action; nr["StartYear"] = start; nr["EndYear"] = end; nr["Amount"] = area; nr["MinAge"] = from; nr["MaxAge"] = to;
            if (nr.Table.Columns.Contains("Budget")) nr["Budget"] = budget; else if (budget != DBNull.Value) { a.Said.ForeColor = Color.Firebrick; a.Said.Text = "Not added: this library has no Budget column (update the package)."; return; }
            if (rep) { nr["Survival"] = surv; nr["Priority"] = a.Priority.SelectedIndex + 1; nr["SitePreparation"] = a.Prep.SelectedIndex + 1; }
            object cost = DBNull.Value, pcost = DBNull.Value, rev = DBNull.Value; string ce = ReadNumber(a.Cost, "the cost", false, false, 0, 1e9, out cost);
            if (ce == null && rep && a.Prep.SelectedIndex > 0) ce = ReadNumber(a.PrepCost, "the site preparation cost", false, false, 0, 1e9, out pcost);
            if (ce == null && !rep) ce = ReadNumber(a.Revenue, "the timber revenue", false, false, 0, 1e9, out rev);
            if (ce != null) { a.Said.ForeColor = Color.Firebrick; a.Said.Text = "Not added: " + ce + "."; return; }
            if (nr.Table.Columns.Contains("Cost")) nr["Cost"] = cost;
            if (nr.Table.Columns.Contains("SitePrepCost")) nr["SitePrepCost"] = pcost;
            if (nr.Table.Columns.Contains("Revenue")) nr["Revenue"] = rev;
            if (nr.Table.Columns.Contains("CostRange")) nr["CostRange"] = a.Range.SelectedIndex == 1 ? 2 : 1;
            Sheet.BeginAddRows();
            try { dt.Rows.Add(nr); }
            finally { Sheet.EndAddRows(); }
            a.Said.ForeColor = SystemColors.GrayText; a.Said.Text = "Added as row " + Live(dt).Count() + ". Change any setting and add again for other years or another place.";
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void ClearAll()
        {
            List<DataRow> rows = Live(Sheet.GetData()).ToList();
            if (rows.Count == 0) return;
            if (MessageBox.Show(this, "Remove every management action, so the projection is the baseline?", "Management Actions", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Sheet.DeleteRows(rows);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        // the display text of a lookup column's value (stratum units)
        private string Lookup(string column, object v)
        {
            if (v == DBNull.Value || v == null) return null;
            DataSheetColumn col = Sheet.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (col == null || col.ValidationTable == null) return Convert.ToString(v);
            foreach (DataRow r in Live(col.ValidationTable.DataSource))
                if (Convert.ToString(r[col.ValidationTable.ValueMember]) == Convert.ToString(v)) return Convert.ToString(r[col.ValidationTable.DisplayMember]);
            return Convert.ToString(v);
        }

        private static string Num(object v, string blank) { return v == DBNull.Value || v == null ? blank : Convert.ToDouble(v).ToString("0.##"); }
        private static int Int(object v, int blank) { return v == DBNull.Value || v == null ? blank : Convert.ToInt32(v); }

        // one line per row, in words
        private string Describe(DataRow r, int i)
        {
            int act = Int(r["ActionId"], 0);
            if (act != 1 && act != 2) return string.Format("{0}. (no action chosen)", i);
            bool rep = act == 1;
            string where = string.Join(" / ", ModelStrata.Columns.Where(c => r.Table.Columns.Contains(c)).Select(c => Lookup(c, r[c])).Where(x => x != null));
            string years = r["StartYear"] == DBNull.Value && r["EndYear"] == DBNull.Value ? "every projection year"
                         : string.Format("{0} to {1}", Num(r["StartYear"], "the first projection year"), Num(r["EndYear"], "the end"));
            string amt = r["Amount"] == DBNull.Value && r.Table.Columns.Contains("Budget") && r["Budget"] != DBNull.Value ? Convert.ToDouble(r["Budget"]).ToString("#,0") + " USD" : Num(r["Amount"], "?");
            string s = string.Format("{0}. {1} {2} a year, {3}, in {4}, {5}-{6} years after the disturbance", i, rep ? "Replant" : "Salvage", amt, years,
                                     where.Length > 0 ? where : "the whole study area", Int(r["MinAge"], rep ? 1 : 0), Int(r["MaxAge"], rep ? 5 : 2));
            if (rep)
            {
                double sv = r["Survival"] == DBNull.Value ? 0.8 : Convert.ToDouble(r["Survival"]);
                int prep = Int(r["SitePreparation"], 1), pri = Int(r["Priority"], 1);
                s += string.Format("; {0:0}% takes{1}{2}", 100 * sv, prep == 2 ? ", after pile and burn" : prep == 3 ? ", after mechanical site preparation" : ", no site preparation",
                                   pri == 2 ? ", far from live forest first" : ", at random");
            }
            Func<string, string> val = c => r.Table.Columns.Contains(c) && r[c] != DBNull.Value ? Num(r[c], "") : null;
            var money = new List<string>();
            if (val("Cost") != null) money.Add((rep ? "planting " : "logging ") + val("Cost"));
            if (rep && val("SitePrepCost") != null) money.Add("site preparation " + val("SitePrepCost"));
            if (!rep && val("Revenue") != null) money.Add("timber revenue " + val("Revenue"));
            bool fixedC = r.Table.Columns.Contains("CostRange") && Int(r["CostRange"], 1) == 2;
            s += money.Count > 0 ? string.Format("; USD per {0}: {1}", UNIT, string.Join(", ", money)) + (fixedC ? ", fixed" : "") + " (the rest: regional defaults)" : "; regional default costs" + (fixedC ? ", fixed" : "");
            return s + ".";
        }

        protected override void ShowData()
        {
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            List<DataRow> rows = Sheet.HasData() ? Live(Sheet.GetData()).ToList() : new List<DataRow>();
            m_rep.Add.Enabled = m_sal.Add.Enabled = edit; m_clear.Enabled = edit && rows.Count > 0;
            m_state.Text = rows.Count == 0 ? "No actions: the projection is the baseline." : string.Format("{0} action{1}.", rows.Count, rows.Count == 1 ? "" : "s");
            int pri = rows.Where(x => Int(x["ActionId"], 0) == 1).Select(x => Int(x["Priority"], 1)).Distinct().Count();
            m_rows.Text = rows.Count == 0 ? "No actions yet." : string.Join(Environment.NewLine, rows.Select((x, i) => Describe(x, i + 1)))
                        + (pri > 1 ? Environment.NewLine + "Every replanting row needs the same priority: the setup stops otherwise." : "");
        }
    }
}
