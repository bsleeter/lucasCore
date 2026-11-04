// =============================================================================
// DataReleaseView.cs - the Data Release page (stage 17): the runs to release, the folder to write, and how many years of maps
// =============================================================================
// Single-row sheet lucasCore_DataReleaseOptions (OutputFolder, MapEvery) and multi-row lucasCore_DataReleaseRun (RunScenarioId), both on this
// page. Each run is picked from a drop-down, as on Compare Runs. The figures and comparison go in by themselves: stage 17 finds the newest
// results that drew them. The names, DOI and wording of a release come with the Release Information page (metadata plan, Phase 4).
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
    public class DataReleaseView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_DataReleaseOptions"; } }
        private DataSheet RunSheet { get { return this.DataFeed.GetDataSheet("lucasCore_DataReleaseRun"); } }

        private readonly TableLayoutPanel m_table = new TableLayoutPanel { AutoSize = true, ColumnCount = 3, Margin = new Padding(0, 6, 0, 3) };
        private readonly Button m_add = new Button { Text = "Add a run", AutoSize = true, Margin = new Padding(3, 6, 3, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private readonly TextBox m_folder = new TextBox { Width = 420, Margin = new Padding(3, 3, 3, 3) };
        private readonly TextBox m_every = Box(60);
        private readonly ToolTip m_tip = new ToolTip();
        private List<RunItem> m_runs = new List<RunItem>();
        private string m_shown = null;   // the row ids the table was built for

        private List<DataRow> Rows() { return RunSheet == null ? new List<DataRow>() : RunSheet.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).ToList(); }
        private static int Rid(DataRow r) { return r["RunScenarioId"] == DBNull.Value ? -1 : Convert.ToInt32(r["RunScenarioId"]); }

        public DataReleaseView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(Note("Choose the historical runs and projections to release. This scenario depends on their Build result. Each run gets its tables, maps and metadata record; the newest Build Figures, Run Figures and Compare Runs results of these runs go in by themselves, and so does a backup of the library."));
            for (int k = 0; k < 3; k++) m_table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            c.Controls.Add(m_table);
            var r = Row(); r.Controls.Add(m_add); c.Controls.Add(r);
            c.Controls.Add(m_state);
            AddGroup(Group("Runs to release", c));

            var f = Form();
            var browse = new Button { Text = "Browse...", AutoSize = true };
            var pick = Row(); pick.Controls.Add(m_folder); pick.Controls.Add(browse);
            FormRow(f, "Release folder", pick, "Blank = a folder named after the library, beside it. Holds the data, so it can be large.");
            FormRow(f, "Maps every", m_every, "years; blank or 1 = every year. The first and last years are always mapped.");
            AddGroup(Group("What to write", f));
            EndGroups();

            m_add.Click += (s, e) => AddRun();
            m_folder.Validated += (s, e) => { if (Refreshing) return; string v = m_folder.Text.Trim(); Write("OutputFolder", v.Length == 0 ? (object)DBNull.Value : v.Replace('\\', '/')); RefreshControls(); };
            browse.Click += (s, e) =>
            {
                using (var d = new FolderBrowserDialog { Description = "Choose the release folder", SelectedPath = Directory.Exists(m_folder.Text.Trim()) ? m_folder.Text.Trim() : "" })
                    if (d.ShowDialog(this) == DialogResult.OK) { Write("OutputFolder", d.SelectedPath.Replace('\\', '/')); RefreshControls(); }
            };
            BindNumber(m_every, () => Sheet, "MapEvery", true);
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_runs = StsimRuns.List(this.DataFeed.Project);
            RefreshControls();
        }

        private void AddRun()
        {
            m_runs = StsimRuns.List(this.DataFeed.Project);
            HashSet<int> have = new HashSet<int>(Rows().Select(Rid));
            RunItem next = m_runs.FirstOrDefault(i => !have.Contains(Convert.ToInt32(i.Key)));
            if (next == null) return;
            DataSheet ds = RunSheet; DataTable dt = ds.GetData();
            ds.BeginAddRows(); DataRow nr = dt.NewRow(); nr["RunScenarioId"] = next.Key; dt.Rows.Add(nr); ds.EndAddRows();
            m_shown = null; RefreshControls();
        }

        private void Build(List<DataRow> rows)
        {
            m_table.SuspendLayout();
            m_table.Controls.Clear(); m_table.RowStyles.Clear(); m_table.RowCount = 0;
            foreach (DataRow row in rows)
            {
                DataRow rw = row; int i = m_table.RowCount;
                m_table.RowCount = i + 1; m_table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                var rm = new Button { Text = "✕", Width = 26, Height = 24, FlatStyle = FlatStyle.Flat, ForeColor = Color.Firebrick, Margin = new Padding(3, 3, 3, 3) };
                m_tip.SetToolTip(rm, "Remove this run from the release");
                rm.Click += (s, e) => { RunSheet.DeleteRows(new[] { rw }); m_shown = null; RefreshControls(); };
                var run = List(420);
                run.DropDown += (s, e) => { m_runs = StsimRuns.List(this.DataFeed.Project); Fill(run, Rid(rw)); };
                run.SelectionChangeCommitted += (s, e) =>
                {
                    var it = run.SelectedItem as RunItem; if (it == null) return;
                    RunSheet.BeginModifyRows(); rw["RunScenarioId"] = it.Key; RunSheet.EndModifyRows(); RefreshControls();
                };
                var role = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 7, 3, 3), Tag = Fit.Fixed };
                m_table.Controls.Add(rm, 0, i); m_table.Controls.Add(run, 1, i); m_table.Controls.Add(role, 2, i);
            }
            m_table.ResumeLayout(true);
        }

        private void Fill(ComboBox cb, int rid)
        {
            cb.BeginUpdate(); cb.Items.Clear();
            foreach (RunItem i in m_runs) cb.Items.Add(i);
            int idx = -1;
            for (int k = 0; k < cb.Items.Count; k++) if (Convert.ToInt32(((RunItem)cb.Items[k]).Key) == rid) idx = k;
            if (idx < 0 && rid >= 0) { cb.Items.Add(StsimRuns.Missing(this.DataFeed.Project, rid)); idx = cb.Items.Count - 1; }
            cb.SelectedIndex = idx; cb.EndUpdate();
        }

        protected override void ShowData()
        {
            if (!m_folder.Focused) m_folder.Text = Show(Value("OutputFolder"));
            if (!m_every.Focused) m_every.Text = Show(Value("MapEvery"));
            List<DataRow> rows = Rows();
            string ids = string.Join(",", rows.Select(r => r.GetHashCode().ToString()));
            if (ids != m_shown) { Build(rows); m_shown = ids; }
            HashSet<int> chosen = new HashSet<int>(rows.Select(Rid));
            for (int i = 0; i < rows.Count; i++)
            {
                int rid = Rid(rows[i]);
                Fill((ComboBox)m_table.GetControlFromPosition(1, i), rid);
                ((Label)m_table.GetControlFromPosition(2, i)).Text = StsimRuns.History(this.DataFeed.Project, rid) >= 0 ? "projection" : "historical";
            }
            m_add.Enabled = m_runs.Any(i => !chosen.Contains(Convert.ToInt32(i.Key)));
            m_state.Text = m_runs.Count == 0 && StsimRuns.Problem.Length > 0 ? "The page finds no runs to list: " + StsimRuns.Problem
                : rows.Count == 0 ? "No runs chosen yet: Add a run, then pick it from the drop-down." : "";
        }
    }
}
