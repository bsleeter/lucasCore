// =============================================================================
// BuildOptionsView.cs - the Build Options page: model grid, historical period, strata and land cover, in framed groups
// =============================================================================
// Single-row sheet lucasCore_BuildOptions. The projection end year is no longer set here (its column is kept, hidden, for older
// libraries): it is in Projection > Run Settings, and the climate of the projection years comes from a Projection Climate scenario
// (stage 11). Spatial multiprocessing: a tile count and strata level that stage 1 turns into the Build result's tile mask. Text fields and
// the forest type list use SyncroSim's bindings; the strata and tile lists are set by hand because they write
// blanks (the default sources). The page wraps to the window and scrolls (Fit, in LucasView.cs).
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

        private class Item
        {
            public object Value { get; set; }
            public string Name { get; set; }
            public override string ToString() { return Name; }
        }

        private readonly TextBox m_resolution = new TextBox();
        private readonly TextBox m_start = new TextBox();
        private readonly TextBox m_end = new TextBox();
        private readonly ComboBox m_secondary = new ComboBox();
        private readonly ComboBox m_tertiary = new ComboBox();
        private readonly ComboBox m_forest = new ComboBox();
        private readonly CheckBox m_tiled = new CheckBox { Text = "Split runs into tiles:", AutoSize = true, Margin = new Padding(3, 5, 6, 3) };
        private readonly TextBox m_tiles = new TextBox();
        private readonly ComboBox m_tileLevel = new ComboBox();
        private readonly Label m_tileState = new Label { AutoSize = true, MaximumSize = new Size(680, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 3, 3, 3) };
        private readonly TableLayoutPanel m_root = new TableLayoutPanel();
        private readonly Panel m_scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true };   // the page scrolls here (see LucasView)
        private bool m_refreshing;

        public BuildOptionsView() { BuildUi(); }

        // ---- layout ---------------------------------------------------------------------------------------------------------
        private static Label Caption(string text) { return new Label { Text = text, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 6, 3) }; }
        private static Label Note(string text) { return new Label { Text = text, AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 3, 3) }; }
        private static TextBox Number(TextBox t, int width) { t.Width = width; t.TextAlign = HorizontalAlignment.Right; t.Anchor = AnchorStyles.Left; t.Margin = new Padding(3, 3, 12, 3); return t; }

        // a framed group: a flowing row of fields, then any long notes each on a row of their own (a wrapped note inside the flowing
        // row did not give the row its wrapped height, and was cut off)
        private static GroupBox Group(string title, out FlowLayoutPanel row, params Control[] below)
        {
            var gb = new GroupBox { Text = title, Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink, Padding = new Padding(10, 6, 10, 8), Margin = new Padding(3, 3, 3, 8) };
            var col = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink, ColumnCount = 1 };
            col.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            row = new FlowLayoutPanel { AutoSize = true, WrapContents = true, FlowDirection = FlowDirection.LeftToRight, Margin = new Padding(0) };
            col.RowStyles.Add(new RowStyle(SizeType.AutoSize)); col.Controls.Add(row);
            foreach (Control c in below) { col.RowStyles.Add(new RowStyle(SizeType.AutoSize)); col.Controls.Add(c); }
            gb.Controls.Add(col);
            return gb;
        }

        private void BuildUi()
        {
            this.SuspendLayout();
            m_root.Dock = DockStyle.Top; m_root.ColumnCount = 1; m_root.Padding = new Padding(8); m_root.AutoSize = true; m_root.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink;
            m_root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            Fit.Attach(m_scroll);
            FlowLayoutPanel r;

            GroupBox gGrid = Group("Model grid", out r);
            r.Controls.Add(Caption("Cell size (m):")); r.Controls.Add(Number(m_resolution, 70));
            r.Controls.Add(Note("1000 = 1 km. Finer cells take longer: a 150 m pyrome runs about 12 minutes per simulated year."));

            GroupBox gHist = Group("Historical period", out r,
                Note("Land use, disturbance and climate are taken from these years' data. Projections start the year after the end year; their end year is set in Projection > Run Settings, and their climate in a Projection Climate scenario."));
            r.Controls.Add(Caption("Start year:")); r.Controls.Add(Number(m_start, 60));
            r.Controls.Add(Caption("End year:")); r.Controls.Add(Number(m_end, 60));

            GroupBox gStrata = Group("Strata", out r);
            r.Controls.Add(Caption("Secondary:")); r.Controls.Add(List(m_secondary, 200));
            r.Controls.Add(Caption("Tertiary:")); r.Controls.Add(List(m_tertiary, 200));
            r.Controls.Add(Note("Primary strata are always the FIA ecodivisions."));
            m_secondary.SelectionChangeCommitted += (s, e) => WriteSource(m_secondary, "SecondarySourceId");
            m_tertiary.SelectionChangeCommitted += (s, e) => WriteSource(m_tertiary, "TertiarySourceId");

            GroupBox gTiles = Group("Spatial multiprocessing", out r, m_tileState,
                Note("ST-Sim runs the tiles of a spatial run in parallel and merges them. Stage 1 writes the tile map into the Build result, so the historical run and every projection on this Build are split the same way (a projection can set its own in Run Settings). Units are packed into tiles of about equal area, largest first, so no unit is split. A projection target must not be split between tiles, so every Target group uses this strata level. Tiled runs also need Library > Properties > Multiprocessing on, with about as many jobs as tiles. A change takes effect the next time the Build runs."));
            r.Controls.Add(m_tiled); r.Controls.Add(Number(m_tiles, 50)); r.Controls.Add(Caption("of whole units of")); r.Controls.Add(List(m_tileLevel, 240));
            m_tiled.CheckedChanged += (s, e) => { if (m_refreshing) return; Sheet.SetSingleRowData("SpatialTiles", m_tiled.Checked ? (object)Math.Max(2, Math.Min(8, Environment.ProcessorCount)) : DBNull.Value); RefreshControls(); };
            m_tiles.Validated += (s, e) => { if (m_refreshing) return; int n; string v = m_tiles.Text.Trim(); if (v.Length == 0) Sheet.SetSingleRowData("SpatialTiles", DBNull.Value); else if (int.TryParse(v, out n) && n >= 1) Sheet.SetSingleRowData("SpatialTiles", n); RefreshControls(); };
            m_tileLevel.SelectionChangeCommitted += (s, e) => { if (!m_refreshing) Sheet.SetSingleRowData("SpatialTilesStrata", m_tileLevel.SelectedIndex + 1); };
            m_secondary.SelectionChangeCommitted += (s, e) => TileLevelNames();
            m_tertiary.SelectionChangeCommitted += (s, e) => TileLevelNames();

            GroupBox gCover = Group("Land cover", out r);
            r.Controls.Add(Caption("Forest type map:")); r.Controls.Add(List(m_forest, 200));
            r.Controls.Add(Note("Assigns the forest type of forest cells; other cover comes from NLCD, RCMAP and C-CAP."));

            foreach (GroupBox g in new[] { gGrid, gHist, gStrata, gCover, gTiles }) { m_root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); m_root.Controls.Add(g); }

            m_scroll.Controls.Add(m_root); this.Controls.Add(m_scroll);
            this.ResumeLayout(false);
        }

        // the tile level list, named by the strata chosen above
        private void TileLevelNames()
        {
            bool was = m_refreshing; m_refreshing = true;
            try
            {
                int k = m_tileLevel.SelectedIndex;
                m_tileLevel.Items.Clear();
                m_tileLevel.Items.Add("Primary: FIA ecodivisions"); m_tileLevel.Items.Add("Secondary: " + Bare(m_secondary)); m_tileLevel.Items.Add("Tertiary: " + Bare(m_tertiary));
                m_tileLevel.SelectedIndex = k >= 0 && k < 3 ? k : 1;
            }
            finally { m_refreshing = was; }
            if (!was) RefreshControls();
        }
        private static string Bare(ComboBox c) { return c.SelectedItem == null ? "" : c.SelectedItem.ToString().Replace(" (default)", ""); }

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
            // the strata lists: Stratum Sources, plus a blank for the default source (read when the page opens)
            DataTable src = this.DataFeed.Project.GetDataSheet(SOURCES).GetData();
            List<Item> items = src.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted && x["Number"] != DBNull.Value)
                .OrderBy(x => Convert.ToInt32(x["Number"])).Select(x => new Item { Value = Convert.ToInt32(x["StratumSourceId"]), Name = Convert.ToString(x["Name"]) }).ToList();
            FillSources(m_secondary, items, "States (default)");
            FillSources(m_tertiary, items, "Federal Lands (default)");
            RefreshControls(); TileLevelNames();
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

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            m_refreshing = true;
            try
            {
                Select(m_secondary, Value("SecondarySourceId"));
                Select(m_tertiary, Value("TertiarySourceId"));
                object tiles = Value("SpatialTiles"); bool on = tiles != DBNull.Value && Convert.ToInt32(tiles) > 1;
                m_tiled.Checked = on; m_tiles.Enabled = m_tileLevel.Enabled = on; m_tiles.Text = tiles == DBNull.Value ? "" : Convert.ToString(tiles);
                object lvl = Value("SpatialTilesStrata"); if (m_tileLevel.Items.Count == 3) m_tileLevel.SelectedIndex = lvl == DBNull.Value ? 1 : Math.Max(0, Math.Min(2, Convert.ToInt32(lvl) - 1));
                m_tileState.Text = on ? string.Format("{0} tiles of whole {1} units: written by stage 1.", tiles, m_tileLevel.SelectedItem) : "Off: runs on this Build are one job (unless a projection sets its own tiles in Run Settings).";
                m_root.Enabled = this.ShouldEnableView();
            }
            finally { m_refreshing = false; }
            Fit.Apply(m_scroll);
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!m_refreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!m_refreshing) RefreshControls(); }
    }
}
