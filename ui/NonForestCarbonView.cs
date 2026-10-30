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

        public NonForestCarbonView()
        {
            this.SuspendLayout();
            AddGroup(Group("Grassland, shrubland and wetland carbon (stage 3)", ProjectionTransitionsView.Stack(
                Note("How the grassland, shrubland and wetland classes grow, shed and decay. The package values come from the CONUS 1 km LUCAS build, which took them from IBIS model simulations: one value per class for every ecodivision (forested wetlands grow on an age curve that also varies by ecodivision); only the climate multiplier (Climate Options: non-forest growth) varies growth by place and year. Leave both tables empty to use the package values; fill them to see the values and change any of them. A row with an ecodivision or an age applies there only and wins over a more general row; a row without an age sets every age."),
                Note("Growth: net growth, the carbon a class takes up each year (Mg C/ha/yr)."),
                m_growth,
                Note("Rates: for each flow, the share or yearly rate. Net Growth flows split the growth among the live pools and must add to 1 for a class (at each age for forested wetlands). Biomass Turnover flows are the share of a live pool shed each year; Decay, Emission and Transfer flows the share of a dead pool that moves on or is released to the atmosphere each year. Emergent wetlands are different: a flow named for a pool alone (AG Very Fast ->, BG Very Fast ->, BG Slow ->) is that pool's total yearly loss, and the Decay, Emission, Lateral Transport and Stabilization flows out of it are shares of that loss, adding to 1. Fill lists every value that does not change with age; the forested wetlands' growth curve and age-varying growth split are not listed (300 ages) but can be set with rows."),
                m_rates)));
            var c = Column();
            c.Controls.Add(Wrapped("The starting carbon of grassland, shrubland and wetland cells is still the package's table (from the CONUS build's spin-up with the package rates), so a changed rate acts from the first year of a run but does not change the starting pools.", 720));
            var r = Row(); r.Controls.Add(m_fill); r.Controls.Add(m_state); c.Controls.Add(r);
            AddGroup(Group("Package values", c));
            EndGroups();
            m_fill.Click += (s, e) => Fill();
            this.ResumeLayout(false);
        }

        private static string File(string name) { return Defaults.PackageFile("defaults", "carbon-assumptions", "fia-measured", name); }
        private DataSheet Growth { get { return this.DataFeed.GetDataSheet(GROWTH); } }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_growth, GROWTH);
            LoadGrid(m_rates, SheetName);
            RefreshControls();
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

        protected override void ShowData()
        {
            int g = Rows(Growth), n = Rows(Sheet);
            m_fill.Text = g + n > 0 ? "Reset to the package values" : "Fill with the package values";
            m_fill.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_state.ForeColor = SystemColors.GrayText;
            m_state.Text = g + n > 0 ? string.Format("{0} growth and {1} rate rows. A class, flow or ecodivision without a row keeps its package value.", g, n)
                                     : "Both tables are empty: the Build uses the package values. Fill to see and edit them.";
        }
    }
}
