// =============================================================================
// ProjectionRunView.cs - the Run Settings page of a projection: how it starts, which historical years it draws, iterations, type mix
// =============================================================================
// Feed ProjectionRun = Projection Options + Projection Start (both single-row, unchanged; stage 9 reads them). Blank still means
// default: no historical run = a continuous run, no reference years = all historical transition years, no tiles = one job.
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
        private readonly RadioButton m_spatial = new RadioButton { Text = "The spatial allocation decides", AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
        private readonly RadioButton m_shares = new RadioButton { Text = "Weight each type by its historical share (default)", AutoSize = true };
        private readonly CheckBox m_tiled = new CheckBox { Text = "Split the landscape into tiles:", AutoSize = true, Margin = new Padding(3, 5, 6, 3) };
        private readonly TextBox m_tiles = Box(50);
        private List<Item> m_runs = new List<Item>();
        private bool m_wantStandAlone;   // the stand-alone radio is on but no run is chosen yet
        private bool m_customYears;      // all years unticked, the years not typed yet

        public ProjectionRunView()
        {
            this.SuspendLayout();
            var start = Column();
            start.Controls.Add(m_continuous);
            var r = Row(); m_standAlone.Margin = new Padding(3, 6, 6, 3); r.Controls.Add(m_standAlone); r.Controls.Add(m_hist); start.Controls.Add(r);
            start.Controls.Add(Wrapped("Stand-alone: stage 9 starts from that run's state class, age and carbon stock maps in its last year (run it with tools/new-historical.R --historical-only --bookend-maps), so the history is run once and many projections share it.", 640));
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
            var t = Row(); t.Controls.Add(m_tiled); t.Controls.Add(m_tiles); tl.Controls.Add(t);
            tl.Controls.Add(Wrapped("ST-Sim runs the tiles in parallel. Tiles are whole units of the target strata, so every Target group must use the same strata level.", 640));
            AddGroup(Group("Spatial multiprocessing", tl));
            EndGroups();

            m_continuous.CheckedChanged += (s, e) => { if (!Refreshing && m_continuous.Checked) { m_wantStandAlone = false; Write(Start, "HistoricalScenarioId", DBNull.Value); RefreshControls(); } };
            m_standAlone.CheckedChanged += (s, e) => { if (!Refreshing && m_standAlone.Checked) { m_wantStandAlone = true; RefreshControls(); } };
            m_hist.SelectionChangeCommitted += (s, e) => { var i = m_hist.SelectedItem as Item; Write(Start, "HistoricalScenarioId", i == null ? DBNull.Value : i.Key); RefreshControls(); };
            m_allYears.CheckedChanged += (s, e) => { if (Refreshing) return; m_customYears = !m_allYears.Checked; if (m_allYears.Checked) { Write("ReferenceStartYear", DBNull.Value); Write("ReferenceEndYear", DBNull.Value); } RefreshControls(); };
            BindNumber(m_from, () => Sheet, "ReferenceStartYear", true); BindNumber(m_to, () => Sheet, "ReferenceEndYear", true);
            BindNumber(m_iter, () => Sheet, "Iterations", true); BindNumber(m_seed, () => Sheet, "RandomSeed", true);
            m_spatial.CheckedChanged += (s, e) => { if (!Refreshing && m_spatial.Checked) Write("HistoricalTypeShares", false); };
            m_shares.CheckedChanged += (s, e) => { if (!Refreshing && m_shares.Checked) Write("HistoricalTypeShares", true); };
            m_tiled.CheckedChanged += (s, e) => { if (Refreshing) return; Write("SpatialTiles", m_tiled.Checked ? (object)4 : DBNull.Value); RefreshControls(); };
            BindNumber(m_tiles, () => Sheet, "SpatialTiles", true);
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // result scenarios of this project, newest first: a historical run is one of them
            m_runs = this.DataFeed.Project.Scenarios.Cast<Scenario>().Where(s => s.IsResult)
                .OrderByDescending(s => s.Id).Select(s => new Item { Key = s.Id, Name = string.Format("[{0}] {1}", s.Id, s.DisplayName) }).ToList();
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
            object sh = Value("HistoricalTypeShares");
            bool shares = sh == DBNull.Value || Convert.ToBoolean(sh);   // blank = historical shares (the default)
            m_shares.Checked = shares; m_spatial.Checked = !shares;
            object tiles = Value("SpatialTiles");
            m_tiled.Checked = tiles != DBNull.Value && Convert.ToInt32(tiles) > 1; m_tiles.Enabled = m_tiled.Checked; m_tiles.Text = Show(tiles);
        }
    }
}
