// =============================================================================
// DataSourcesView.cs - the Data Sources page of the project: the national data paths, grouped by kind, with where to get each
// =============================================================================
// Single-row project sheet lucasCore_DataSource. defaults/library/data-sources.csv gives each column its category, the dataset it
// holds and a download page; a column the file does not list goes under "Other". Each path has a Browse button (a folder dialog for
// *Folder columns, a file dialog otherwise) and a check of whether it exists on this machine. A new library comes with the package's
// default paths (LibrarySetup); a blank path means the package default (NCCPI: fetched from Planetary Computer).
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

        private class Entry { public string Column, Category, Source, Url; public TextBox Path; public Label State; }
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
            intro.Controls.Add(Note("The stages read these national datasets from disk. A new library starts with the paths of the machine lucasCore was built on: point each one at your own copy (Browse, or type the path). A red cross means the path does not exist on this machine. Each dataset's download page is linked under its name."));
            AddGroup(Group("Data Sources", intro));

            DataSheet ds = Sheet;
            var cols = ds.Columns.Cast<DataSheetColumn>().Where(c => c.IsVisible && c.Name != "DataSourceId" && c.Name != "ProjectId" && c.DataType == typeof(string)).ToList();
            foreach (DataSheetColumn c in cols)
            {
                string[] m; meta.TryGetValue(c.Name, out m);
                m_entries.Add(new Entry { Column = c.Name, Category = m != null ? m[1] : "Other", Source = m != null ? m[2] : null, Url = m != null ? m[3] : null });
            }
            var order = meta.Values.Select(m => m[1]).Distinct().ToList(); order.Add("Other");
            foreach (string cat in order)
            {
                List<Entry> es = m_entries.Where(e => e.Category == cat).ToList();
                if (es.Count == 0) continue;
                var t = new TableLayoutPanel { AutoSize = true, ColumnCount = 4 };
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                t.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
                foreach (Entry e in es) AddEntry(t, e, cols.First(c => c.Name == e.Column).DisplayName);
                AddGroup(Group(cat, t));
            }
            EndGroups();
            this.ResumeLayout(false);
        }

        private void AddEntry(TableLayoutPanel t, Entry e, string displayName)
        {
            int r = t.RowCount; t.RowCount = r + 2; t.RowStyles.Add(new RowStyle(SizeType.AutoSize)); t.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            var name = new Label { Text = displayName, AutoSize = true, MaximumSize = new Size(360, 0), Tag = Fit.Fixed, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 9, 0) };
            e.Path = new TextBox { Dock = DockStyle.Fill, Margin = new Padding(3, 4, 3, 0) };
            var browse = new Button { Text = "Browse...", AutoSize = true, Margin = new Padding(3, 3, 3, 0) };
            e.State = new Label { AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(6, 7, 3, 0), Font = new Font(this.Font, FontStyle.Bold) };
            t.Controls.Add(name, 0, r); t.Controls.Add(e.Path, 1, r); t.Controls.Add(browse, 2, r); t.Controls.Add(e.State, 3, r);
            Control under;
            if (!string.IsNullOrEmpty(e.Url))
            {
                var link = new LinkLabel { Text = string.Format("Download: {0}", e.Source ?? e.Url), AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 0, 3, 8) };
                string url = e.Url;
                link.LinkClicked += (s, a) => { try { Process.Start(url); } catch (Exception) { } };
                under = link;
            }
            else under = new Label { Text = "", AutoSize = true, Margin = new Padding(3, 0, 3, 8) };
            t.Controls.Add(under, 0, r + 1); t.SetColumnSpan(under, 4);

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
