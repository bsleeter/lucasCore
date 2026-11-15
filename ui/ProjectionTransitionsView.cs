// =============================================================================
// ProjectionTransitionsView.cs - the Land Use page of a projection: how much each land-use and harvest group changes, and where it goes
// =============================================================================
// Feed ProjectionTransitions = Projection Transitions (stage 9: amount per group) + Projection Allocation (stage 10: placement per
// group or member type). User 2026-11-14: re-imagined "with a more similar look and feel to the other custom UI pages ... such as for
// the management work", then split by what drives the change: this page holds land use (urbanization, intensification, agriculture)
// and forest harvest; fire moved to the Fire page, reforestation to Natural Change (TransitionWalk.cs: the same rows, each page its
// families). The tables are the record of every group and stay here, behind Show tables ("I dont think we even really need to see the
// table since all the controls are now presented. Perhaps its an option"); source and event classes are edited there. Reset to
// defaults reloads both tables from defaults/projection/transitions.csv and allocation.csv (what the stages use when a sheet is empty).
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
        protected override string SheetName { get { return TransitionWalk.TRANSITIONS; } }
        private DataSheet Alloc { get { return this.DataFeed.GetDataSheet(TransitionWalk.ALLOCATION); } }

        private readonly Panel m_amount = GridHost(240), m_place = GridHost(170);
        private readonly Button m_reset = new Button { Text = "Reset to defaults", AutoSize = true };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(8, 8, 3, 3) };
        private readonly Label m_period = Note(""), m_empty = Note("");
        private readonly Label m_words = new Label { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(3, 4, 3, 6) };
        private readonly TransitionWalk m_walk;
        private readonly CheckBox m_show;
        private readonly GroupBox m_tables;

        internal static TableLayoutPanel Stack(params Control[] cs)
        {
            var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Dock = DockStyle.Fill };
            t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            foreach (Control c in cs) { t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); if (c is Panel && !(c is FlowLayoutPanel)) c.Dock = DockStyle.Fill; t.Controls.Add(c); }
            return t;
        }

        // a page's "Show table(s)" box: the controls are hidden until it is ticked (closed again on each new page)
        internal static CheckBox ShowTable(string text, params Control[] hidden)
        {
            var cb = new CheckBox { Text = text, AutoSize = true, Margin = new Padding(6, 4, 3, 8) };
            Action a = () => { foreach (Control c in hidden) c.Visible = cb.Checked; };
            cb.CheckedChanged += (s, e) => a(); a();
            return cb;
        }

        public ProjectionTransitionsView()
        {
            this.SuspendLayout();
            m_walk = new TransitionWalk(new[] { TransitionWalk.LAND_USE, TransitionWalk.HARVEST, TransitionWalk.OTHER }, () => Sheet, () => Alloc, () => Refreshing, () => RefreshControls());
            m_walk.Title[TransitionWalk.OTHER] = "Other transitions";
            m_walk.FamilyNote[TransitionWalk.OTHER] = "Groups and placement rows not on the Land Use, Fire or Natural Change pages.";
            AddGroup(Group("How the projection draws the future", Stack(
                Note("Each projection year, every group repeats a historical year drawn from the reference period. Fire: the Fire page; reforestation: Natural Change."),
                m_period, m_empty)));
            Root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); Root.Controls.Add(m_walk.Host);
            AddGroup(Group("In words", Stack(m_words)));
            var r = Row(); r.Controls.Add(m_reset); r.Controls.Add(m_state);
            m_tables = Group("The tables (every group, fire and reforestation included)", Stack(
                Note("The record of the choices on the Land Use, Fire and Natural Change pages. Source and event classes (the NLCD codes a change comes from and goes to) are set here only."),
                Caption("How much changes each year (stage 9)"),
                m_amount,
                Wrapped("Target: the area the group had in the drawn year, per unit of the Target Strata level (counties).  Probability: its burned or changed fraction of each Rate Unit (pyromes), as a map.  None: off after the historical end.  Sampling Set: groups with the same name draw the same historical year.  Excluded GAP: status codes where it may not happen (1|2|3).", 720),
                Caption("Where it goes (stage 10)"),
                m_place,
                Wrapped("Fitted: a regression on the historical record (Spatial Allocation page).  Rules: WUI and GAP weights.  Adjacency: only the share of the class the cell becomes around it, read from the annual maps (Ag Change).  Source Classes: the NLCD codes a cell has the year before (blank = not developed, water or ice).  Event Classes: the codes it changes to, or LCMS:standrep / LCMS:partial (Tree Removal that becomes shrub or grass / stays forest).  Adjacency: more likely next to developed land (agriculture, for agriculture events), updated during the run.  Size Distribution: historical patch sizes in ST-Sim - Auto when patches span several model cells, On, Off.", 720),
                r));
            m_show = ShowTable("Show tables", m_tables);
            Root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); Root.Controls.Add(m_show);
            AddGroup(m_tables);
            EndGroups();
            m_reset.Click += (s, e) => Reset();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // open filled in: empty sheets this scenario may edit take the package defaults
            FillIfEmpty(SheetName, Defaults.PackageFile("defaults", "projection", "transitions.csv"), new Dictionary<string, string> { { "UnitSource", "UnitSourceId" } });
            FillIfEmpty(TransitionWalk.ALLOCATION, Defaults.PackageFile("defaults", "projection", "allocation.csv"), null);
            Project p = this.Scenario != null ? this.Scenario.Project : this.DataFeed.Project;
            if (p != null) { try { m_walk.Ms.Load(p, this.Scenario); } catch (Exception) { } }
            LoadGrid(m_amount, SheetName);
            LoadGrid(m_place, TransitionWalk.ALLOCATION);
            m_walk.Rebuild();
            RefreshControls();
        }

        private void Reset()
        {
            if (MessageBox.Show(this, "Replace both tables with the package defaults (defaults/projection/transitions.csv and allocation.csv)? This resets fire and reforestation too.", "Land Use",
                                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var p = Defaults.Load(Sheet, Defaults.PackageFile("defaults", "projection", "transitions.csv"), new Dictionary<string, string> { { "UnitSource", "UnitSourceId" } });
            p.AddRange(Defaults.Load(Alloc, Defaults.PackageFile("defaults", "projection", "allocation.csv"), null));
            m_state.Text = p.Count == 0 ? "Defaults loaded." : "Loaded, except: " + string.Join("; ", p.Take(5)) + (p.Count > 5 ? string.Format(" (+{0} more)", p.Count - 5) : "");
            m_state.ForeColor = p.Count == 0 ? SystemColors.GrayText : Color.Firebrick;
            LoadGrid(m_amount, SheetName); LoadGrid(m_place, TransitionWalk.ALLOCATION);
            m_walk.Rebuild(); RefreshControls();
        }

        protected override void ShowData()
        {
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_reset.Enabled = edit; m_walk.Editable = edit;
            List<string> words = m_walk.Show();
            m_empty.Text = m_walk.HasRows ? "" : "No transition rows: the stages use the package defaults (defaults/projection/transitions.csv). Show tables, then Reset to defaults, fills the tables.";
            m_words.Text = words.Count == 0 ? "No land-use or harvest rows yet." : string.Join(Environment.NewLine, words);
            m_period.Text = ReferencePeriod(this.Scenario);
        }

        // the reference period (Run Settings), in words
        internal static string ReferencePeriod(Scenario sc)
        {
            DataSheet po = sc == null ? null : sc.GetDataSheet("lucasCore_ProjectionOptions");
            System.Data.DataRow o = po == null || !po.HasData() ? null : po.GetDataRow();
            object y0 = o == null ? DBNull.Value : o["ReferenceStartYear"], y1 = o == null ? DBNull.Value : o["ReferenceEndYear"];
            return "Reference period (Run Settings): " + (y0 == DBNull.Value ? "the first historical transition year" : Convert.ToString(y0)) + " to " + (y1 == DBNull.Value ? "the historical end" : Convert.ToString(y1)) + ".";
        }
    }
}
