// =============================================================================
// GrowthInputsView.cs - Carbon Assumptions > Growth Inputs: each forest type's growth curve and live carbon inputs (to-do 29)
// =============================================================================
// Multi-row sheet lucasCore_GrowthInput (Forest Type, FIA Forest Type Groups, Growth Class, Merchantable Carbon Density, Deciduous Share,
// Fine Root Share). An empty sheet means the package values (defaults/growth/forest-type-crosswalk.csv and merch-carbon-density.csv);
// Fill / Reset writes those values as rows (defaults/carbon-assumptions/fia-measured/growth-inputs.csv, the rows the Carbon Method
// page's Fill writes too) so they can be read and edited. A forest type without a row keeps its package values. Stages 2 and 3 log
// every value that differs from the package's.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class GrowthInputsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_GrowthInput"; } }

        private readonly Panel m_grid = GridHost(560);
        private readonly Button m_fill = new Button { AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };

        public GrowthInputsView()
        {
            this.SuspendLayout();
            AddGroup(Group("Growth inputs by forest type (stages 2 and 3)", ProjectionTransitionsView.Stack(
                Note("What the growth curves are fitted to and how live tree carbon is split, one row per forest type. Leave the sheet empty to use the package values; fill it to see them and change any of them."),
                m_grid)));
            var g = Column();
            g.Controls.Add(Wrapped("FIA Forest Type Groups: the FIA forest type group codes whose plots the type's growth curves are fitted to, separated by ';' (for example 260 or 100;120).", 720));
            g.Controls.Add(Wrapped("Growth Class: east or west, softwood or hardwood. It sets the lag of the curves for types with few plots, and the softwood or hardwood CBM turnover and snag rates.", 720));
            g.Controls.Add(Wrapped("Merchantable Carbon Density: carbon per cubic metre of FIA net merchantable volume, wood and bark (Mg C/m3). It turns the volume curves into merchantable carbon.", 720));
            g.Controls.Add(Wrapped("Deciduous Share: the share of the type's volume in deciduous species. Foliage falls at the CBM hardwood rate for that share and the softwood rate for the rest.", 720));
            g.Controls.Add(Wrapped("Fine Root Share: a fixed share of root carbon in fine roots. Blank = Li et al. (2003), where the share falls as root biomass grows (about 0.4 in young stands to under 0.1 in old ones).", 720));
            AddGroup(Group("What the columns mean", g));
            var r = Row(); r.Controls.Add(m_fill); r.Controls.Add(m_state);
            AddGroup(Group("Package values", r));
            EndGroups();
            m_fill.Click += (s, e) => Fill();
            this.ResumeLayout(false);
        }

        private static string File { get { return Defaults.PackageFile("defaults", "carbon-assumptions", "fia-measured", "growth-inputs.csv"); } }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void Fill()
        {
            if (Sheet.HasData() && MessageBox.Show(this, "Replace every row with the package values?", "Growth Inputs", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            List<string> p = Defaults.Load(Sheet, File, null);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
            if (p.Count > 0) { m_state.Text = "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : ""); m_state.ForeColor = Color.Firebrick; }
        }

        protected override void ShowData()
        {
            bool has = Sheet.HasData();
            int n = has ? Sheet.GetData().Rows.Cast<System.Data.DataRow>().Count(x => x.RowState != System.Data.DataRowState.Deleted) : 0;
            m_fill.Text = has ? "Reset to the package values" : "Fill with the package values";
            m_fill.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_state.ForeColor = SystemColors.GrayText;
            m_state.Text = has ? string.Format("{0} forest type{1} listed. A forest type without a row keeps its package values.", n, n == 1 ? "" : "s")
                               : "The sheet is empty: the Build uses the package values for every forest type. Fill to see and edit them.";
        }
    }
}
