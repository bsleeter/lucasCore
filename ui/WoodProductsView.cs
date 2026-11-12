// =============================================================================
// WoodProductsView.cs - the Wood Products page (stage 18): the run whose harvested carbon to follow, and the model's options
// =============================================================================
// Single-row sheet lucasCore_WoodProductsOptions: RunScenarioId (blank = the newest ST-Sim result), Region (blank = from the strata),
// Draws, Seed, LandClearingUtilized (blank = the defaults), Spinup (Boolean). Stage 18 reads it (src/18-wood-products.R).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class WoodProductsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_WoodProductsOptions"; } }
        private readonly ComboBox m_run = List(460);
        private readonly ComboBox m_region = List(300);
        private readonly TextBox m_draws = Box(70);
        private readonly TextBox m_seed = Box(70);
        private readonly TextBox m_lcu = Box(70);
        private readonly CheckBox m_spin = new CheckBox { Text = "Start from the regional harvest history (1906), scaled to the run's first decade", AutoSize = true, Margin = new Padding(3, 5, 3, 3) };
        private List<RunItem> m_runs = new List<RunItem>();
        private static readonly string[,] Regions = {
            { "", "(from the strata: the state of each secondary stratum)" }, { "NE", "NE - Northeast" }, { "NLS", "NLS - Northern Lake States" },
            { "NPS", "NPS - Northern Prairie States" }, { "SE", "SE - Southeast" }, { "SC", "SC - South Central" }, { "RMN", "RMN - Rocky Mountain, North" },
            { "RMS", "RMS - Rocky Mountain, South" }, { "PSW", "PSW - Pacific Southwest" }, { "PWE", "PWE - Pacific Northwest, East" }, { "PWW", "PWW - Pacific Northwest, West" } };

        public WoodProductsView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(m_run);
            c.Controls.Add(Note("A historical run or a projection of this project. A stand-alone projection is joined to its historical run, so wood harvested in the history keeps decaying through the projection. The scenario must depend on the run's Build result."));
            AddGroup(Group("Run to follow", c));

            var f = Form();
            FormRow(f, "Region", m_region, "Smith et al. (2006) region of the product and roundwood factors. Blank: each cell's region from its secondary stratum (a state or a county), Oregon and Washington split at the Cascade crest by ecodivision. Choose one when the strata name no state.");
            FormRow(f, "Parameter draws", m_draws, "Per run iteration (blank = 100). 0 runs the published values only. Results give the mean and the 90% interval.");
            FormRow(f, "Seed", m_seed, "Random seed of the draws (blank = 1). The same seed gives the same draws, so two projections from one history share its years exactly.");
            FormRow(f, "Land clearing used", m_lcu, "Share of the wood cut in urbanization and agricultural expansion that becomes products (blank = 0.5, drawn over 0 to 1). No USFS table gives it; the rest is emitted in the year cleared.");
            AddGroup(Group("Model", f));

            var s = Column();
            s.Controls.Add(m_spin);
            s.Controls.Add(Note("Off: the products start empty in the run's first year, so the decay of earlier harvests is missing and storage is overstated."));
            AddGroup(Group("Before the run", s));
            EndGroups();

            for (int i = 0; i < Regions.GetLength(0); i++) m_region.Items.Add(Regions[i, 1]);
            m_run.DropDown += (o, e) => { m_runs = StsimRuns.List(this.DataFeed.Project); RefreshControls(); };
            m_run.SelectionChangeCommitted += (o, e) => { var i = m_run.SelectedItem as RunItem; Write("RunScenarioId", i == null ? DBNull.Value : i.Key); RefreshControls(); };
            m_region.SelectionChangeCommitted += (o, e) => { int k = m_region.SelectedIndex; Write("Region", k <= 0 ? (object)DBNull.Value : Regions[k, 0]); RefreshControls(); };
            BindNumber(m_draws, () => Sheet, "Draws", true);
            BindNumber(m_seed, () => Sheet, "Seed", true);
            BindNumber(m_lcu, () => Sheet, "LandClearingUtilized", false);
            m_spin.CheckedChanged += (o, e) => { if (Refreshing) return; Write("Spinup", m_spin.Checked ? -1 : 0); RefreshControls(); };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_runs = StsimRuns.List(this.DataFeed.Project);
            RefreshControls();
        }

        protected override void ShowData()
        {
            object rid = Value("RunScenarioId");
            m_run.BeginUpdate(); m_run.Items.Clear();
            m_run.Items.Add(new RunItem { Key = DBNull.Value, Name = "(the newest run)" });
            foreach (RunItem i in m_runs) m_run.Items.Add(i);
            int idx = 0;
            for (int k = 1; k < m_run.Items.Count; k++) if (rid != DBNull.Value && Convert.ToInt32(((RunItem)m_run.Items[k]).Key) == Convert.ToInt32(rid)) idx = k;
            if (rid != DBNull.Value && idx == 0) { m_run.Items.Add(StsimRuns.Missing(this.DataFeed.Project, Convert.ToInt32(rid))); idx = m_run.Items.Count - 1; }
            m_run.SelectedIndex = idx; m_run.EndUpdate();

            string rg = Show(Value("Region")); int r = 0;
            for (int k = 1; k < Regions.GetLength(0); k++) if (string.Equals(Regions[k, 0], rg, StringComparison.OrdinalIgnoreCase)) r = k;
            m_region.SelectedIndex = r;
            m_draws.Text = Show(Value("Draws")); m_seed.Text = Show(Value("Seed")); m_lcu.Text = Show(Value("LandClearingUtilized"));
            object sp = Value("Spinup"); m_spin.Checked = sp == DBNull.Value || Convert.ToInt32(sp) != 0;
        }
    }

    public class WoodProductsFigureView : FigureView { protected override string SheetName { get { return "lucasCore_OutputWoodProductsFigure"; } } }
}
