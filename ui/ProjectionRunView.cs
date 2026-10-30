// =============================================================================
// ProjectionRunView.cs - the Run Settings page of a projection: how it starts, which historical years it draws, iterations, type mix
// =============================================================================
// Feed ProjectionRun = Projection Options + Projection Start (both single-row, unchanged; stage 9 reads them). Blank still means
// default: no historical run = a continuous run, no reference years = all historical transition years, no tiles = the Build's (Build Options; none there = one job, and 1 = one job even when the Build has tiles); 0 = automatic (stage 9 picks the number).
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
    public class ProjectionRunView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ProjectionOptions"; } }
        private DataSheet Start { get { return this.DataFeed.GetDataSheet("lucasCore_ProjectionStart"); } }

        private class Item { public object Key; public string Name; public override string ToString() { return Name; } }

        private readonly RadioButton m_continuous = new RadioButton { Text = "Continuous: the projection follows the historical years in the same run", AutoSize = true };
        private readonly RadioButton m_standAlone = new RadioButton { Text = "Stand-alone: start from the final year of a historical run", AutoSize = true };
        private readonly ComboBox m_hist = List(360);
        private readonly CheckBox m_allYears = new CheckBox { Text = "All historical transition years", AutoSize = true, Margin = new Padding(3, 5, 18, 3) };
        private readonly TextBox m_from = Box(60), m_to = Box(60);
        private readonly TextBox m_iter = Box(60), m_seed = Box(60);
        private readonly TextBox m_endYear = Box(60);
        private readonly RadioButton m_spatial = new RadioButton { Text = "The spatial allocation decides", AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
        private readonly RadioButton m_shares = new RadioButton { Text = "Weight each type by its historical share (default)", AutoSize = true };
        private readonly CheckBox m_tiled = new CheckBox { Text = "Split the landscape into tiles:", AutoSize = true, Margin = new Padding(3, 5, 6, 3) };
        private readonly TextBox m_tiles = Box(50);
        private readonly ComboBox m_tileLevel = List(240);
        private readonly Label m_tileState = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 3, 3, 3) };
        private int m_synced;
        private int m_buildTiles = 1, m_buildLevel = 2;   // the Build's spatial tiles (its Build Options), followed while this page sets none
        private List<Item> m_runs = new List<Item>();
        private bool m_wantStandAlone;   // the stand-alone radio is on but no run is chosen yet
        private bool m_customYears;      // all years unticked, the years not typed yet

        public ProjectionRunView()
        {
            this.SuspendLayout();
            var span = Form();
            FormRow(span, "End year:", m_endYear, "blank = 2100. Projections start the year after the Build's historical end; their climate comes from a Projection Climate scenario.");
            AddGroup(Group("Projection years", span));

            var start = Column();
            start.Controls.Add(m_continuous);
            var r = Row(); m_standAlone.Margin = new Padding(3, 6, 6, 3); r.Controls.Add(m_standAlone); r.Controls.Add(m_hist); start.Controls.Add(r);
            start.Controls.Add(Wrapped("Stand-alone: stage 9 starts from that run's state class, age and carbon stock maps in its last year, so the history is run once and many projections share it. The run must have written age maps (on by default for Builds from 25 October 2026; otherwise tick Ages on its Spatial output page).", 640));
            AddGroup(Group("How the projection starts", start));

            var years = Column();
            years.Controls.Add(Note("Each projection year and iteration draws one whole historical year; the groups of one sampling set (Transitions page) draw the same year."));
            var y = Row(); y.Controls.Add(m_allYears); y.Controls.Add(Caption("or from")); y.Controls.Add(m_from); y.Controls.Add(Caption("to")); y.Controls.Add(m_to); years.Controls.Add(y);
            AddGroup(Group("Historical years drawn (reference period)", years));

            var it = Form();
            FormRow(it, "Iterations:", m_iter, "Monte Carlo runs: each draws its own sequence of historical years");
            FormRow(it, "Random seed:", m_seed, "the same seed gives the same draws");
            AddGroup(Group("Iterations", it));

            var mix = Column();
            mix.Controls.Add(Note("A named group (Urbanization) gets one area per unit and year; which of its transition types each cell gets:"));
            var m = Row(); m.Controls.Add(m_spatial); m.Controls.Add(m_shares); mix.Controls.Add(m);
            mix.Controls.Add(Wrapped("Types that share one placement surface (Developed Low, Medium and High) split about evenly when the allocation decides.", 640));
            AddGroup(Group("Transition types within a named group", mix));

            var tl = Column();
            var t = Row(); t.Controls.Add(m_tiled); t.Controls.Add(m_tiles); t.Controls.Add(Caption("of whole units of")); t.Controls.Add(m_tileLevel); tl.Controls.Add(t);
            tl.Controls.Add(m_tileState);
            tl.Controls.Add(Wrapped("ST-Sim runs the tiles in parallel and merges them. A target must not be split between tiles, so every Target group uses the tile strata level: choosing it here sets the Target Strata of this scenario's Target rows (Transitions page), and stage 9 enforces it. The levels are the strata set in Build Options; set one there to a layer that suits tiles before building.", 640));
            AddGroup(Group("Spatial multiprocessing", tl));
            EndGroups();

            m_continuous.CheckedChanged += (s, e) => { if (!Refreshing && m_continuous.Checked) { m_wantStandAlone = false; Write(Start, "HistoricalScenarioId", DBNull.Value); RefreshControls(); } };
            m_standAlone.CheckedChanged += (s, e) => { if (!Refreshing && m_standAlone.Checked) { m_wantStandAlone = true; RefreshControls(); } };
            m_hist.DropDown += (s, e) => { int n = m_runs.Count; LoadRuns(); if (m_runs.Count != n) RefreshControls(); };
            m_hist.SelectionChangeCommitted += (s, e) => { var i = m_hist.SelectedItem as Item; Write(Start, "HistoricalScenarioId", i == null ? DBNull.Value : i.Key); RefreshControls(); };
            m_allYears.CheckedChanged += (s, e) => { if (Refreshing) return; m_customYears = !m_allYears.Checked; if (m_allYears.Checked) { Write("ReferenceStartYear", DBNull.Value); Write("ReferenceEndYear", DBNull.Value); } RefreshControls(); };
            BindNumber(m_from, () => Sheet, "ReferenceStartYear", true); BindNumber(m_to, () => Sheet, "ReferenceEndYear", true);
            BindNumber(m_iter, () => Sheet, "Iterations", true); BindNumber(m_seed, () => Sheet, "RandomSeed", true);
            BindNumber(m_endYear, () => Sheet, "ProjectionEndYear", true);
            m_spatial.CheckedChanged += (s, e) => { if (!Refreshing && m_spatial.Checked) Write("HistoricalTypeShares", false); };
            m_shares.CheckedChanged += (s, e) => { if (!Refreshing && m_shares.Checked) Write("HistoricalTypeShares", true); };
            // ticked: follow the Build's tiles (or 4 of this projection's own when the Build has none); unticked: one job (1 when the Build has tiles, since blank follows the Build)
            // (0 = automatic: stage 9 picks the number, as stage 1 does for the Build)
            m_tiled.CheckedChanged += (s, e) => { if (Refreshing) return;
                if (m_tiled.Checked) { if (BuildTiled()) Write("SpatialTiles", DBNull.Value); else { Write("SpatialTiles", 0); SetTileLevel(TileLevel()); } }
                else Write("SpatialTiles", BuildTiled() ? (object)1 : DBNull.Value);
                RefreshControls(); };
            m_tiles.Validated += (s, e) => { if (Refreshing) return; bool follow = Following(); string v = m_tiles.Text.Trim(); int n;
                if (v.Equals("auto", StringComparison.OrdinalIgnoreCase)) v = "0";
                if (v.Length == 0) Write("SpatialTiles", DBNull.Value);
                else if (int.TryParse(v, out n) && n >= 0 && (!follow || n != m_buildTiles)) { Write("SpatialTiles", n); if (follow) SetTileLevel(m_buildLevel); }
                RefreshControls(); };
            m_tileLevel.SelectionChangeCommitted += (s, e) => { if (Following()) Write("SpatialTiles", m_buildTiles); SetTileLevel(m_tileLevel.SelectedIndex + 1); RefreshControls(); };
            this.ResumeLayout(false);
        }

        private int TileLevel() { return IntValue("SpatialTilesStrata", 2); }
        private bool BuildTiled() { return m_buildTiles == 0 || m_buildTiles > 1; }
        private bool Following() { return Value("SpatialTiles") == DBNull.Value && BuildTiled(); }
        private static string TilesText(object t) { return t == DBNull.Value ? "" : Convert.ToInt32(t) == 0 ? "auto" : Convert.ToString(t); }

        // the tile level, and the Target Strata of this scenario's Target rows (Projection Transitions) to match
        private void SetTileLevel(int level)
        {
            Write("SpatialTilesStrata", level);
            DataSheet pt = this.DataFeed.Scenario == null ? null : this.DataFeed.Scenario.GetDataSheet("lucasCore_ProjectionTransition");
            m_synced = 0; if (pt == null) return;
            DataTable dt = pt.GetData();
            List<DataRow> rows = dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted && r["Method"] != DBNull.Value && Convert.ToInt32(r["Method"]) == 1).ToList();
            List<DataRow> change = rows.Where(r => r["StrataLevel"] == DBNull.Value || Convert.ToInt32(r["StrataLevel"]) != level).ToList();
            if (change.Count == 0) return;
            pt.BeginModifyRows(); foreach (DataRow r in change) r["StrataLevel"] = level; pt.EndModifyRows();
            m_synced = change.Count;
        }

        // result scenarios of this project, newest first: a historical run is one of them. Results are in Project.Results, not in
        // Project.Scenarios (which holds only the scenarios you edit); reread whenever the drop-down opens, so a run that finished
        // while this page was open is listed
        private void LoadRuns()
        {
            m_runs = this.DataFeed.Project.Results.Cast<Scenario>()
                .OrderByDescending(s => s.Id).Select(s => new Item { Key = s.Id, Name = s.DisplayName.StartsWith("[" + s.Id + "]") ? s.DisplayName : string.Format("[{0}] {1}", s.Id, s.DisplayName) }).ToList();   // a result's DisplayName already starts with its id
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadRuns();
            // the strata levels by what the build put in them (Build Options' sources; blank = the defaults), read once
            string sec = "States", ter = "Federal Lands";
            try
            {
                Scenario sc = this.DataFeed.Scenario;
                // this scenario's Build Options, else its dependencies' (a Projection Setup takes them from its Build result)
                Func<Scenario, DataRow> opts = s => s == null ? null : s.GetDataSheet("lucasCore_BuildOptions").GetData().Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted);
                DataRow bo = opts(sc);
                if (bo == null && sc != null) foreach (Scenario d in sc.Dependencies) { bo = opts(d); if (bo != null) break; }
                DataTable src = this.DataFeed.Project.GetDataSheet("lucasCore_StratumSource").GetData();
                Func<object, string, string> name = (k, d) => { if (k == null || k == DBNull.Value) return d; DataRow r = src.Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted && Convert.ToInt32(x["StratumSourceId"]) == Convert.ToInt32(k)); return r == null ? d : Convert.ToString(r["Name"]); };
                if (bo != null) { sec = name(bo["SecondarySourceId"], sec); ter = name(bo["TertiarySourceId"], ter); }
                if (bo != null && bo.Table.Columns.Contains("SpatialTiles") && bo["SpatialTiles"] != DBNull.Value) m_buildTiles = Convert.ToInt32(bo["SpatialTiles"]);
                if (bo != null && bo.Table.Columns.Contains("SpatialTilesStrata") && bo["SpatialTilesStrata"] != DBNull.Value) m_buildLevel = Convert.ToInt32(bo["SpatialTilesStrata"]);
            }
            catch (Exception) { }
            m_tileLevel.Items.Clear(); m_tileLevel.Items.Add("Primary: FIA ecodivisions"); m_tileLevel.Items.Add("Secondary: " + sec); m_tileLevel.Items.Add("Tertiary: " + ter);
            RefreshControls();
        }

        protected override void ShowData()
        {
            object hid = Value(Start, "HistoricalScenarioId");
            bool standAlone = hid != DBNull.Value || m_wantStandAlone;
            m_standAlone.Checked = standAlone; m_continuous.Checked = !standAlone;
            m_hist.Enabled = standAlone;
            m_hist.BeginUpdate(); m_hist.Items.Clear();
            m_hist.Items.Add(new Item { Key = DBNull.Value, Name = "(choose a historical run)" });
            foreach (Item i in m_runs) m_hist.Items.Add(i);
            int idx = 0;
            for (int k = 1; k < m_hist.Items.Count; k++) if (hid != DBNull.Value && Convert.ToInt32(((Item)m_hist.Items[k]).Key) == Convert.ToInt32(hid)) idx = k;
            if (hid != DBNull.Value && idx == 0) { m_hist.Items.Add(new Item { Key = hid, Name = string.Format("[{0}] (not in this project)", hid) }); idx = m_hist.Items.Count - 1; }
            m_hist.SelectedIndex = idx; m_hist.EndUpdate();

            object rs = Value("ReferenceStartYear"), re = Value("ReferenceEndYear");
            bool all = rs == DBNull.Value && re == DBNull.Value && !m_customYears;
            m_allYears.Checked = all; m_from.Enabled = m_to.Enabled = !all;
            m_from.Text = Show(rs); m_to.Text = Show(re);

            m_iter.Text = Show(Value("Iterations")); m_seed.Text = Show(Value("RandomSeed"));
            m_endYear.Text = Show(Value("ProjectionEndYear"));
            object sh = Value("HistoricalTypeShares");
            bool shares = sh == DBNull.Value || Convert.ToBoolean(sh);   // blank = historical shares (the default)
            m_shares.Checked = shares; m_spatial.Checked = !shares;
            object own = Value("SpatialTiles"); bool follow = Following();
            object tiles = follow ? (object)m_buildTiles : own;
            m_tiled.Checked = tiles != DBNull.Value && (Convert.ToInt32(tiles) == 0 || Convert.ToInt32(tiles) > 1); m_tiles.Enabled = m_tileLevel.Enabled = m_tiled.Checked; m_tiles.Text = TilesText(tiles);
            if (m_tileLevel.Items.Count == 3) m_tileLevel.SelectedIndex = Math.Max(0, Math.Min(2, (follow ? m_buildLevel : TileLevel()) - 1));
            m_tileState.Text = follow ? "From the Build (Build Options): every run on it uses these tiles, and stage 9 sets the Target rows to this level. Change the number or level to set this projection's own; untick for one job."
                : !m_tiled.Checked ? (BuildTiled() ? string.Format("One job: the Build's {0} tiles are not used (tick to follow the Build again).", m_buildTiles == 0 ? "automatic" : Convert.ToString(m_buildTiles)) : "")
                : TilesText(own) == "auto" ? "Automatic: stage 9 packs whole units into as many tiles as still shorten the run and logs the choice; type a number to choose it yourself."
                : m_synced > 0 ? string.Format("{0} Target row{1} set to this level on the Transitions page.", m_synced, m_synced == 1 ? "" : "s")
                : "Target rows use this level (rows inherited from the Build are set by stage 9 when it runs).";
        }
    }
}
