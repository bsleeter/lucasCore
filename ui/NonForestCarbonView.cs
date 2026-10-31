// =============================================================================
// NonForestCarbonView.cs - Carbon Assumptions > Grassland, Shrubland and Wetland Carbon: the non-forest rates (to-do 39)
// =============================================================================
// Feed NonForestCarbon: lucasCore_NonForestGrowth (Ecodivision, Class, Age, Net Growth) and lucasCore_NonForestRate (Ecodivision, Class, Age,
// Flow, Value). The package values are the CONUS 1 km build's (from IBIS simulations): one value per class for all of CONUS (the forested
// wetlands' growth curve and growth split vary with age), in
// defaults/stockflow/nonforest-*.csv. Empty sheets mean the package values; Fill / Reset writes them as rows
// (defaults/carbon-assumptions/fia-measured/nonforest-growth.csv and nonforest-rates.csv, the rows the Carbon Method page's Fill writes
// too) so they can be read and edited. A row replaces the package value; an ecodivision row wins over the class's all-ecodivisions
// row. Stage 3 logs how many values differ from the package's.
// The Diagram view draws one class's values (the package's with this scenario's rows on top) as pools and flows with their steady-state
// budget (NonForestBudget, NonForestDiagram), beside the Build's starting pools of the class.
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
    public class NonForestCarbonView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_NonForestRate"; } }
        private const string GROWTH = "lucasCore_NonForestGrowth";

        private readonly Panel m_growth = GridHost(230);
        private readonly Panel m_rates = GridHost(460);
        private readonly Button m_fill = new Button { AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };

        private readonly RadioButton m_viewTables = new RadioButton { Text = "Tables", AutoSize = true, Checked = true, Margin = new Padding(3, 3, 18, 3) };
        private readonly RadioButton m_viewDiagram = new RadioButton { Text = "Diagram (pools, flows and the steady-state budget)", AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
        private GroupBox m_tablesGroup, m_packageGroup, m_diagramGroup;
        private readonly ComboBox m_class = List(260);
        private readonly ComboBox m_eco = List(220);
        private readonly NumericUpDown m_age = new NumericUpDown { Minimum = 0, Maximum = 300, Value = 100, Width = 60, Margin = new Padding(3, 4, 6, 3) };
        private readonly Label m_ageLabel = new Label { Text = "Age (yr)", AutoSize = true, Margin = new Padding(3, 7, 3, 3) };
        private readonly RadioButton m_rates_ = new RadioButton { Text = "Rates as entered", AutoSize = true, Checked = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly RadioButton m_flux = new RadioButton { Text = "Fluxes (Mg C/ha/yr)", AutoSize = true, Margin = new Padding(3, 3, 18, 3) };
        private readonly CheckBox m_hide = new CheckBox { Text = "Hide empty pools", AutoSize = true, Checked = true, Margin = new Padding(3, 3, 3, 3) };
        private readonly NonForestDiagram m_diagram = new NonForestDiagram { Dock = DockStyle.Fill, Margin = new Padding(0, 6, 0, 6), MinimumSize = new Size(200, 520) };
        private readonly Label m_budget = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 3), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };

        public NonForestCarbonView()
        {
            this.SuspendLayout();
            var v = Row(); v.Controls.AddRange(new Control[] { Caption("Show"), m_viewTables, m_viewDiagram });
            AddGroup(Group("Grassland, shrubland and wetland carbon (stage 3)", ProjectionTransitionsView.Stack(
                Note("How the grassland, shrubland and wetland classes grow, shed and decay. The package values come from the CONUS 1 km LUCAS build, which took them from IBIS model simulations: one value per class for every ecodivision (forested wetlands grow on an age curve that also varies by ecodivision); only the climate multiplier (Climate Options: non-forest growth) varies growth by place and year. Leave both tables empty to use the package values; fill them to see the values and change any of them. A row with an ecodivision or an age applies there only and wins over a more general row; a row without an age sets every age."),
                v)));
            m_tablesGroup = Group("Tables", ProjectionTransitionsView.Stack(
                Note("Growth: net growth, the carbon a class takes up each year (Mg C/ha/yr)."),
                m_growth,
                Note("Rates: for each flow, the share or yearly rate. Net Growth flows split the growth among the live pools and must add to 1 for a class (at each age for forested wetlands). Biomass Turnover flows are the share of a live pool shed each year; Decay, Emission and Transfer flows the share of a dead pool that moves on or is released to the atmosphere each year. Emergent wetlands are different: a flow named for a pool alone (AG Very Fast ->, BG Very Fast ->, BG Slow ->) is that pool's total yearly loss, and the Decay, Emission, Lateral Transport and Stabilization flows out of it are shares of that loss, adding to 1. Fill lists every value that does not change with age; the forested wetlands' growth curve and age-varying growth split are not listed (300 ages) but can be set with rows."),
                m_rates));
            AddGroup(m_tablesGroup);
            var pick = Row(); pick.Controls.AddRange(new Control[] { Caption("Class"), m_class, Caption("Ecodivision"), m_eco, m_ageLabel, m_age });
            var opt = Row(); opt.Controls.AddRange(new Control[] { Caption("Label the flows with"), m_rates_, m_flux, m_hide });
            m_diagramGroup = Group("Diagram", ProjectionTransitionsView.Stack(
                Note("One class's values as the run uses them: the package's, with this page's rows on top (drawn bold). Net growth (NPP) enters the live pools from the left, split by its shares. Each box gives the pool's carbon at steady state, where inputs and losses balance, its turnover time, and what it releases to the atmosphere each year (and, for emergent wetlands, to water). A curve's width is the carbon it carries at steady state; hover over it for the arithmetic. The Build's starting pools came from a spin-up with these rates, so with the package values the budget lands near them."),
                pick, opt, m_budget, m_diagram,
                Note("Forested wetlands grow on an age curve: the diagram holds the rates of the age shown fixed, so their budget is what those rates would settle to, not the class's starting pools.")));
            AddGroup(m_diagramGroup);
            var c = Column();
            c.Controls.Add(Wrapped("The starting carbon of grassland, shrubland and wetland cells is still the package's table (from the CONUS build's spin-up with the package rates), so a changed rate acts from the first year of a run but does not change the starting pools.", 720));
            var r = Row(); r.Controls.Add(m_fill); r.Controls.Add(m_state); c.Controls.Add(r);
            m_packageGroup = Group("Package values", c);
            AddGroup(m_packageGroup);
            EndGroups();
            m_fill.Click += (s, e) => Fill();
            EventHandler redraw = (s, e) => { if (!Refreshing) Draw(); };
            m_viewTables.CheckedChanged += (s, e) => ShowView();
            m_eco.SelectedIndexChanged += (s, e) => { if (!Refreshing) { FillClasses(); Draw(); } };
            m_class.SelectedIndexChanged += redraw; m_age.ValueChanged += redraw; m_flux.CheckedChanged += redraw; m_hide.CheckedChanged += redraw;
            ShowView();
            this.ResumeLayout(false);
        }

        private static string File(string name) { return Defaults.PackageFile("defaults", "carbon-assumptions", "fia-measured", name); }
        private DataSheet Growth { get { return this.DataFeed.GetDataSheet(GROWTH); } }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_growth, GROWTH);
            LoadGrid(m_rates, SheetName);
            // ecodivisions of the library the package has values for
            m_eco.Items.Clear();
            foreach (string n in CarbonPages.Names(Sheet, "StratumId").Values.OrderBy(x => x)) if (NonForestBudget.Classes(n).Count > 0) m_eco.Items.Add(n);
            if (m_eco.Items.Count > 0) m_eco.SelectedIndex = 0;
            FillClasses();
            RefreshControls();
        }

        private void FillClasses()
        {
            string keep = m_class.SelectedItem as string;
            var have = new HashSet<string>(CarbonPages.Names(Sheet, "StateClassId").Values, StringComparer.OrdinalIgnoreCase);
            m_class.Items.Clear();
            if (m_eco.SelectedItem != null) foreach (string cl in NonForestBudget.Classes((string)m_eco.SelectedItem).Where(have.Contains)) m_class.Items.Add(cl);
            int k = keep == null ? -1 : m_class.Items.IndexOf(keep);
            if (m_class.Items.Count > 0) m_class.SelectedIndex = k >= 0 ? k : 0;
        }

        private void ShowView()
        {
            bool tables = m_viewTables.Checked;
            m_tablesGroup.Visible = m_packageGroup.Visible = tables; m_diagramGroup.Visible = !tables;
            if (!tables) Draw();
        }

        private static int Rows(DataSheet ds) { return ds != null && ds.HasData() ? ds.GetData().Rows.Cast<DataRow>().Count(x => x.RowState != DataRowState.Deleted) : 0; }

        private void Fill()
        {
            if ((Rows(Sheet) > 0 || Rows(Growth) > 0) && MessageBox.Show(this, "Replace every row of both tables with the package values?", "Grassland, Shrubland and Wetland Carbon", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            List<string> p = Defaults.Load(Growth, File("nonforest-growth.csv"), null);
            p.AddRange(Defaults.Load(Sheet, File("nonforest-rates.csv"), null));
            LoadGrid(m_growth, GROWTH);
            LoadGrid(m_rates, SheetName);
            RefreshControls();
            if (p.Count > 0) { m_state.Text = "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : ""); m_state.ForeColor = Color.Firebrick; }
        }

        // this scenario's rows by name
        private List<NonForestBudget.SheetRow> SheetRows(DataSheet ds, string valueCol, bool flow)
        {
            Dictionary<int, string> eco = CarbonPages.Names(ds, "StratumId"), cls = CarbonPages.Names(ds, "StateClassId"), fg = flow ? CarbonPages.Names(ds, "FlowGroupId") : null;
            var l = new List<NonForestBudget.SheetRow>(); string n;
            foreach (DataRow r in CarbonPages.Rows(ds))
            {
                if (r["StateClassId"] == DBNull.Value || r[valueCol] == DBNull.Value || (flow && r["FlowGroupId"] == DBNull.Value)) continue;
                l.Add(new NonForestBudget.SheetRow {
                    Eco = r["StratumId"] == DBNull.Value ? null : (eco.TryGetValue(Convert.ToInt32(r["StratumId"]), out n) ? n : "?"),
                    Cls = cls.TryGetValue(Convert.ToInt32(r["StateClassId"]), out n) ? n : "?",
                    Flow = flow ? (fg.TryGetValue(Convert.ToInt32(r["FlowGroupId"]), out n) ? n : "?") : null,
                    Age = r["AgeMin"] == DBNull.Value ? (int?)null : Convert.ToInt32(r["AgeMin"]), V = Convert.ToDouble(r[valueCol]) });
            }
            return l;
        }

        private void Draw()
        {
            if (m_viewTables.Checked || this.DataFeed == null) return;
            string eco = m_eco.SelectedItem as string, cls = m_class.SelectedItem as string;
            if (eco == null || cls == null) { m_diagram.Budget = null; m_budget.Text = ""; m_diagram.Invalidate(); return; }
            bool ages = NonForestBudget.HasAges(eco, cls);
            m_age.Visible = m_ageLabel.Visible = ages;
            NonForestBudget b = NonForestBudget.Make(eco, cls, ages ? (int)m_age.Value : 0, SheetRows(Sheet, "Value", true), SheetRows(Growth, "NetGrowth", false));
            m_diagram.Budget = b; m_diagram.ShowFlux = m_flux.Checked; m_diagram.HideEmpty = m_hide.Checked;
            if (b == null) m_budget.Text = "";
            else
            {
                string text = string.Format("Net growth (NPP) {0} Mg C/ha/yr{1}; released as CO₂ {2}", NonForestDiagram.Num(b.Growth), b.GrowthYours ? " (this page's row)" : "", NonForestDiagram.Num(b.Co2));
                if (b.Aquatic > 0) text += ", to water " + NonForestDiagram.Num(b.Aquatic);
                if (b.Burial > 0) text += ", buried in deep soil " + NonForestDiagram.Num(b.Burial);
                text += string.Format(".\nSteady state: live {0}, dead {1}, soil {2} Mg C/ha", NonForestDiagram.Num(b.Live), NonForestDiagram.Num(b.Dead), NonForestDiagram.Num(b.Soil));
                // the Build's starting pools of the class (study-area means), for comparison
                Scenario res = CarbonPages.BuildResult(this.Scenario);
                DataSheet iss = null; try { iss = res == null ? null : res.GetDataSheet("lucasCore_OutputInitialStockSummary"); } catch (Exception) { }
                Dictionary<int, string> names = iss == null ? null : CarbonPages.Names(iss, "StateClassId"); string n;
                DataRow row = iss == null ? null : CarbonPages.Rows(iss).FirstOrDefault(x => x["StateClassId"] != DBNull.Value && names.TryGetValue(Convert.ToInt32(x["StateClassId"]), out n) && n == cls);
                text += row == null ? "." : string.Format("; the Build result {0} starts this class at live {1}, dead {2}, soil {3}.", "[" + res.Id + "]",
                    NonForestDiagram.Num(Convert.ToDouble(row["Live"])), NonForestDiagram.Num(Convert.ToDouble(row["Dom"])), NonForestDiagram.Num(Convert.ToDouble(row["Soil"])));
                m_budget.Text = text;
            }
            m_diagram.Invalidate();
        }

        protected override void ShowData()
        {
            int g = Rows(Growth), n = Rows(Sheet);
            m_fill.Text = g + n > 0 ? "Reset to the package values" : "Fill with the package values";
            m_fill.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_state.ForeColor = SystemColors.GrayText;
            m_state.Text = g + n > 0 ? string.Format("{0} growth and {1} rate rows. A class, flow or ecodivision without a row keeps its package value.", g, n)
                                     : "Both tables are empty: the Build uses the package values. Fill to see and edit them.";
            Draw();
        }
    }
}
