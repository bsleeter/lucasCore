// =============================================================================
// WoodProductsView.cs - the Wood Products page (stage 18): the run whose harvested carbon to follow, and the model's options
// =============================================================================
// Single-row sheet lucasCore_WoodProductsOptions: RunScenarioId (blank = the newest ST-Sim result), Region (blank = from the strata),
// Draws, Seed, LandClearingUtilized (blank = the defaults), Spinup (Boolean), and, in the feed's second sheet lucasCore_WoodProductsFuture (1.5.1), the levers of a different wood products
// future (LeverFromYear, LeverFullYear, LongLivedShift, LifetimeMultiplier, ExtraEnergyShare, RecoveredWood, RecoveredPaper,
// DiscardEnergyShare; blank = the default). Stage 18 reads it (src/18-wood-products.R). The diagram (WoodProductsFate,
// WoodProductsDiagram) follows one harvest with the levers in full effect, beside the defaults.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class WoodProductsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_WoodProductsOptions"; } }
        private const string FUTURE = "lucasCore_WoodProductsFuture";   // the levers: a sheet of its own (lucasCore 1.5.1), so no library update is needed
        private DataSheet Future { get { return this.DataFeed.GetDataSheet(FUTURE); } }
        private readonly ComboBox m_run = List(460);
        private readonly ComboBox m_region = List(300);
        private readonly TextBox m_draws = Box(70);
        private readonly TextBox m_seed = Box(70);
        private readonly TextBox m_lcu = Box(70);
        private readonly CheckBox m_spin = new CheckBox { Text = "Start from the regional harvest history (1906), scaled to the run's first decade", AutoSize = true, Margin = new Padding(3, 5, 3, 3) };
        private readonly TextBox m_from = Box(70), m_full = Box(70), m_long = Box(70), m_life = Box(70), m_energy = Box(70), m_recW = Box(70), m_recP = Box(70), m_discE = Box(70);
        private readonly ComboBox m_dRegion = List(230), m_dWood = List(100), m_dLog = List(100);
        private readonly NumericUpDown m_dYears = new NumericUpDown { Minimum = 0, Maximum = 200, Value = 50, Increment = 10, Width = 60, Margin = new Padding(3, 4, 6, 3) };
        private readonly Label m_summary = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 3), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };
        private readonly WoodProductsDiagram m_diagram = new WoodProductsDiagram { Dock = DockStyle.Fill, Margin = new Padding(0, 6, 0, 6) };
        private bool m_regionPicked;   // the diagram's region follows the page's Region until one is chosen for the diagram
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

            var w = Form();
            FormRow(w, "Apply from year", m_from, "First year the parameters below act (blank = the projection's first year; for a historical run, its first year). Wood harvested and products discarded before it keep the published tables.");
            FormRow(w, "Fully reached by year", m_full, "The parameters are phased in along a straight line from the start year to this one (blank = at once, in the start year).");
            FormRow(w, "Shift to long-lived products", m_long, "0 to 1 (blank = 0). That share of the carbon bound for paper and short-lived end uses (half-life 12 years or less: packaging, pallets, other manufacturing) goes to building end uses instead (housing and non-residential buildings, 67 to 100 years), in the building mix of the year.");
            FormRow(w, "Product lifetime multiplier", m_life, "Blank = 1. Multiplies the half-life of every product in use: 1.25 keeps products 25% longer (durable design, repair, reuse), 0.8 shortens them. Acts on everything in use from the start year.");
            FormRow(w, "Extra share burned for energy", m_energy, "0 to 1 (blank = 0). That share of the industrial roundwood is burned with energy capture in the year harvested instead of made into products, on top of the bark, fuelwood and mill residue already burned. Stored carbon falls; the model does not credit the fossil fuel displaced.");
            FormRow(w, "Discarded wood recovered", m_recW, "0 to 1 (blank = the table's last year, 0.09). Share of discarded solid wood recycled; the other fates shrink in proportion. Recovered products go back in use for a few years (half-life 2.6) and are then discarded again.");
            FormRow(w, "Discarded paper recovered", m_recP, "0 to 1 (blank = the table's last year, 0.50). The same for paper.");
            FormRow(w, "Discards burned for energy", m_discE, "0 to 1 (blank = 0, as in Skog 2008). Share of discarded wood and paper burned with energy capture, taken in proportion from the other fates (mostly landfills).");
            AddGroup(Group("A different wood products future", ProjectionTransitionsView.Stack(
                Note("Leave every box blank to run the published tables as they are. Each parameter moves carbon from one path to another from the start year on, on top of the parameter draws, so the interval stays and the whole band moves. The run log lists the ones that differ from their defaults."),
                w)));

            var pick = Row(); pick.Controls.AddRange(new Control[] { Caption("Region"), m_dRegion, Caption("Wood"), m_dWood, Caption("Log size"), m_dLog, Caption("Years after harvest"), m_dYears });
            AddGroup(Group("Diagram: where the carbon of a harvest goes", ProjectionTransitionsView.Stack(
                Note("One year's harvest of the region and wood chosen here, followed with the parameters above in full effect and the published values (no draws); the tables are held at their last year, as the stage holds them for later years. Each box gives the carbon there after the years shown, in % of the harvested carbon (wood and bark); a curve's width is the carbon that has passed along it. A value in bold differs from the one the default parameters give, shown beside it. Hover over a curve for what it is. The stage itself follows every year's harvest of the run by region, forest type and cause; this is one harvest of one kind."),
                pick, m_summary, m_diagram)));
            EndGroups();

            for (int i = 0; i < Regions.GetLength(0); i++) m_region.Items.Add(Regions[i, 1]);
            m_run.DropDown += (o, e) => { m_runs = StsimRuns.List(this.DataFeed.Project); RefreshControls(); };
            m_run.SelectionChangeCommitted += (o, e) => { var i = m_run.SelectedItem as RunItem; Write("RunScenarioId", i == null ? DBNull.Value : i.Key); RefreshControls(); };
            m_region.SelectionChangeCommitted += (o, e) => { int k = m_region.SelectedIndex; Write("Region", k <= 0 ? (object)DBNull.Value : Regions[k, 0]); RefreshControls(); };
            BindNumber(m_draws, () => Sheet, "Draws", true);
            BindNumber(m_seed, () => Sheet, "Seed", true);
            BindNumber(m_lcu, () => Sheet, "LandClearingUtilized", false);
            m_spin.CheckedChanged += (o, e) => { if (Refreshing) return; Write("Spinup", m_spin.Checked ? -1 : 0); RefreshControls(); };
            BindNumber(m_from, () => Future, "LeverFromYear", true); BindNumber(m_full, () => Future, "LeverFullYear", true);
            BindNumber(m_long, () => Future, "LongLivedShift", false); BindNumber(m_life, () => Future, "LifetimeMultiplier", false);
            BindNumber(m_energy, () => Future, "ExtraEnergyShare", false); BindNumber(m_recW, () => Future, "RecoveredWood", false);
            BindNumber(m_recP, () => Future, "RecoveredPaper", false); BindNumber(m_discE, () => Future, "DiscardEnergyShare", false);
            for (int i = 1; i < Regions.GetLength(0); i++) m_dRegion.Items.Add(Regions[i, 1]);
            m_dWood.Items.AddRange(new object[] { "Softwood", "Hardwood" }); m_dLog.Items.AddRange(new object[] { "Sawlog", "Pulpwood" });
            m_dRegion.SelectedIndex = Regions.GetLength(0) - 2; m_dWood.SelectedIndex = 0; m_dLog.SelectedIndex = 0;
            m_dRegion.SelectionChangeCommitted += (o, e) => { m_regionPicked = true; Draw(); };
            EventHandler redraw = (o, e) => { if (!Refreshing) Draw(); };
            m_dWood.SelectedIndexChanged += redraw; m_dLog.SelectedIndexChanged += redraw; m_dYears.ValueChanged += redraw;
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
            m_from.Text = Show(Value(Future, "LeverFromYear")); m_full.Text = Show(Value(Future, "LeverFullYear")); m_long.Text = Show(Value(Future, "LongLivedShift")); m_life.Text = Show(Value(Future, "LifetimeMultiplier"));
            m_energy.Text = Show(Value(Future, "ExtraEnergyShare")); m_recW.Text = Show(Value(Future, "RecoveredWood")); m_recP.Text = Show(Value(Future, "RecoveredPaper")); m_discE.Text = Show(Value(Future, "DiscardEnergyShare"));
            if (!m_regionPicked && r > 0) m_dRegion.SelectedIndex = r - 1;
            Draw();
        }

        // a lever as a number (blank: the default given)
        private double Lever(string column, double blank)
        {
            try { object v = Value(Future, column); return v == DBNull.Value || v == null ? blank : Convert.ToDouble(v); }
            catch (Exception) { return blank; }
        }

        // the diagram: one harvest of the chosen region and wood with this page's parameters, beside the defaults
        private void Draw()
        {
            if (this.DataFeed == null || m_dRegion.SelectedIndex < 0) return;
            var L = new WoodProductsFate.Levers { Long = Lever("LongLivedShift", 0), Life = Lever("LifetimeMultiplier", 1), Energy = Lever("ExtraEnergyShare", 0),
                RecWood = Lever("RecoveredWood", double.NaN), RecPaper = Lever("RecoveredPaper", double.NaN), DiscEnergy = Lever("DiscardEnergyShare", double.NaN) };
            string region = Regions[m_dRegion.SelectedIndex + 1, 0], wood = m_dWood.SelectedIndex == 1 ? "HW" : "SW", log = m_dLog.SelectedIndex == 1 ? "Pulpwood" : "Sawlog";
            int years = (int)m_dYears.Value; string problem = L.Problem();
            WoodProductsFate.Result b = null, f = null;
            try
            {
                string dir = Defaults.PackageFile("defaults", "wood-products");
                b = WoodProductsFate.Make(dir, region, wood, log, years, null);
                f = problem == null && L.Active ? WoodProductsFate.Make(dir, region, wood, log, years, L) : b;
            }
            catch (Exception ex) { problem = "The wood products tables could not be read: " + ex.Message; b = f = null; }
            m_diagram.Fate = f; m_diagram.Base = b; m_diagram.Empty = problem ?? "";
            m_summary.ForeColor = problem == null ? SystemColors.ControlText : Color.Firebrick;
            if (problem != null) m_summary.Text = problem + (f != null ? " The diagram shows the default parameters." : "");
            else if (f == null) m_summary.Text = "The tables have no values for this region, wood type and log size.";
            else
            {
                string t = string.Format("After {0} years: {1} of the harvested carbon is stored (in use {2}, recovered {3}, landfills {4}, dumps {5}) and {6} emitted (with energy capture {7}, without {8}).",
                    years, WoodProductsDiagram.Pct(f.Stored), WoodProductsDiagram.Pct(f.InUseTotal), WoodProductsDiagram.Pct(f.Recovered), WoodProductsDiagram.Pct(f.Landfill), WoodProductsDiagram.Pct(f.Dump),
                    WoodProductsDiagram.Pct(f.EmitEnergy + f.EmitNo), WoodProductsDiagram.Pct(f.EmitEnergy), WoodProductsDiagram.Pct(f.EmitNo));
                t += L.Active ? string.Format("\nWith the default parameters: {0} stored, {1} emitted.", WoodProductsDiagram.Pct(b.Stored), WoodProductsDiagram.Pct(b.EmitEnergy + b.EmitNo))
                              : "\nEvery parameter is at its default.";
                m_summary.Text = t;
            }
            m_diagram.Invalidate();
        }
    }

    public class WoodProductsFigureView : FigureView { protected override string SheetName { get { return "lucasCore_OutputWoodProductsFigure"; } } }
}
