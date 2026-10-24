// =============================================================================
// LandCoverCrosswalkView.cs - the Land Cover Crosswalks page: the codes stage 5 maps to state classes, filled in from the package
// =============================================================================
// Multi-row sheet lucasCore_LandCoverCrosswalk (Source, Code, Description, State Class, Note). An empty sheet takes
// defaults/landcover/land-cover-crosswalks.csv when the page opens (FillIfEmpty), so every row can be read and edited; Reset puts the
// package rows back. Stage 5 logs any row that differs from the package default.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class LandCoverCrosswalkView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_LandCoverCrosswalk"; } }

        private readonly Panel m_grid = GridHost(520);
        private readonly Button m_reset = new Button { Text = "Reset to package defaults", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };

        public LandCoverCrosswalkView()
        {
            this.SuspendLayout();
            AddGroup(Group("Land cover crosswalks (stage 5)", ProjectionTransitionsView.Stack(
                Note("How stage 5 turns the land cover sources into state classes: forest types (state classes 100-999) from LANDFIRE EVT or the USFS forest type groups, grassland and shrubland types from RCMAP, wetland types from C-CAP. One row per source code; edit a State Class to change where that code goes."),
                m_grid)));
            var r = Row(); r.Controls.Add(m_reset); r.Controls.Add(m_state);
            AddGroup(Group("Defaults", r));
            EndGroups();
            m_reset.Click += (s, e) => Reset();
            this.ResumeLayout(false);
        }

        private string File { get { return Defaults.PackageFile("defaults", "landcover", "land-cover-crosswalks.csv"); } }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            List<string> p = FillIfEmpty(SheetName, File, null);
            if (p != null) Report(p, "Filled in from the package defaults.");
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void Reset()
        {
            if (MessageBox.Show(this, "Replace every row with the package defaults (defaults/landcover/land-cover-crosswalks.csv)?", "Land Cover Crosswalks",
                                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Report(Defaults.Load(Sheet, File, null), "Defaults loaded.");
            LoadGrid(m_grid, SheetName);
        }

        private void Report(List<string> p, string ok)
        {
            m_state.Text = p.Count == 0 ? ok : "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : "");
            m_state.ForeColor = p.Count == 0 ? SystemColors.GrayText : Color.Firebrick;
        }

        protected override void ShowData() { m_reset.Enabled = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView(); }
    }
}
