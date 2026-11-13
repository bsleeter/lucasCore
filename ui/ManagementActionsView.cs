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
        private class ModelStrata
        {
            public static readonly string[] Levels = { "Primary", "Secondary", "Tertiary" };
            public static readonly string[] Columns = { "StratumId", "SecondaryStratumId", "TertiaryStratumId" };
            public readonly string[] Source = { "FIA ecodivisions", "States", "Federal Lands" };
            public readonly List<string>[] Units = { new List<string>(), new List<string>(), new List<string>() };   // names with land, by level
            public readonly Dictionary<string, int>[] Keys = { new Dictionary<string, int>(), new Dictionary<string, int>(), new Dictionary<string, int>() };
            public int TileLevel = -1;   // 0-2 with tiles, -1 without
            public bool FromBuild;       // the units come from the Build's Strata Summary (else every unit of the source)

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
                Func<string, int> number = n => { DataRow r = src.Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted && Convert.ToString(x["Name"]) == n);
                    return r == null || r["Number"] == DBNull.Value ? -1 : Convert.ToInt32(r["Number"]); };
                DataRow bo = Own(sc, "lucasCore_BuildOptions");
                if (bo != null) { Source[1] = name(bo["SecondarySourceId"], Source[1]); Source[2] = name(bo["TertiarySourceId"], Source[2]); }
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
                // the units with land in the study area (the Build's Strata Summary), else every unit of the level's source
                DataSheet ss = null;
                if (sc != null) { if (HasRows(sc, "lucasCore_OutputStrataSummary")) ss = sc.GetDataSheet("lucasCore_OutputStrataSummary");
                                  else foreach (Scenario d in sc.Dependencies) if (HasRows(d, "lucasCore_OutputStrataSummary")) { ss = d.GetDataSheet("lucasCore_OutputStrataSummary"); break; } }
                FromBuild = ss != null;
                for (int i = 0; i < 3; i++) Units[i].Clear();
                if (ss != null)
                    foreach (DataRow r in Live(ss.GetData()))
                    { int i = Array.IndexOf(Levels, Convert.ToString(r["Level"])); string n = Convert.ToString(r["Name"]); if (i >= 0 && Keys[i].ContainsKey(n) && !Units[i].Contains(n)) Units[i].Add(n); }
                else
                    for (int i = 0; i < 3; i++)
                    { int num = i == 0 ? -1 : number(Source[i]);
                      foreach (var kv in ids[i]) if (i == 0 || (num >= 0 && (int)(kv.Value / 100000000L) == num)) Units[i].Add(kv.Key); }
                for (int i = 0; i < 3; i++) Units[i].Sort(StringComparer.CurrentCultureIgnoreCase);
            }

            private static bool HasRows(Scenario s, string sheet) { DataSheet ds = s.GetDataSheet(sheet); return ds != null && ds.HasData(); }
        }

        // ---- where an action applies: a unit at any of the three strata levels, or "(any)" there; all "(any)" = the whole study
        // area (user 2026-11-13: "the management could also be specified by a) the tiling strata and b) the other strata", e.g. County A
        // with Federal Land Type A, then County A with Type B). With spatial tiles the tile level's unit is required ----------------
        private class WherePicker
        {
            private const string ANY = "(any)";
            public readonly Label[] Captions = new Label[3];
            public readonly ComboBox[] Units = new ComboBox[3];
            public readonly Label Info = new Label { AutoSize = true, MaximumSize = new Size(420, 0), Tag = Fit.Fixed, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 2, 3, 3) };
            private ModelStrata m_ms;

            public WherePicker()
            {
                for (int i = 0; i < 3; i++)
                {
                    Captions[i] = new Label { AutoSize = true, Margin = new Padding(3, 7, 6, 3), Tag = Fit.Fixed };
                    Units[i] = new ComboBox { Width = 330, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3), AutoCompleteMode = AutoCompleteMode.SuggestAppend,
                                              AutoCompleteSource = AutoCompleteSource.ListItems, MaxDropDownItems = 20 };
                }
            }

            public Control Panel()
            {
                var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 2, Margin = new Padding(0) };
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                for (int i = 0; i < 3; i++) { t.RowCount = i + 1; t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.Controls.Add(Captions[i], 0, i); t.Controls.Add(Units[i], 1, i); }
                var p = Column(); p.Controls.Add(t); p.Controls.Add(Info); return p;
            }

            public void Load(ModelStrata ms)
            {
                m_ms = ms;
                for (int i = 0; i < 3; i++)
                {
                    bool req = i == ms.TileLevel;
                    Captions[i].Text = string.Format("{0} ({1}){2}:", ModelStrata.Levels[i], ms.Source[i], req ? ", required" : "");
                    ComboBox c = Units[i]; c.BeginUpdate(); c.Items.Clear(); if (!req) c.Items.Add(ANY);
                    foreach (string n in ms.Units[i]) c.Items.Add(n);
                    c.EndUpdate(); c.Text = ""; if (!req) c.SelectedIndex = 0;
                }
                Info.Text = (ms.TileLevel >= 0
                    ? string.Format("This projection runs in spatial tiles of {0} units, so each action names one {0} unit (a target must lie inside one tile), and optionally a unit at the other levels: add a row for each unit, or combination of units, to manage.", ms.Source[ms.TileLevel])
                    : "No spatial tiles: leave every level at (any) for the whole study area, or name a unit at one or more levels (for example a county and a federal owner within it).")
                    + (ms.FromBuild ? " The lists hold the units with land in the study area; a combination with no land stops the setup, which names the row." : " (The Build has not run yet: every unit of each source is listed.)");
            }

            // the row's stratum columns, or an error message
            public string Apply(DataRow nr)
            {
                for (int i = 0; i < 3; i++)
                {
                    string col = ModelStrata.Columns[i]; if (nr.Table.Columns.Contains(col)) nr[col] = DBNull.Value;
                    string txt = Units[i].Text.Trim();
                    if (txt.Length == 0 || txt == ANY)
                    { if (i == m_ms.TileLevel) return string.Format("choose a {0} unit (the projection's tiles need one)", m_ms.Source[i]); continue; }
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
            public readonly TextBox Start = Box(60), End = Box(60), Area = Box(80), From = Box(40), To = Box(40), Survival = Box(50);
            public readonly ComboBox Priority = List(330), Prep = List(250);
            public readonly WherePicker Where = new WherePicker();
            public readonly Button Add;
            public readonly Label Said = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
            public ActionForm(string addText) { Add = new Button { Text = addText, AutoSize = true, Margin = new Padding(3, 6, 6, 3) }; }
        }

        private readonly ActionForm m_rep = new ActionForm("Add replanting");
        private readonly ActionForm m_sal = new ActionForm("Add salvage logging");
        private readonly Panel m_grid = GridHost(200);
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Label m_rows = new Label { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(3, 4, 3, 6) };

        private static FlowLayoutPanel Pair(TextBox a, string mid, TextBox b, string after)
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
                Note("Management acts on forest that a disturbance has put into its disturbed class (high-severity fire): the land that waits to come back as forest, comes back, or converts to shrub or grass at the end of its window. Choose an action's settings below and add it; add it again with other settings for other years or another place. The rows at the bottom are what the Projection Setup uses. With no rows the projection is the baseline: natural return and conversion only."),
                Note("The area is management above what happened historically. The natural return rates were fitted from what NLCD saw after past fires, and that already includes whatever planting followed them, so a row adds planting or salvage on top of the past rate."))));

            // replanting
            var f = Form();
            FormRow(f, "Years:", Pair(m_rep.Start, "to", m_rep.End, null), "blank = from the first projection year, or to the projection end");
            FormRow(f, "Area per year:", m_rep.Area, "planted each year, in the library's amount units (hectares unless the Terminology says otherwise). When less land is eligible in a year (few recent fires), less is planted; the run reports what was done");
            FormRow(f, "Where:", m_rep.Where.Panel(), "a unit at one or more of the Build's strata levels (Build Options), or (any) at every level for the whole study area. An area over several units is spread over them by their forest land");
            FormRow(f, "Years since the disturbance:", Pair(m_rep.From, "to", m_rep.To, null), "the window for planting: a disturbed cell is planted only at these ages (0 = the year of the fire). Default 1 to 5: before shrubs and grass take the site");
            FormRow(f, "Survival:", m_rep.Survival, "the share of the planted area that takes and goes back to its forest type at age 0. The rest fails: it stays disturbed with its age and can still return on its own or convert. Default 0.8");
            FormRow(f, "Priority:", m_rep.Priority, "at random among eligible cells, or first where natural return is least likely: far from live forest (the inverse of the seed-source curve that speeds natural return near live forest). Every replanting row uses the same priority");
            FormRow(f, "Site preparation:", m_rep.Prep, "carbon flows on the planted (and failed) area. Pile and burn: the shrub and herb cover burns as clearcut slash does (96% to CO2, CO and CH4), its roots die, half the litter and fine woody debris and 30% of the branch snags burn. Mechanical (mastication): the cover goes to litter and fine woody debris, its roots die; nothing burns. None: no flows. Provisional values (to-do 58)");
            var ra = Row(); ra.Controls.Add(m_rep.Add); ra.Controls.Add(m_rep.Said);
            AddGroup(Group("Replanting", ProjectionTransitionsView.Stack(f, ra,
                Wrapped("A planted cell goes back to its own forest type (its disturbed class remembers it). Planting a different type is not offered yet.", 760))));

            // salvage
            var g = Form();
            FormRow(g, "Years:", Pair(m_sal.Start, "to", m_sal.End, null), "blank = from the first projection year, or to the projection end");
            FormRow(g, "Area per year:", m_sal.Area, "salvaged each year, in the library's amount units");
            FormRow(g, "Where:", m_sal.Where.Panel(), "a unit at one or more of the Build's strata levels, or (any) at every level for the whole study area");
            FormRow(g, "Years since the disturbance:", Pair(m_sal.From, "to", m_sal.To, null), "the window: salvage follows soon after the fire, before the snags lose their value. Default 0 to 2");
            var sa = Row(); sa.Controls.Add(m_sal.Add); sa.Controls.Add(m_sal.Said);
            AddGroup(Group("Salvage logging", ProjectionTransitionsView.Stack(g, sa,
                Wrapped("Salvage takes mostly the snags: 72% of snag stems and 85% of any merchantable live wood go to the forestry sector, branch snags fall to dead wood (CBM's salvage matrix). The cell stays in its disturbed class with its age, so its return and conversion clock keeps running.", 760))));

            // the rows
            var r = Row(); r.Controls.Add(m_clear); r.Controls.Add(m_state);
            AddGroup(Group("Actions (what the Projection Setup uses)", ProjectionTransitionsView.Stack(m_rows, m_grid, r,
                Wrapped("Stage 9 turns each row into ST-Sim targets; Projection Results > Management Actions (as set up) lists what each row became. The grid can also be edited directly.", 760))));
            EndGroups();

            m_rep.Priority.Items.AddRange(new object[] { "None (random among eligible cells)", "Far from live forest (least likely to return on its own)" });
            m_rep.Prep.Items.AddRange(new object[] { "None", "Pile and burn", "Mechanical (mastication)" });
            Defaults();
            m_rep.Add.Click += (s, e) => AddRow(1, m_rep);
            m_sal.Add.Click += (s, e) => AddRow(2, m_sal);
            m_clear.Click += (s, e) => ClearAll();
            this.ResumeLayout(false);
        }

        private void Defaults()
        {
            m_rep.Area.Text = "100"; m_rep.From.Text = "1"; m_rep.To.Text = "5"; m_rep.Survival.Text = "0.8"; m_rep.Priority.SelectedIndex = 0; m_rep.Prep.SelectedIndex = 0;
            m_sal.Area.Text = "100"; m_sal.From.Text = "0"; m_sal.To.Text = "2";
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            Project p = this.Scenario != null ? this.Scenario.Project : this.DataFeed.Project;
            if (p != null) { var ms = new ModelStrata(); try { ms.Load(p, this.Scenario); } catch (Exception) { } m_rep.Where.Load(ms); m_sal.Where.Load(ms); }
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
            bool rep = action == 1; object start = DBNull.Value, end = DBNull.Value, area = DBNull.Value, from = DBNull.Value, to = DBNull.Value, surv = DBNull.Value;
            string err = ReadNumber(a.Start, "the start year", true, false, 1900, 2200, out start) ?? ReadNumber(a.End, "the end year", true, false, 1900, 2200, out end)
                      ?? ReadNumber(a.Area, "the area per year", false, true, 0, 1e12, out area) ?? ReadNumber(a.From, "the first year since the disturbance", true, false, 0, 500, out from)
                      ?? ReadNumber(a.To, "the last year since the disturbance", true, false, 0, 500, out to)
                      ?? (rep ? ReadNumber(a.Survival, "survival", false, false, 0, 1, out surv) : null);
            if (err == null && start != DBNull.Value && end != DBNull.Value && (int)start > (int)end) err = "the start year is after the end year";
            if (err == null && from != DBNull.Value && to != DBNull.Value && (int)from > (int)to) err = "the window runs backwards";
            DataTable dt = Sheet.GetData(); DataRow nr = dt.NewRow();
            if (err == null) err = a.Where.Apply(nr);
            if (err != null) { a.Said.ForeColor = Color.Firebrick; a.Said.Text = "Not added: " + err + "."; return; }
            nr["ActionId"] = action; nr["StartYear"] = start; nr["EndYear"] = end; nr["Amount"] = area; nr["MinAge"] = from; nr["MaxAge"] = to;
            if (rep) { nr["Survival"] = surv; nr["Priority"] = a.Priority.SelectedIndex + 1; nr["SitePreparation"] = a.Prep.SelectedIndex + 1; }
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
            string s = string.Format("{0}. {1} {2} a year, {3}, in {4}, {5}-{6} years after the disturbance", i, rep ? "Replant" : "Salvage", Num(r["Amount"], "?"), years,
                                     where.Length > 0 ? where : "the whole study area", Int(r["MinAge"], rep ? 1 : 0), Int(r["MaxAge"], rep ? 5 : 2));
            if (rep)
            {
                double sv = r["Survival"] == DBNull.Value ? 0.8 : Convert.ToDouble(r["Survival"]);
                int prep = Int(r["SitePreparation"], 1), pri = Int(r["Priority"], 1);
                s += string.Format("; {0:0}% takes{1}{2}", 100 * sv, prep == 2 ? ", after pile and burn" : prep == 3 ? ", after mechanical site preparation" : ", no site preparation",
                                   pri == 2 ? ", far from live forest first" : ", at random");
            }
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
