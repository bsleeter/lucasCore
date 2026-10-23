// =============================================================================
// ProjectionTransitionsView.cs - the Transitions page of a projection: how much each group changes, and where it goes
// =============================================================================
// Feed ProjectionTransitions = Projection Transitions (stage 9: amount per group) + Projection Allocation (stage 10: placement per
// group or member type). Both are SyncroSim's own grids with notes around them; Reset to defaults reloads both from
// defaults/projection/transitions.csv and allocation.csv (what the stages use when a sheet is empty).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class ProjectionTransitionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ProjectionTransition"; } }
        private const string ALLOCATION = "lucasCore_ProjectionAllocation";

        private readonly Panel m_amount = GridHost(240), m_place = GridHost(170);
        private readonly Button m_reset = new Button { Text = "Reset to defaults", AutoSize = true };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(8, 8, 3, 3) };

        internal static TableLayoutPanel Stack(params Control[] cs)
        {
            var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Dock = DockStyle.Fill };
            t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            foreach (Control c in cs) { t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); if (c is Panel && !(c is FlowLayoutPanel)) c.Dock = DockStyle.Fill; t.Controls.Add(c); }
            return t;
        }

        public ProjectionTransitionsView()
        {
            this.SuspendLayout();
            AddGroup(Group("How much changes each year (stage 9)", Stack(
                Note("One row per transition group. Named groups (Urbanization) get one amount for all their types; the placement below decides the type."),
                m_amount,
                Wrapped("Target: the area the group had in the drawn year, per unit of the Target Strata level (counties).  Probability: its burned or changed fraction of each Rate Unit (pyromes), as a map.  None: off after the historical end.  Sampling Set: groups with the same name draw the same historical year.  Excluded GAP: status codes where it may not happen (1|2|3).", 720))));
            AddGroup(Group("Where it goes (stage 10, Projection Setup)", Stack(
                Note("One row per group or member type to place. Rows with the same Surface share one fitted surface; a group without a row is placed at random in its units."),
                m_place,
                Wrapped("Fitted: a regression on the historical record (Spatial Allocation page).  Rules: WUI and GAP weights.  Source Classes: the NLCD codes a cell has the year before (blank = not developed, water or ice).  Event Classes: the codes it changes to, or LANDFIRE:Thinning.  Adjacency: more likely next to developed land (agriculture, for agriculture events), updated during the run.", 720))));
            var r = Row(); r.Controls.Add(m_reset); r.Controls.Add(m_state);
            AddGroup(Group("Defaults", r));
            EndGroups();
            m_reset.Click += (s, e) => Reset();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_amount, SheetName);
            LoadGrid(m_place, ALLOCATION);
            RefreshControls();
        }

        private void Reset()
        {
            if (MessageBox.Show(this, "Replace both tables with the package defaults (defaults/projection/transitions.csv and allocation.csv)?", "Transitions",
                                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var p = Defaults.Load(Sheet, Defaults.PackageFile("defaults", "projection", "transitions.csv"), new Dictionary<string, string> { { "UnitSource", "UnitSourceId" } });
            p.AddRange(Defaults.Load(this.DataFeed.GetDataSheet(ALLOCATION), Defaults.PackageFile("defaults", "projection", "allocation.csv"), null));
            m_state.Text = p.Count == 0 ? "Defaults loaded." : "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : "");
            m_state.ForeColor = p.Count == 0 ? SystemColors.GrayText : Color.Firebrick;
            LoadGrid(m_amount, SheetName); LoadGrid(m_place, ALLOCATION);
        }

        protected override void ShowData()
        {
            m_reset.Enabled = !(this.Scenario != null && this.Scenario.IsResult);
        }
    }
}
