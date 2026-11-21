// =============================================================================
// StudyAreaView.cs - the Study Area page: pick the kind of unit first (radio buttons), then the units of that kind (drop-down)
// =============================================================================
// Replaces the default grid of lucasCore_StudyArea, whose single drop-down listed all 6,221 units of every source. The sheet itself
// is unchanged (one row per unit, UnitId = a stsim_SecondaryStratum row), so stage 1 reads it as before; the kind chosen is kept in
// Study Area Type (lucasCore_StudyAreaOptions.SourceId). The picker itself is UnitPicker (shared with the Spatial Allocation page).
// The units may be of several kinds (stage 1 takes the cells of any of them): the kind chosen only says which is added next.
// Below the units, "A boundary file of your own" (lucasCore_StudyAreaBoundary; user 2026-11-21): polygons the user supplies, which
// replace the named units (choosing a file removes them, and the picker is off while a file is named), and a name for the study area.
// Built by tools/build_ui.ps1 into lucasCoreUI.dll (C# 5, .NET Framework 4.8, against SyncroSim's own assemblies).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;
using SyncroSim.Core.Forms;

namespace lucasCoreUI
{
    public class StudyAreaView : DataFeedView
    {
        private const string BOUNDARY = "lucasCore_StudyAreaBoundary";
        private readonly UnitPicker m_picker = new UnitPicker("Define the study area by", 120);
        private readonly TextBox m_file = new TextBox { Width = 420, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_browse = new Button { Text = "Browse...", AutoSize = true };
        private readonly Button m_clear = new Button { Text = "Clear", AutoSize = true };
        private readonly TextBox m_name = new TextBox { Width = 260, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 6, 3) };
        private bool m_refreshing;

        public StudyAreaView()
        {
            m_picker.Dock = DockStyle.Fill;
            m_picker.UnitSheet = () => this.DataFeed.GetDataSheet("lucasCore_StudyArea");
            m_picker.KindSheet = () => this.DataFeed.GetDataSheet("lucasCore_StudyAreaOptions");
            m_picker.Changed = RefreshControls; m_picker.MixKinds = true;
            m_picker.EmptyNote = EmptyNote;

            var gb = new GroupBox { Text = "Or a boundary file of your own", Dock = DockStyle.Fill, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink, Padding = new Padding(10, 6, 10, 8), Margin = new Padding(3, 8, 3, 3) };
            var grid = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 4, RowCount = 3 };
            for (int i = 0; i < 4; i++) grid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            grid.Controls.Add(new Label { Text = "Polygons", AutoSize = true, Margin = new Padding(3, 7, 6, 3) }, 0, 0);
            grid.Controls.Add(m_file, 1, 0); grid.Controls.Add(m_browse, 2, 0); grid.Controls.Add(m_clear, 3, 0);
            grid.Controls.Add(new Label { Text = "Study area name", AutoSize = true, Margin = new Padding(3, 7, 6, 3) }, 0, 1);
            grid.Controls.Add(m_name, 1, 1);
            var note = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3),
                Text = "A shapefile, GeoPackage, GeoJSON, KML or zipped shapefile of polygons, in any projection. Its polygons, taken together, are the study area in place of named units. " +
                       "The name is used in logs and figures and for the Data Download's region folder (blank = the file's name)." };
            grid.Controls.Add(note, 0, 2); grid.SetColumnSpan(note, 4);
            gb.Controls.Add(grid);

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Padding = new Padding(8) };
            root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.Controls.Add(m_picker, 0, 0); root.Controls.Add(gb, 0, 1);
            this.Controls.Add(root);

            m_browse.Click += (s, e) =>
            {
                using (var d = new OpenFileDialog { Title = "Study area boundary (polygons)", CheckFileExists = true,
                    Filter = "Polygon files (*.shp;*.gpkg;*.geojson;*.json;*.kml;*.zip)|*.shp;*.gpkg;*.geojson;*.json;*.kml;*.zip|All files (*.*)|*.*" })
                {
                    if (d.ShowDialog(this) == DialogResult.OK) SetFile(d.FileName);
                }
            };
            m_clear.Click += (s, e) => SetFile("");
            m_file.Validated += (s, e) => { if (!m_refreshing && m_file.Text.Trim() != SavedFile()) SetFile(m_file.Text.Trim()); };
            m_name.Validated += (s, e) => { if (!m_refreshing) { string v = m_name.Text.Trim(); Boundary.SetSingleRowData("Name", v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); } };
        }

        private DataSheet Boundary { get { return this.DataFeed.GetDataSheet(BOUNDARY); } }
        private static string Cell(DataSheet ds, string column)
        {
            if (ds == null || !ds.HasData()) return "";
            DataRow r = ds.GetDataRow(); return r == null || r[column] == DBNull.Value ? "" : Convert.ToString(r[column]).Trim();
        }
        private string SavedFile() { return Cell(Boundary, "BoundaryFileName"); }
        private static string NameOf(string name, string file) { return name.Length > 0 ? name : Path.GetFileNameWithoutExtension(file); }

        // a file replaces the named units: they are removed (after asking), and the kind goes back to none
        private void SetFile(string path)
        {
            if (path.Length > 0)
            {
                DataSheet us = this.DataFeed.GetDataSheet("lucasCore_StudyArea");
                List<DataRow> rows = us.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).ToList();
                if (rows.Count > 0)
                {
                    string msg = string.Format("A boundary file replaces the {0} unit{1} already chosen. Continue?", rows.Count, rows.Count == 1 ? "" : "s");
                    if (MessageBox.Show(this, msg, "Study Area", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) { RefreshControls(); return; }
                    us.DeleteRows(rows);
                }
                DataSheet ks = this.DataFeed.GetDataSheet("lucasCore_StudyAreaOptions");
                if (ks.HasData()) ks.SetSingleRowData("SourceId", DBNull.Value);
            }
            Boundary.SetSingleRowData("BoundaryFileName", path.Length == 0 ? (object)DBNull.Value : path);
            RefreshControls();
        }

        // What the picker shows in place of "all of CONUS" when no units are chosen: this scenario's boundary file, else the study
        // area of the first scenario this one depends on that has one (a Build that depends on its Data Download scenario: the study
        // area is entered once; user 2026-11-21. SyncroSim hands a run the dependency's rows). A result holds the rows itself.
        private string EmptyNote()
        {
            string f = SavedFile();
            if (f.Length > 0) return string.Format("Study area: {0}, the polygons of {1}.{2}", NameOf(Cell(Boundary, "Name"), f), f, File.Exists(f) ? "" : " This file is not there.");
            Scenario sc = this.Scenario; if (sc == null || sc.IsResult) return null;
            foreach (Scenario d in sc.Dependencies)
            {
                DataSheet b = d.GetDataSheet(BOUNDARY); string df = Cell(b, "BoundaryFileName");
                if (df.Length > 0) return string.Format("Study area: {0}, the polygons of {1}, from \"{2}\", a scenario this one depends on. A study area set here would replace it.", NameOf(Cell(b, "Name"), df), df, d.Name);
                DataSheet x = d.GetDataSheet("lucasCore_StudyArea"); if (x == null || !x.HasData()) continue;
                List<string> names = x.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted && r["UnitId"] != DBNull.Value)
                    .Select(r => m_picker.UnitName(Convert.ToInt32(r["UnitId"])) ?? "unit " + r["UnitId"]).OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase).ToList();
                if (names.Count == 0) continue;
                return string.Format("Study area: {0} unit{1} from \"{2}\", a scenario this one depends on: {3}. Units chosen here would replace them.",
                                     names.Count, names.Count == 1 ? "" : "s", d.Name, string.Join("; ", names));
            }
            return null;
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            // the lists are read when the page opens: SyncroSim's sheet monitors read a single row, so they cannot watch multi-row lists
            m_picker.LoadLists(dataFeed.Project);
            RefreshControls();
        }

        public override void RefreshControls()
        {
            base.RefreshControls();
            if (this.DataFeed == null) return;
            bool editable = !(this.Scenario != null && this.Scenario.IsResult);
            string f = SavedFile();
            m_refreshing = true;
            try { m_file.Text = f; m_name.Text = Cell(Boundary, "Name"); }
            finally { m_refreshing = false; }
            m_file.Enabled = editable; m_browse.Enabled = editable; m_name.Enabled = editable; m_clear.Enabled = editable && f.Length > 0;
            m_picker.ShowData(editable && f.Length == 0);   // (the units are off while a boundary file is named)
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { base.OnRowsAdded(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { base.OnRowsDeleted(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
        protected override void OnRowsModified(object sender, DataSheetRowEventArgs e) { base.OnRowsModified(sender, e); if (!m_picker.IsRefreshing) RefreshControls(); }
    }
}
