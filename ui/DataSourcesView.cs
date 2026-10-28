// =============================================================================
// DataSourcesView.cs - the Data Sources page of the project: the national data paths, grouped by kind, with where to get each
// =============================================================================
// Single-row project sheet lucasCore_DataSource. defaults/library/data-sources.csv gives each column its category, the dataset it
// holds, a download page, the name the page shows and an optional note; a column the file does not list goes under "Other". One row per
// dataset (user, 2026-10-28): its name (else the column's display name without bracketed detail) with the note in grey under it, and
// the column's full display name, source and link in a tooltip; the path; a Browse button (a folder dialog for *Folder columns, a file
// dialog otherwise); a Download button (the download page); and a check of whether the path exists on this machine. A new library
// comes with the package's default paths (LibrarySetup); a blank path means the package default (NCCPI: fetched from Planetary Computer).
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

        private class Entry { public string Column, Category, Source, Url, Name, Note; public TextBox Path; public Label State; }
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
            AddGroup(Group("Data Sources", intro));

            DataSheet ds = Sheet;
            var cols = ds.Columns.Cast<DataSheetColumn>().Where(c => c.IsVisible && c.Name != "DataSourceId" && c.Name != "ProjectId" && c.DataType == typeof(string)).ToList();
            foreach (DataSheetColumn c in cols)
            {
                string[] m; meta.TryGetValue(c.Name, out m);
                Func<int, string> at = k => m != null && m.Length > k && m[k].Length > 0 ? m[k] : null;
                m_entries.Add(new Entry { Column = c.Name, Category = at(1) ?? "Other", Source = at(2), Url = at(3), Name = at(4), Note = at(5) });
            }
            var order = meta.Values.Select(m => m[1]).Distinct().ToList(); order.Add("Other");
            foreach (string cat in order)
            {
                List<Entry> es = m_entries.Where(e => e.Category == cat).ToList();
                if (es.Count == 0) continue;
                // fixed name and path widths, so every group's columns line up
                var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 5 };
                t.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, NameWidth));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, PathWidth));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                foreach (Entry e in es) AddEntry(t, e, cols.First(c => c.Name == e.Column).DisplayName);
                AddGroup(Group(cat, t));
            }
            EndGroups();
            this.ResumeLayout(false);
        }

        private const int NameWidth = 330, PathWidth = 560;
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
            e.Path = new TextBox { Width = PathWidth - 6, Anchor = AnchorStyles.Left | AnchorStyles.Right, Margin = new Padding(3, 4, 3, 3) };
            var browse = new Button { Text = "Browse...", AutoSize = true, Margin = new Padding(3, 3, 3, 3) };
            var download = new Button { Text = "Download", AutoSize = true, Margin = new Padding(3, 3, 3, 3), Enabled = !string.IsNullOrEmpty(e.Url) };
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
            foreach (Entry e in m_entries)
            {
                string v = Show(Value(e.Column)).Trim();
                e.Path.Text = v;
                bool exists = false;
                try { exists = v.Length > 0 && (File.Exists(v) || Directory.Exists(v)); } catch (Exception) { }
                if (v.Length == 0)
                {
                    e.State.Text = e.Column == "NccpiFile" ? "fetched" : "default";
                    e.State.ForeColor = SystemColors.GrayText;
                }
                else { e.State.Text = exists ? "✓" : "✗"; e.State.ForeColor = exists ? Color.ForestGreen : Color.Firebrick; }
            }
        }
    }
}
