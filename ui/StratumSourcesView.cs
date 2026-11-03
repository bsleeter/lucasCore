// =============================================================================
// StratumSourcesView.cs - the Stratum Sources page of the project: where each source's polygons are read, in the Data Sources style
// =============================================================================
// Multi-row project sheet lucasCore_StratumSource (written by tools/new-library.R and LibrarySetup from defaults/strata/presets.csv).
// One row per source (user, 2026-11-02): its name with its description and unit count in grey under it; the polygon file; Browse; Use
// home (clears the file); and a mark saying where stage 1 will read it, by the same rule as src/strata.R strata_path: the file when it
// exists on this machine (a relative file is under the package's defaults/strata), else, for a preset with a Data Download dataset
// (presets.csv DataSource), its place in Data Sources Home (data-sources.csv HomePath, at the home's top: strata are national). A home
// read uses the preset's own layer and fields, so the row's Layer, Id Field and Value Field matter only with a file of its own.
// "Use home copies for all" clears every file the home can replace, after asking. The full grid, for a custom source or the read
// settings, is under Advanced settings, shown on request.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class StratumSourcesView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_StratumSource"; } }
        private const string DataSourceSheet = "lucasCore_DataSource";

        // Where: what the mark found (Own = the row's file, Package = the package's ecodivisions, Home, HomeMissingFile = a missing file, so the home)
        private enum Where { None, Own, Package, Home, HomeMissingFile }
        private class Entry { public string Name, Description, Prefix, DataSource, HomePath, DatasetName, PackageFile, Shown = ""; public int Number; public TextBox Path; public Label Detail, State, Reading; public Button UseHome; public Where Reads; public bool HomeHas; }
        private readonly List<Entry> m_entries = new List<Entry>();
        private readonly ToolTip m_tip = new ToolTip { AutoPopDelay = 20000 };
        private TableLayoutPanel m_table; private Label m_homeNote, m_summary; private Button m_all, m_advanced; private Panel m_grid;
        private Dictionary<string, string> m_presetSource;                  // preset name -> Data Sources column
        private Dictionary<string, string> m_presetFile;                    // preset name -> its own File (only the ecodivisions have one)
        private Dictionary<string, string[]> m_meta;                       // Data Sources column -> data-sources.csv row
        private bool m_built;

        private const int NameWidth = 260, Beside = 330, MinPath = 220;

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            if (!m_built) { BuildPage(); m_built = true; }
            RefreshControls();
        }

        private void ReadTables()
        {
            m_presetSource = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            m_presetFile = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            m_meta = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            string pkg = LibrarySetup.PackageDirectory();
            try
            {
                List<string[]> p = Csv.Read(Path.Combine(pkg, "defaults", "strata", "presets.csv"));
                int ds = Array.IndexOf(p[0], "DataSource"), fi = Array.IndexOf(p[0], "File");
                foreach (string[] r in p.Skip(1))
                {
                    if (ds >= 0 && r.Length > ds && r[ds].Length > 0) m_presetSource[r[0]] = r[ds];
                    if (fi >= 0 && r.Length > fi && r[fi].Length > 0) m_presetFile[r[0]] = r[fi];
                }
            }
            catch (Exception) { }
            try { foreach (string[] r in Csv.Read(Path.Combine(pkg, "defaults", "library", "data-sources.csv")).Skip(1)) if (r.Length >= 11) m_meta[r[0]] = r; }
            catch (Exception) { }
        }

        private void BuildPage()
        {
            this.SuspendLayout();
            ReadTables();
            var intro = Column();
            intro.Controls.Add(Note("Stage 1 of the Build cuts the study area and its strata from these polygons. Each source is read from one of three places: the Polygon File named here, whenever that file exists on this machine; else the copy a Data Download put in Data Sources Home; or, for the FIA ecodivisions, the copy that ships with lucasCore. A Data Download fills the home but never changes this page, so a source keeps reading its own file until you clear it (Use home). Changes apply to the next Build; results already made keep their strata."));
            m_summary = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 8, 3, 3), Font = new Font(this.Font, FontStyle.Bold) };
            intro.Controls.Add(m_summary);
            var bar = Row(); bar.Margin = new Padding(0, 6, 0, 0);
            m_all = new Button { Text = "Use home copies for all", AutoSize = true };
            m_tip.SetToolTip(m_all, "Clears the Polygon File of every source the home holds, so each is read from Data Sources Home");
            m_all.Click += (s, a) => UseHomeForAll();
            m_homeNote = new Label { AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(9, 8, 3, 3), ForeColor = SystemColors.GrayText };
            bar.Controls.Add(m_all); bar.Controls.Add(m_homeNote); intro.Controls.Add(bar);
            AddGroup(Group("Stratum Sources", intro));

            m_table = new TableLayoutPanel { AutoSize = true, ColumnCount = 5 };
            m_table.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, NameWidth));
            for (int i = 0; i < 4; i++) m_table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            AddGroup(Group("Sources", m_table));

            var adv = Column();
            adv.Controls.Add(Note("Every column of the sheet: the number and name prefix of each source's units, the layer and fields it is read with, its crosswalk and unit list, and how overlaps and uncovered land are handled (defaults/strata/README.md). A custom source is a new row here; then run tools/new-library.R with --rebuild-strata, which writes its units into the strata lists."));
            m_advanced = new Button { Text = "Show advanced settings", AutoSize = true, Margin = new Padding(3, 6, 3, 3) };
            m_grid = GridHost(320); m_grid.Visible = false;
            m_advanced.Click += (s, a) => ToggleGrid();
            adv.Controls.Add(m_advanced); adv.Controls.Add(m_grid);
            AddGroup(Group("Advanced settings", adv));
            EndGroups();
            this.Resize += (s, a) => SizePaths();
            this.ResumeLayout(false);
        }

        private void ToggleGrid()
        {
            if (!m_grid.Visible)
            {
                try { if (m_grid.Controls.Count == 0) LoadGrid(m_grid, SheetName); }
                catch (Exception ex) { MessageBox.Show(this, "Could not show the grid: " + ex.Message, "Stratum Sources"); return; }
            }
            m_grid.Visible = !m_grid.Visible;
            m_advanced.Text = m_grid.Visible ? "Hide advanced settings" : "Show advanced settings";
            if (m_grid.Visible) m_grid.Width = Math.Max(400, this.ClientSize.Width - 60);
        }

        // ---- rows ------------------------------------------------------------------------------------------------------------
        private List<DataRow> Rows()
        {
            DataSheet ds = Sheet; if (ds == null) return new List<DataRow>();
            return ds.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).OrderBy(r => r["Number"] == DBNull.Value ? int.MaxValue : Convert.ToInt32(r["Number"])).ToList();
        }

        // the table is remade when the sources change (a row added or removed in the grid), else only refilled
        private void MakeRows(List<DataRow> rows)
        {
            m_table.SuspendLayout();
            m_table.Controls.Clear(); m_table.RowStyles.Clear(); m_table.RowCount = 0; m_entries.Clear();
            foreach (DataRow r in rows)
            {
                var e = new Entry { Name = Show(r["Name"]), Description = Show(r["Description"]), Prefix = Show(r["Prefix"]), Number = r["Number"] == DBNull.Value ? 0 : Convert.ToInt32(r["Number"]) };
                string col; if (m_presetSource.TryGetValue(e.Name, out col)) e.DataSource = col;
                if (e.DataSource == null && e.Number == 1) e.DataSource = "EcodivisionFile";
                string[] m; if (e.DataSource != null && m_meta.TryGetValue(e.DataSource, out m)) { e.HomePath = m[10].Length > 0 ? m[10] : null; e.DatasetName = m[4]; }
                string pf; if (m_presetFile.TryGetValue(e.Name, out pf)) e.PackageFile = pf;
                m_entries.Add(e); AddEntry(e);
            }
            m_table.ResumeLayout(true);
        }

        private void AddEntry(Entry e)
        {
            int r = m_table.RowCount; m_table.RowCount = r + 1; m_table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var cell = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 3, 9, 3) };
            var name = new Label { Text = e.Name, AutoSize = true, MaximumSize = new Size(NameWidth - 12, 0), Tag = Fit.Fixed, Margin = new Padding(3, 4, 3, 0) };
            e.Detail = new Label { AutoSize = true, MaximumSize = new Size(NameWidth - 12, 0), Tag = Fit.Fixed, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 1, 3, 0) };
            cell.Controls.Add(name); cell.Controls.Add(e.Detail);
            m_tip.SetToolTip(name, e.Name + (e.Description.Length > 0 ? Environment.NewLine + e.Description : "") +
                                   (e.DatasetName != null ? Environment.NewLine + "Data Download dataset: " + e.DatasetName + " (" + e.DataSource + ")" : Environment.NewLine + "Not fetched by Data Download: needs a file of its own"));
            e.Path = new TextBox { Width = MinPath, Anchor = AnchorStyles.Left, Margin = new Padding(3, 4, 3, 3) };
            var browse = new Button { Text = "Browse...", AutoSize = true, Margin = new Padding(3, 3, 3, 3) };
            // the ecodivisions are not downloaded: their button puts back the package's own copy instead
            e.UseHome = new Button { Text = e.PackageFile != null ? "Use package copy" : "Use home", AutoSize = true, Margin = new Padding(3, 3, 3, 3), Enabled = false };
            m_tip.SetToolTip(e.UseHome, e.PackageFile != null ? "Reads the copy that ships with lucasCore (defaults/strata/" + e.PackageFile + ")" : "Clears the file, so the polygons are read from Data Sources Home");
            e.State = new Label { AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(6, 7, 3, 3), Font = new Font(this.Font, FontStyle.Bold) };
            m_table.Controls.Add(cell, 0, r); m_table.Controls.Add(e.Path, 1, r); m_table.Controls.Add(browse, 2, r); m_table.Controls.Add(e.UseHome, 3, r); m_table.Controls.Add(e.State, 4, r);
            // under the path: the whole path the next Build reads, which a narrow box cannot show
            m_table.RowCount = r + 2; m_table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            e.Reading = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 0, 3, 8) };
            m_table.Controls.Add(e.Reading, 1, r + 1); m_table.SetColumnSpan(e.Reading, 4);

            Entry en = e;
            // written only when the text was changed here: leaving a box never writes back what it was shown
            e.Path.Validated += (s, a) => { if (Refreshing) return; string v = en.Path.Text.Trim(); if (v == en.Shown) return; SetFile(en, v.Length == 0 ? (object)DBNull.Value : v); };
            browse.Click += (s, a) => Browse(en);
            e.UseHome.Click += (s, a) => SetFile(en, en.PackageFile != null ? (object)en.PackageFile : DBNull.Value);
        }

        private void SetFile(Entry e, object v)
        {
            DataSheet ds = Sheet;
            DataRow r = ds.GetData().Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted && Show(x["Name"]) == e.Name);
            if (r == null) return;
            object now = r["File"];
            if (Equals(now, v) || (now != DBNull.Value && v != DBNull.Value && Convert.ToString(now) == Convert.ToString(v))) return;
            ds.BeginModifyRows(); try { r["File"] = v; } finally { ds.EndModifyRows(); }
            RefreshControls();
        }

        // Browse shows .shp and .gpkg; a file geodatabase is a folder (WBD_National_GDB.gdb), so it is typed into the box
        private void Browse(Entry e)
        {
            string now = Resolve(e.Path.Text.Trim());
            using (var d = new OpenFileDialog { Title = "Choose the polygons for " + e.Name, CheckFileExists = true,
                                                Filter = "Polygon files (*.shp;*.gpkg)|*.shp;*.gpkg|All files (*.*)|*.*" })
            {
                try { if (now.Length > 0 && Directory.Exists(Path.GetDirectoryName(now))) { d.InitialDirectory = Path.GetDirectoryName(now); d.FileName = Path.GetFileName(now); } } catch (Exception) { }
                if (d.ShowDialog(this) == DialogResult.OK) SetFile(e, d.FileName.Replace('\\', '/'));
            }
        }

        private void UseHomeForAll()
        {
            List<Entry> can = m_entries.Where(e => e.Path.Text.Trim().Length > 0 && HomeCopy(e) != null).ToList();
            if (can.Count == 0) { MessageBox.Show(this, "No source has a file of its own that the home could replace.", "Stratum Sources"); return; }
            if (MessageBox.Show(this, string.Format("Read these {0} sources from Data Sources Home instead of their own files?{1}{1}{2}{1}{1}The strata of the next Build will come from the home's copies; the results already made keep theirs. The home's copies can differ from older files (Federal Lands: PAD-US 4.0 fee ownership, not the National Atlas boundaries).",
                                                can.Count, Environment.NewLine, string.Join(Environment.NewLine, can.Select(e => "  " + e.Name))),
                                "Use home copies", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            DataSheet ds = Sheet; DataTable dt = ds.GetData();
            ds.BeginModifyRows();
            try { foreach (Entry e in can) { DataRow r = dt.Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted && Show(x["Name"]) == e.Name); if (r != null) r["File"] = DBNull.Value; } }
            finally { ds.EndModifyRows(); }
            RefreshControls();
        }

        // ---- where each source is read ------------------------------------------------------------------------------------------
        private string Home()
        {
            // read the table itself: another sheet's single-row helpers see no data until that sheet's own page has loaded it
            try
            {
                DataRow r = this.DataFeed.Project.GetDataSheet(DataSourceSheet).GetData().Rows.Cast<DataRow>().FirstOrDefault(x => x.RowState != DataRowState.Deleted);
                return r == null ? "" : Show(r["DataSourcesHome"]).Trim();
            }
            catch (Exception) { return ""; }
        }

        // a relative file is under the package's defaults/strata (src/strata.R strata_file)
        private static string Resolve(string f)
        {
            if (f.Length == 0) return f;
            try { return Path.IsPathRooted(f) ? f : Path.Combine(LibrarySetup.PackageDirectory(), "defaults", "strata", f).Replace('\\', '/'); }
            catch (Exception) { return f; }
        }
        private static bool Exists(string f) { try { return f.Length > 0 && (File.Exists(f) || Directory.Exists(f)); } catch (Exception) { return false; } }

        // the home's copy of a source, or null (the strata datasets are national: the home's top only)
        private string m_home = "";
        private string HomeCopy(Entry e)
        {
            if (e.HomePath == null || m_home.Length == 0 || e.Number == 1) return null;
            int n; return DataSourcesView.Place(m_home, e.HomePath, out n);
        }

        // the units each source has in the strata lists (the primary list for ecodivisions)
        private Dictionary<string, int> UnitCounts()
        {
            var c = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (string sheet in new[] { "stsim_SecondaryStratum", "stsim_TertiaryStratum" })
                {
                    DataSheet s = this.DataFeed.Project.GetDataSheet(sheet); if (s == null) continue;
                    foreach (DataRow r in s.GetData().Rows) { if (r.RowState == DataRowState.Deleted) continue;
                        string n = Show(r["Name"]); int k = n.IndexOf(": ", StringComparison.Ordinal); if (k <= 0) continue;
                        string p = n.Substring(0, k); int v; c.TryGetValue(p + "|" + sheet, out v); c[p + "|" + sheet] = v + 1; }
                }
                DataSheet st = this.DataFeed.Project.GetDataSheet("stsim_Stratum");
                if (st != null) c["|primary"] = st.GetData().Rows.Cast<DataRow>().Count(r => r.RowState != DataRowState.Deleted);
            }
            catch (Exception) { }
            return c;
        }

        // a failure here is shown at the top of the page in red: SyncroSim would otherwise hide it, and leave the page half filled
        protected override void ShowData()
        {
            if (m_table == null) return;   // called by SyncroSim before the page is built
            try { Fill(); }
            catch (Exception ex) { m_summary.Text = "The page could not show the sources: " + ex.GetType().Name + ": " + ex.Message; m_summary.ForeColor = Color.Firebrick; }
        }

        private void Fill()
        {
            List<DataRow> rows = Rows();
            if (m_entries.Count != rows.Count || m_entries.Select(e => e.Name).Where((n, i) => n != Show(rows[i]["Name"])).Any()) MakeRows(rows);
            m_home = Home();
            bool homeOk = Exists(m_home);
            m_homeNote.Text = m_home.Length == 0 ? "Data Sources Home is not set (Data Sources page)" : homeOk ? "Data Sources Home: " + m_home : "Data Sources Home not found: " + m_home;
            m_homeNote.ForeColor = m_home.Length > 0 && !homeOk ? Color.Firebrick : SystemColors.GrayText;
            Dictionary<string, int> units = UnitCounts();
            foreach (Entry e in m_entries)
            {
                DataRow r = rows.FirstOrDefault(x => Show(x["Name"]) == e.Name);
                string v = r == null ? "" : Show(r["File"]).Trim();
                e.Shown = v; e.Path.Text = v; if (!e.Path.Focused) e.Path.SelectionStart = 0;   // the start: the folder is what tells an old file from the home
                string full = Resolve(v); bool own = Exists(full); string home = HomeCopy(e);
                m_tip.SetToolTip(e.Path, full);
                e.Reading.Text = "Reads: " + (own ? full + (Path.IsPathRooted(v) ? "" : " (the copy shipped with lucasCore)") : home != null ? home + " (Data Sources Home)" : "nothing");
                e.Reading.ForeColor = own || home != null ? SystemColors.GrayText : Color.Firebrick;

                int n2, n3, np; units.TryGetValue(e.Prefix + "|stsim_SecondaryStratum", out n2); units.TryGetValue(e.Prefix + "|stsim_TertiaryStratum", out n3); units.TryGetValue("|primary", out np);
                int count = e.Number == 1 ? np : Math.Max(n2, n3);
                string what = e.Number == 1 ? "primary strata" : e.DatasetName ?? "custom source";
                e.Detail.Text = (count > 0 ? string.Format("{0} · {1:N0} units", what, count) : what) + (home != null ? Environment.NewLine + "home has " + Path.GetFileName(home) : "");

                bool package = own && !Path.IsPathRooted(v);
                e.HomeHas = home != null;
                e.UseHome.Enabled = e.PackageFile != null ? !package || !string.Equals(v, e.PackageFile, StringComparison.OrdinalIgnoreCase) : v.Length > 0 && home != null;
                if (own)
                {
                    e.Reads = package ? Where.Package : Where.Own;
                    e.State.Text = package ? "Reads: package copy" : "Reads: this file"; e.State.ForeColor = package || home == null ? Color.ForestGreen : Color.DarkOrange;
                    m_tip.SetToolTip(e.State, "Read from " + full + (home != null ? Environment.NewLine + "The home also holds a copy (" + home + "): Use home reads that instead." : ""));
                }
                else if (home != null)
                {
                    e.Reads = v.Length > 0 ? Where.HomeMissingFile : Where.Home;
                    e.State.Text = v.Length > 0 ? "Reads: home copy (file not found)" : "Reads: home copy"; e.State.ForeColor = v.Length > 0 ? Color.DarkOrange : Color.ForestGreen;
                    m_tip.SetToolTip(e.State, (v.Length > 0 ? full + " does not exist on this machine, so the home's copy is read:" + Environment.NewLine : "Read from ") + home);
                }
                else
                {
                    e.Reads = Where.None;
                    e.State.Text = "✗ Nothing to read"; e.State.ForeColor = Color.Firebrick;
                    m_tip.SetToolTip(e.State, v.Length > 0 ? full + " does not exist on this machine" + (e.HomePath != null ? ", and the home has no copy: run a Data Download scenario" : "")
                                     : e.HomePath != null ? (m_home.Length == 0 ? "Set Data Sources Home, then run a Data Download scenario" : "Not in Data Sources Home (" + e.HomePath + "): run a Data Download scenario")
                                     : "No file: set one (this source is not fetched by Data Download)");
                }
            }
            m_all.Enabled = m_entries.Any(e => e.Reads == Where.Own && e.HomeHas);
            m_summary.Text = Summary(); m_summary.ForeColor = m_entries.Any(e => e.Reads == Where.None) ? Color.Firebrick : SystemColors.ControlText;
            SizePaths();
        }

        // what the next Build will read, in a sentence or two, and what to do about it
        private string Summary()
        {
            Func<Where, int> n = w => m_entries.Count(e => e.Reads == w);
            int ownWithHome = m_entries.Count(e => e.Reads == Where.Own && e.HomeHas);
            var parts = new List<string>();
            if (n(Where.Home) + n(Where.HomeMissingFile) > 0) parts.Add(string.Format("{0} from Data Sources Home", n(Where.Home) + n(Where.HomeMissingFile)));
            if (n(Where.Own) > 0) parts.Add(string.Format("{0} from files of their own", n(Where.Own)));
            if (n(Where.Package) > 0) parts.Add(string.Format("{0} from the package's copy", n(Where.Package)));
            string s = "The next Build reads " + (parts.Count == 0 ? "no source" : string.Join(", ", parts)) + ".";
            if (ownWithHome > 0) s += string.Format(" The home also holds {0} of the sources read from their own files: click Use home copies for all (or Use home on a row) to read the home's copies instead.", ownWithHome);
            if (n(Where.None) > 0) s += string.Format(" {0} source(s) have nothing to read: see the red marks.", n(Where.None));
            return s;
        }

        // path boxes take the width the window leaves, as on Data Sources
        private void SizePaths()
        {
            if (m_entries.Count == 0) return;
            int mark = m_entries.Max(e => e.State.PreferredSize.Width + e.State.Margin.Horizontal);
            int w = Math.Max(MinPath, this.ClientSize.Width - NameWidth - Beside - mark);
            foreach (Entry e in m_entries) if (e.Path.Width != w) e.Path.Width = w;
        }
    }
}
