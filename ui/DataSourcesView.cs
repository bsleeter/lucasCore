// =============================================================================
// DataSourcesView.cs - the Data Sources page of the project: the national data paths, grouped by kind, with where to get each
// =============================================================================
// Single-row project sheet lucasCore_DataSource. defaults/library/data-sources.csv gives each column its category, the dataset it
// holds, a download page, the name the page shows and an optional note; a column the file does not list goes under "Other". One row per
// dataset (user, 2026-10-28): its name (else the column's display name without bracketed detail) with the note in grey under it, and
// the column's full display name, source and link in a tooltip; the path; a Browse button (a folder dialog for *Folder columns, a file
// dialog otherwise); a Download button (the download page); and a check of whether the path exists on this machine. A new library
// comes with the package's default paths (LibrarySetup); a blank path means the package default (NCCPI: fetched from Planetary Computer;
// the ecodivisions: the package's own copy). The file's Access column (to-do 12) marks the datasets with no public download "user": their
// Download button is off and the mark says "user-supplied" until a path is found.
// Data Sources Home (to-do 12, src/datahome.R): one folder holding every dataset at its place (the file's HomePath column). A blank path
// whose place holds the data shows "✓ home"; Make folders creates the empty layout. The home folder's manifest.csv, written by the Data
// Download stage, adds each dataset's status and the region it covers to its mark and tooltip.
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class DataSourcesView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_DataSource"; } }

        private class Entry { public string Column, Category, Source, Url, Name, Note, Access, HomePath; public TextBox Path; public Label State; }
        private const string HomeColumn = "DataSourcesHome";
        private TextBox m_home; private Label m_homeState;
        private readonly List<Entry> m_entries = new List<Entry>();
        private bool m_built;

        public DataSourcesView() { }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            if (!m_built) { BuildPage(); m_built = true; }
            RefreshControls();
        }

        // the groups are made once the sheet's columns are known
        private void BuildPage()
        {
            this.SuspendLayout();
            var meta = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            try
            {
                List<string[]> rows = Csv.Read(Path.Combine(LibrarySetup.PackageDirectory(), "defaults", "library", "data-sources.csv"));
                foreach (string[] r in rows.Skip(1)) if (r.Length >= 4) meta[r[0]] = r;
            }
            catch (Exception) { }
            var intro = Column();
            intro.Controls.Add(Note("The stages read these national datasets from disk. A new library starts with the paths of the machine lucasCore was built on: point each one at your own copy (Browse, or type the path). A red cross means the path does not exist on this machine. Download opens the dataset's download page; hover a name for the full description."));
            if (Sheet.Columns.Cast<DataSheetColumn>().Any(c => c.Name == HomeColumn)) intro.Controls.Add(HomeRow());
            AddGroup(Group("Data Sources", intro));

            DataSheet ds = Sheet;
            var cols = ds.Columns.Cast<DataSheetColumn>().Where(c => c.IsVisible && c.Name != "DataSourceId" && c.Name != "ProjectId" && c.Name != HomeColumn && c.DataType == typeof(string)).ToList();
            foreach (DataSheetColumn c in cols)
            {
                string[] m; meta.TryGetValue(c.Name, out m);
                Func<int, string> at = k => m != null && m.Length > k && m[k].Length > 0 ? m[k] : null;
                m_entries.Add(new Entry { Column = c.Name, Category = at(1) ?? "Other", Source = at(2), Url = at(3), Name = at(4), Note = at(5), Access = at(6), HomePath = at(10) });
            }
            var order = meta.Values.Select(m => m[1]).Distinct().ToList(); order.Add("Other");
            foreach (string cat in order)
            {
                List<Entry> es = m_entries.Where(e => e.Category == cat).ToList();
                if (es.Count == 0) continue;
                // a fixed name width, and path boxes all sized together to the window (SizePaths), so every group's columns line up
                var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 5 };
                t.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, NameWidth));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                foreach (Entry e in es) AddEntry(t, e, cols.First(c => c.Name == e.Column).DisplayName);
                AddGroup(Group(cat, t));
            }
            EndGroups();
            this.Resize += (s, a) => SizePaths();
            this.ResumeLayout(false);
            SizePaths();
        }

        // name column, and the room the buttons, mark, group borders and scroll bar take beside the path box
        private const int NameWidth = 280, Beside = 330, MinPath = 220;

        // every path box takes the width the window leaves (at least MinPath), so Browse and Download stay in view
        private void SizePaths()
        {
            int w = Math.Max(MinPath, this.ClientSize.Width - NameWidth - Beside);
            foreach (Entry e in m_entries) if (e.Path != null && e.Path.Width != w) e.Path.Width = w;
        }
        private readonly ToolTip m_tip = new ToolTip { AutoPopDelay = 20000 };

        // the dataset's name without the detail its column name carries in brackets or after " - " (that goes in the tooltip)
        private static string ShortName(string displayName)
        {
            string s = System.Text.RegularExpressions.Regex.Replace(displayName, @"\s*\([^)]*\)", "");
            int k = s.IndexOf(" - ", StringComparison.Ordinal); if (k > 0) s = s.Substring(0, k);
            return s.Trim();
        }

        // one row per dataset: name, path, Browse, Download, found mark
        private void AddEntry(TableLayoutPanel t, Entry e, string displayName)
        {
            int r = t.RowCount; t.RowCount = r + 1; t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            // the name from data-sources.csv (else the column's display name, shortened), a grey note under it when the file gives one
            var cell = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 3, 9, 3) };
            var name = new Label { Text = e.Name ?? ShortName(displayName), AutoSize = true, MaximumSize = new Size(NameWidth - 12, 0), Tag = Fit.Fixed, Margin = new Padding(3, 4, 3, 0) };
            cell.Controls.Add(name);
            if (e.Note != null) cell.Controls.Add(new Label { Text = e.Note, AutoSize = true, MaximumSize = new Size(NameWidth - 12, 0), Tag = Fit.Fixed, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 1, 3, 0) });
            m_tip.SetToolTip(name, displayName + (e.Source != null ? Environment.NewLine + "Source: " + e.Source : "") + (e.Url != null ? Environment.NewLine + e.Url : ""));
            e.Path = new TextBox { Width = MinPath, Anchor = AnchorStyles.Left, Margin = new Padding(3, 4, 3, 3) };
            var browse = new Button { Text = "Browse...", AutoSize = true, Margin = new Padding(3, 3, 3, 3) };
            var download = new Button { Text = "Download", AutoSize = true, Margin = new Padding(3, 3, 3, 3), Enabled = !string.IsNullOrEmpty(e.Url) && e.Access != "user" };
            if (download.Enabled)
            {
                string url = e.Url;
                m_tip.SetToolTip(download, "Opens " + (e.Source ?? url) + Environment.NewLine + url);
                download.Click += (s, a) => { try { Process.Start(url); } catch (Exception) { } };
            }
            e.State = new Label { AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(6, 7, 3, 3), Font = new Font(this.Font, FontStyle.Bold) };
            t.Controls.Add(cell, 0, r); t.Controls.Add(e.Path, 1, r); t.Controls.Add(browse, 2, r); t.Controls.Add(download, 3, r); t.Controls.Add(e.State, 4, r);

            Entry en = e;
            e.Path.Validated += (s, a) => { if (Refreshing) return; string v = en.Path.Text.Trim(); Write(en.Column, v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); };
            browse.Click += (s, a) => Browse(en);
        }

        // the home folder: path, Browse, Make folders, and a mark
        private Control HomeRow()
        {
            var row = Row(); row.WrapContents = false; row.Margin = new Padding(0, 6, 0, 0);
            var cap = Caption("Data Sources Home"); m_tip.SetToolTip(cap, "One folder holding every dataset at its standard place: a blank path below reads its place here.");
            m_home = new TextBox { Width = 420, Anchor = AnchorStyles.Left, Margin = new Padding(3, 4, 3, 3) };
            var browse = new Button { Text = "Browse...", AutoSize = true };
            var make = new Button { Text = "Make folders", AutoSize = true };
            m_tip.SetToolTip(make, "Creates the empty folder layout in the home folder (nothing is moved or deleted)");
            m_homeState = new Label { AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(6, 7, 3, 3), Font = new Font(this.Font, FontStyle.Bold) };
            row.Controls.Add(cap); row.Controls.Add(m_home); row.Controls.Add(browse); row.Controls.Add(make); row.Controls.Add(m_homeState);
            m_home.Validated += (s, a) => { if (Refreshing) return; string v = m_home.Text.Trim(); Write(HomeColumn, v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); };
            browse.Click += (s, a) =>
            {
                using (var d = new FolderBrowserDialog { Description = "Choose the Data Sources Home folder", SelectedPath = Directory.Exists(m_home.Text.Trim()) ? m_home.Text.Trim() : "" })
                    if (d.ShowDialog(this) == DialogResult.OK) { Write(HomeColumn, d.SelectedPath.Replace('\\', '/')); RefreshControls(); }
            };
            make.Click += (s, a) =>
            {
                string h = m_home.Text.Trim();
                if (h.Length == 0) { MessageBox.Show(this, "Choose the home folder first.", "Data Sources Home"); return; }
                int made = 0;
                try
                {
                    foreach (string d in m_entries.Where(e => e.HomePath != null).Select(e => PlaceFolder(h, e.HomePath)).Concat(new[] { Path.Combine(h, "logs") }).Distinct())
                        if (!Directory.Exists(d)) { Directory.CreateDirectory(d); made++; }
                }
                catch (Exception ex) { MessageBox.Show(this, ex.Message, "Data Sources Home"); }
                RefreshControls();
                MessageBox.Show(this, made == 0 ? "Every folder was already there." : string.Format("Made {0} folders in {1}.", made, h), "Data Sources Home");
            };
            return row;
        }

        // the folder a HomePath names: itself for a folder column, the pattern's folder for a file column
        private static string PlaceFolder(string home, string homePath)
        {
            string first = homePath.Split('|')[0];
            return Path.Combine(home, first.Contains("*") ? Path.GetDirectoryName(first) : first);
        }

        // a HomePath under the home folder, as src/datahome.R home_path: the folder, or the one file its patterns match. found = files matched
        private static string Place(string home, string homePath, out int found)
        {
            found = 0;
            try
            {
                string[] parts = homePath.Split('|');
                if (!parts[0].Contains("*")) { string p = Path.Combine(home, parts[0]); if (Directory.Exists(p)) { found = 1; return p; } return null; }
                string dir = PlaceFolder(home, homePath); if (!Directory.Exists(dir)) return null;
                var pats = new[] { Path.GetFileName(parts[0]) }.Concat(parts.Skip(1));
                // the suffix test keeps "*.tif" from matching .tiff (GetFiles' 3-letter extension rule)
                List<string> files = pats.SelectMany(pt => Directory.GetFiles(dir, pt).Where(f => !pt.StartsWith("*") || f.EndsWith(pt.Substring(1), StringComparison.OrdinalIgnoreCase))).Distinct().ToList();
                found = files.Count;
                return files.Count == 1 ? files[0].Replace('\\', '/') : null;
            }
            catch (Exception) { return null; }
        }

        // manifest.csv of the home folder: Column -> its row (header names as keys)
        private static Dictionary<string, Dictionary<string, string>> Manifest(string home)
        {
            var m = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
            try
            {
                string f = Path.Combine(home, "manifest.csv"); if (home.Length == 0 || !File.Exists(f)) return m;
                List<string[]> rows = Csv.Read(f); if (rows.Count < 2) return m;
                string[] head = rows[0];
                foreach (string[] r in rows.Skip(1))
                {
                    var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    for (int i = 0; i < head.Length && i < r.Length; i++) d[head[i]] = r[i];
                    string c; if (d.TryGetValue("Column", out c)) m[c] = d;
                }
            }
            catch (Exception) { }
            return m;
        }
        private static string Get(Dictionary<string, string> d, string k) { string v; return d != null && d.TryGetValue(k, out v) ? v : ""; }

        private void Browse(Entry e)
        {
            string now = e.Path.Text.Trim();
            if (e.Column.EndsWith("Folder", StringComparison.OrdinalIgnoreCase))
            {
                using (var d = new FolderBrowserDialog { Description = "Choose the folder", SelectedPath = Directory.Exists(now) ? now : "" })
                    if (d.ShowDialog(this) == DialogResult.OK) { Write(e.Column, d.SelectedPath.Replace('\\', '/')); RefreshControls(); }
            }
            else
            {
                using (var d = new OpenFileDialog { Title = "Choose the file", CheckFileExists = true })
                {
                    try { if (now.Length > 0 && Directory.Exists(Path.GetDirectoryName(now))) { d.InitialDirectory = Path.GetDirectoryName(now); d.FileName = Path.GetFileName(now); } } catch (Exception) { }
                    if (d.ShowDialog(this) == DialogResult.OK) { Write(e.Column, d.FileName.Replace('\\', '/')); RefreshControls(); }
                }
            }
        }

        protected override void ShowData()
        {
            string home = m_home == null ? "" : Show(Value(HomeColumn)).Trim();
            if (m_home != null)
            {
                m_home.Text = home; m_tip.SetToolTip(m_home, home);
                bool hx = false; try { hx = home.Length > 0 && Directory.Exists(home); } catch (Exception) { }
                m_homeState.Text = home.Length == 0 ? "not set" : hx ? "✓" : "✗";
                m_homeState.ForeColor = home.Length == 0 ? SystemColors.GrayText : hx ? Color.ForestGreen : Color.Firebrick;
            }
            var manifest = Manifest(home);
            foreach (Entry e in m_entries)
            {
                string v = Show(Value(e.Column)).Trim();
                e.Path.Text = v;
                if (!e.Path.Focused) { e.Path.SelectionStart = v.Length; e.Path.ScrollToCaret(); }   // a long path shows its end (the file or folder name)
                m_tip.SetToolTip(e.Path, v);
                bool exists = false;
                try { exists = v.Length > 0 && (File.Exists(v) || Directory.Exists(v)); } catch (Exception) { }
                Dictionary<string, string> mr; manifest.TryGetValue(e.Column, out mr);
                string got = mr == null ? "" : string.Format("{0}Downloaded {1} ({2}{3}); status {4}", Environment.NewLine, Get(mr, "Downloaded"),
                                                             Get(mr, "Copy") == "national" ? "national copy" : "region: " + Get(mr, "Units"),
                                                             Get(mr, "BufferKm").Length > 0 ? " + " + Get(mr, "BufferKm") + " km" : "", Get(mr, "Status"));
                string flag = mr != null && Get(mr, "Status") != "done" ? " " + Get(mr, "Status") : "";
                int found = 0; string place = v.Length == 0 && home.Length > 0 && e.HomePath != null ? Place(home, e.HomePath, out found) : null;
                if (place != null)
                {
                    e.State.Text = "✓ home" + flag; e.State.ForeColor = flag.Length > 0 ? Color.DarkOrange : Color.ForestGreen;
                    m_tip.SetToolTip(e.State, place + got);
                }
                else if (v.Length == 0 && found > 1)
                {
                    e.State.Text = string.Format("✗ {0} files", found); e.State.ForeColor = Color.Firebrick;
                    m_tip.SetToolTip(e.State, string.Format("{0} files match {1} in the home folder: keep one, or set the path", found, e.HomePath));
                }
                else if (v.Length == 0)
                {
                    m_tip.SetToolTip(e.State, home.Length > 0 && e.HomePath != null ? "Nothing at " + e.HomePath + " in the home folder" : "");
                    e.State.Text = e.Column == "NccpiFile" ? "fetched" : e.Access == "package" ? "package copy" : e.Access == "user" ? "user-supplied" : "default";
                    e.State.ForeColor = SystemColors.GrayText;
                }
                else if (!exists && e.Access == "user") { e.State.Text = "✗ user-supplied"; e.State.ForeColor = Color.Firebrick; m_tip.SetToolTip(e.State, v); }
                else { e.State.Text = exists ? "✓" : "✗"; e.State.ForeColor = exists ? Color.ForestGreen : Color.Firebrick; m_tip.SetToolTip(e.State, v + got); }
            }
        }
    }
}
