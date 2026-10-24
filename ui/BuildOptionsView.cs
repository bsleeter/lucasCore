// =============================================================================
// BuildOptionsView.cs - the Build Options page: grouped fields, and a Run a projection check box that turns the end year on and off
// =============================================================================
// Single-row sheet lucasCore_BuildOptions, unchanged: a blank ProjectionEndYear still means no projection (stage 7 reads it that way),
// so the check box needs no column of its own. Text fields and the forest type list use SyncroSim's bindings; the strata lists and
// the check box are set by hand because they write blanks (the default sources, no projection).
// Built by tools/build_ui.ps1 into lucasCoreUI.dll.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public class BuildOptionsView : DataFeedView
    {
        private const string SHEET = "lucasCore_BuildOptions";
        private const string SOURCES = "lucasCore_StratumSource";
        private const int DEFAULT_PROJECTION_END = 2100;

        private class Item
        {
            public object Value { get; set; }
            public string Name { get; set; }
            public override string ToString() { return Name; }
        }

        private readonly TextBox m_resolution = new TextBox();
        private readonly TextBox m_start = new TextBox();
        private readonly TextBox m_end = new TextBox();
        private readonly CheckBox m_project = new CheckBox();
        private readonly TextBox m_projEnd = new TextBox();
        private readonly Label m_projEndLabel = new Label();
        private readonly Label m_projNote = new Label();
        private readonly ComboBox m_secondary = new ComboBox();
        private readonly ComboBox m_tertiary = new ComboBox();
        private readonly ComboBox m_forest = new ComboBox();
        private readonly Label m_gridNote = new Label();
        private readonly TableLayoutPanel m_root = new TableLayoutPanel();
        private bool m_refreshing;

        public BuildOptionsView() { BuildUi(); }

        // ---- layout ---------------------------------------------------------------------------------------------------------
        private static Label Caption(string text) { return new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 6, 3) }; }
        private static Label Note(string text) { return new Label { Text = text, AutoSize = true, ForeColor = SystemColors.GrayText, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 3, 3) }; }
        private static TextBox Number(TextBox t, int width) { t.Width = width; t.TextAlign = HorizontalAlignment.Right; t.Anchor = AnchorStyles.Left; t.Margin = new Padding(3, 3, 12, 3); return t; }

        private static GroupBox Group(string title, out FlowLayoutPanel row)
        {
            var gb = new GroupBox { Text = title, Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink, Padding = new Padding(10, 6, 10, 8), Margin = new Padding(3, 3, 3, 8) };
            row = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, FlowDirection = FlowDirection.LeftToRight };
            gb.Controls.Add(row);
            return gb;
        }

        private void BuildUi()
        {
            this.SuspendLayout();
            m_root.Dock = DockStyle.Fill; m_root.ColumnCount = 1; m_root.Padding = new Padding(8); m_root.AutoScroll = true;
            FlowLayoutPanel r;

            GroupBox gGrid = Group("Model grid", out r);
            r.Controls.Add(Caption("Cell size (m):")); r.Controls.Add(Number(m_resolution, 70));
            m_gridNote.Text = "1000 = 1 km. Finer cells take longer: a 150 m pyrome runs about 12 minutes per simulated year.";
            m_gridNote.ForeColor = SystemColors.GrayText; m_gridNote.AutoSize = true; m_gridNote.Margin = new Padding(3, 7, 3, 3);
            r.Controls.Add(m_gridNote);

            GroupBox gHist = Group("Historical period", out r);
            r.Controls.Add(Caption("Start year:")); r.Controls.Add(Number(m_start, 60));
            r.Controls.Add(Caption("End year:")); r.Controls.Add(Number(m_end, 60));
            r.Controls.Add(Note("Land use, disturbance and climate are taken from these years' data."));

            GroupBox gProj = Group("Projection", out r);
            m_project.Text = "Run a projection"; m_project.AutoSize = true; m_project.Margin = new Padding(3, 5, 18, 3);
            m_project.CheckedChanged += OnProjectChanged;
            r.Controls.Add(m_project);
            m_projEndLabel.Text = "End year:"; m_projEndLabel.AutoSize = true; m_projEndLabel.Anchor = AnchorStyles.Left; m_projEndLabel.Margin = new Padding(3, 7, 6, 3);
            r.Controls.Add(m_projEndLabel); r.Controls.Add(Number(m_projEnd, 60));
            m_projNote.AutoSize = true; m_projNote.ForeColor = SystemColors.GrayText; m_projNote.Margin = new Padding(3, 7, 3, 3);
            r.Controls.Add(m_projNote);

            GroupBox gStrata = Group("Strata", out r);
            r.Controls.Add(Caption("Secondary:")); r.Controls.Add(List(m_secondary, 200));
            r.Controls.Add(Caption("Tertiary:")); r.Controls.Add(List(m_tertiary, 200));
            r.Controls.Add(Note("Primary strata are always the FIA ecodivisions."));
            var mp = new Label { Text = "Spatial multiprocessing: projections can be split into tiles of whole units of one of these three strata (chosen in Projection > Run Settings), and every target then uses that level. If you will use it, set the secondary or tertiary strata here to a layer that suits tiles (counties, HUCs) - it cannot be changed later in the projection settings.",
                                 AutoSize = true, MaximumSize = new Size(680, 0), ForeColor = Color.DarkGoldenrod, Margin = new Padding(3, 7, 3, 3) };
            r.SetFlowBreak(r.Controls[r.Controls.Count - 1], true); r.Controls.Add(mp);
            m_secondary.SelectionChangeCommitted += (s, e) => WriteSource(m_secondary, "SecondarySourceId");
            m_tertiary.SelectionChangeCommitted += (s, e) => WriteSource(m_tertiary, "TertiarySourceId");

            GroupBox gCover = Group("Land cover", out r);
            r.Controls.Add(Caption("Forest type map:")); r.Controls.Add(List(m_forest, 200));
            r.Controls.Add(Note("Assigns the forest type of forest cells; other cover comes from NLCD, RCMAP and C-CAP."));

            foreach (GroupBox g in new[] { gGrid, gHist, gProj, gStrata, gCover }) { m_root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); m_root.Controls.Add(g); }
            m_root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            this.Controls.Add(m_root);
            this.ResumeLayout(false);
        }

        private static ComboBox List(ComboBox c, int width) { c.DropDownStyle = ComboBoxStyle.DropDownList; c.Width = width; c.Anchor = AnchorStyles.Left; c.Margin = new Padding(3, 3, 12, 3); return c; }

        // ---- data -----------------------------------------------------------------------------------------------------------
        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // the forest type list is bound: its items carry the column's list values
            m_forest.DisplayMember = "Name"; m_forest.ValueMember = "Value";
            m_forest.DataSource = new List<Item> { new Item { Value = 1, Name = "LANDFIRE EVT" }, new Item { Value = 2, Name = "USFS forest type groups" } };
            this.SetComboBoxBinding(m_forest, "ForestTypeMap");
            this.SetTextBoxBinding(m_resolution, "Resolution");
            this.SetTextBoxBinding(m_start, "StartYear");
            this.SetTextBoxBinding(m_end, "EndYear");
            this.SetTextBoxBinding(m_projEnd, "ProjectionEndYear");
            // the strata lists: Stratum Sources, plus a blank for the default source (read when the page opens)
            DataTable src = this.DataFeed.Project.GetDataSheet(SOURCES).GetData();
            List<Item> items = src.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted && x["Number"] != DBNull.Value)
                .OrderBy(x => Convert.ToInt32(x["Number"])).Select(x => new Item { Value = Convert.ToInt32(x["StratumSourceId"]), Name = Convert.ToString(x["Name"]) }).ToList();
            FillSources(m_secondary, items, "States (default)");
            FillSources(m_tertiary, items, "Federal Lands (default)");
            RefreshControls();
        }

        private static void FillSources(ComboBox c, List<Item> items, string blank)
        {
            c.Items.Clear();
            c.Items.Add(new Item { Value = DBNull.Value, Name = blank });
            foreach (Item i in items) c.Items.Add(i);
        }

        private DataSheet Sheet { get { return this.DataFeed.GetDataSheet(SHEET); } }

        private object Value(string column)
        {
            DataSheet ds = Sheet;
            if (!ds.HasData()) return DBNull.Value;
            DataRow r = ds.GetDataRow();
            return r == null ? DBNull.Value : r[column];
        }

        private static void Select(ComboBox c, object value)
        {
            int idx = 0;
            for (int i = 1; i < c.Items.Count; i++)
                if (value != DBNull.Value && Convert.ToInt32(((Item)c.Items[i]).Value) == Convert.ToInt32(value)) { idx = i; break; }
            if (c.Items.Count > 0) c.SelectedIndex = idx;
        }

        private void WriteSource(ComboBox c, string column)
        {
            if (m_refreshing) return;
            Item i = c.SelectedItem as Item;
            Sheet.SetSingleRowData(column, i == null ? DBNull.Value : i.Value);
        }

        private void OnProjectChanged(object sender, EventArgs e)
        {
            if (m_refreshing) return;
            // no projection = a blank end year (what the stages read); a projection starts with the default end year
            object v = Value("ProjectionEndYear");
            if (m_project.Checked && v == DBNull.Value) Sheet.SetSingleRowData("ProjectionEndYear", DEFAULT_PROJECTION_END);
            if (!m_project.Checked && v != DBNull.Value) Sheet.SetSingleRowData("ProjectionEndYear", DBNull.Value);
            this.RefreshBoundControls();
            UpdateStates();
        }

        private void UpdateStates()
        {
            bool on = m_project.Checked;
            m_projEnd.Enabled = on; m_projEndLabel.Enabled = on;
            object end = Value("EndYear");
            m_projNote.Text = on
                ? string.Format("Starts in {0}. Choose the climate scenario, model and replicate in Climate Options.", end == DBNull.Value ? "the year after the historical end" : Convert.ToString(Convert.ToInt32(end) + 1))
                : "Historical only.";
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            m_refreshing = true;
            try
            {
                m_project.Checked = Value("ProjectionEndYear") != DBNull.Value;
                Select(m_secondary, Value("SecondarySourceId"));
                Select(m_tertiary, Value("TertiarySourceId"));
                UpdateStates();
                m_root.Enabled = this.ShouldEnableView();
            }
            finally { m_refreshing = false; }
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!m_refreshing) RefreshControls(); }
    }
}
