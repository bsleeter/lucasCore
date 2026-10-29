// =============================================================================
// CompareRunsView.cs - the Compare Runs page (stage 14): the runs to compare, each picked from a drop-down, and which is the baseline
// =============================================================================
// Multi-row sheet lucasCore_CompareRunOptions, one line per run: a remove button (✕, first so it never falls off a narrow page), RunScenarioId (a drop-down of the project's ST-Sim runs, StsimRuns),
// Label (blank = the scenario's name), Baseline (a tick; ticking one clears the others) and Colour (a swatch: click for a colour
// dialog, right-click for the default palette). Add a run lists the newest run not yet chosen. Stage 14 reads
// the sheet unchanged. A run that is another chosen run's historical run is marked as the history (drawn in black).
// =============================================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class CompareRunsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_CompareRunOptions"; } }

        private readonly TableLayoutPanel m_table = new TableLayoutPanel { AutoSize = true, ColumnCount = 6, Margin = new Padding(0, 6, 0, 3) };
        private readonly Button m_add = new Button { Text = "Add a run", AutoSize = true, Margin = new Padding(3, 6, 3, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 6, 3, 3) };
        private readonly ToolTip m_tip = new ToolTip();
        private List<RunItem> m_runs = new List<RunItem>();
        private string m_shown = null;   // the row ids the table was built for

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }
        private List<DataRow> Rows() { return Sheet == null ? new List<DataRow>() : Live(Sheet.GetData()).ToList(); }
        private static int Rid(DataRow r) { return r["RunScenarioId"] == DBNull.Value ? -1 : Convert.ToInt32(r["RunScenarioId"]); }

        public CompareRunsView()
        {
            this.SuspendLayout();
            var c = Column();
            c.Controls.Add(Note("Choose the runs to compare: historical runs and projections of this project. Tick the baseline, the run the others are compared with (none ticked = the first projection). A projection's historical run is drawn in black up to the year the projection starts, and is added when it is not chosen. The scenario must depend on the runs' Build result."));
            for (int k = 0; k < 6; k++) m_table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            c.Controls.Add(m_table);
            var r = Row(); r.Controls.Add(m_add); c.Controls.Add(r);
            c.Controls.Add(m_state);
            AddGroup(Group("Runs to compare", c));
            EndGroups();
            m_add.Click += (s, e) => AddRun();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_runs = StsimRuns.List(this.DataFeed.Project);
            RefreshControls();
        }

        private void Modify(DataRow row, string column, object value)
        {
            object now = row[column];
            if (Equals(now, value) || Convert.ToString(now) == Convert.ToString(value)) return;
            Sheet.BeginModifyRows(); row[column] = value ?? DBNull.Value; Sheet.EndModifyRows();
        }

        private void AddRun()
        {
            m_runs = StsimRuns.List(this.DataFeed.Project);
            HashSet<int> have = new HashSet<int>(Rows().Select(Rid));
            RunItem next = m_runs.FirstOrDefault(i => !have.Contains(Convert.ToInt32(i.Key)));
            if (next == null) return;
            DataSheet ds = Sheet; DataTable dt = ds.GetData();
            ds.BeginAddRows(); DataRow nr = dt.NewRow(); nr["RunScenarioId"] = next.Key; dt.Rows.Add(nr); ds.EndAddRows();
            m_shown = null; RefreshControls();
        }

        // the table: one line per row of the sheet, rebuilt when the rows change and refreshed in place otherwise
        private void Build(List<DataRow> rows)
        {
            m_table.SuspendLayout();
            m_table.Controls.Clear(); m_table.RowStyles.Clear(); m_table.RowCount = 0;
            Action<Control[]> line = cs => { int i = m_table.RowCount; m_table.RowCount = i + 1; m_table.RowStyles.Add(new RowStyle(SizeType.AutoSize)); for (int k = 0; k < cs.Length; k++) if (cs[k] != null) m_table.Controls.Add(cs[k], k, i); };
            Func<string, Label> head = t => new Label { Text = t, AutoSize = true, Font = new Font(this.Font, FontStyle.Bold), Margin = new Padding(3, 3, 12, 3), Tag = Fit.Fixed };
            if (rows.Count > 0) line(new Control[] { null, head("Run"), head("Baseline"), head("Colour"), head("Label (blank = the run's name)"), null });
            foreach (DataRow row in rows)
            {
                DataRow rw = row;
                var run = List(340);
                run.DropDown += (s, e) => { m_runs = StsimRuns.List(this.DataFeed.Project); Fill(run, Rid(rw)); };
                run.SelectionChangeCommitted += (s, e) => { var it = run.SelectedItem as RunItem; if (it != null) Modify(rw, "RunScenarioId", it.Key); RefreshControls(); };
                var lab = Box(180); lab.TextAlign = HorizontalAlignment.Left;
                lab.Validated += (s, e) => { if (Refreshing) return; string v = lab.Text.Trim(); Modify(rw, "Label", v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); };
                var bas = new CheckBox { AutoSize = true, Anchor = AnchorStyles.None, Margin = new Padding(3, 6, 12, 3) };
                bas.CheckedChanged += (s, e) =>
                {
                    if (Refreshing) return;
                    Sheet.BeginModifyRows();
                    foreach (DataRow o in Rows()) o["Baseline"] = (o == rw && bas.Checked) ? (object)true : DBNull.Value;
                    Sheet.EndModifyRows();
                    RefreshControls();
                };
                var col = new Button { Width = 70, Height = 24, FlatStyle = FlatStyle.Flat, Margin = new Padding(3, 3, 12, 3) };
                m_tip.SetToolTip(col, "Click to choose a colour; right-click for the default palette");
                col.MouseUp += (s, e) =>
                {
                    if (e.Button == MouseButtons.Right) { Modify(rw, "Colour", DBNull.Value); RefreshControls(); return; }
                    if (e.Button != MouseButtons.Left) return;
                    using (var d = new ColorDialog { FullOpen = true })
                    {
                        if (rw["Colour"] != DBNull.Value) try { d.Color = ColorTranslator.FromHtml(Convert.ToString(rw["Colour"])); } catch (Exception) { }
                        if (d.ShowDialog(this) == DialogResult.OK) { Modify(rw, "Colour", string.Format("#{0:x2}{1:x2}{2:x2}", d.Color.R, d.Color.G, d.Color.B)); RefreshControls(); }
                    }
                };
                var rm = new Button { Text = "✕", Width = 26, Height = 24, FlatStyle = FlatStyle.Flat, ForeColor = Color.Firebrick, Margin = new Padding(3, 3, 3, 3) };
                m_tip.SetToolTip(rm, "Remove this run from the comparison");
                rm.Click += (s, e) => { Sheet.DeleteRows(new[] { rw }); m_shown = null; RefreshControls(); };
                var role = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 7, 3, 3), Tag = Fit.Fixed };
                line(new Control[] { rm, run, bas, col, lab, role });
            }
            m_table.ResumeLayout(true);
        }

        private void Fill(ComboBox cb, int rid)
        {
            cb.BeginUpdate(); cb.Items.Clear();
            foreach (RunItem i in m_runs) cb.Items.Add(i);
            int idx = -1;
            for (int k = 0; k < cb.Items.Count; k++) if (Convert.ToInt32(((RunItem)cb.Items[k]).Key) == rid) idx = k;
            if (idx < 0 && rid >= 0) { cb.Items.Add(new RunItem { Key = rid, Name = string.Format("[{0}] (not an ST-Sim run of this project)", rid) }); idx = cb.Items.Count - 1; }
            cb.SelectedIndex = idx; cb.EndUpdate();
        }

        protected override void ShowData()
        {
            List<DataRow> rows = Rows();
            string ids = string.Join(",", rows.Select(r => r.GetHashCode().ToString()));
            if (ids != m_shown) { Build(rows); m_shown = ids; }
            HashSet<int> chosen = new HashSet<int>(rows.Select(Rid));
            HashSet<int> hist = new HashSet<int>(rows.Select(r => StsimRuns.History(this.DataFeed.Project, Rid(r))).Where(h => h >= 0));
            bool anyBase = rows.Any(r => r["Baseline"] != DBNull.Value && Convert.ToBoolean(r["Baseline"]));
            DataRow first = rows.FirstOrDefault(r => !hist.Contains(Rid(r)));
            for (int i = 0; i < rows.Count; i++)
            {
                DataRow r = rows[i]; int rid = Rid(r);
                var run = (ComboBox)m_table.GetControlFromPosition(1, i + 1);   // line 0 is the header
                var lab = (TextBox)m_table.GetControlFromPosition(4, i + 1);
                var bas = (CheckBox)m_table.GetControlFromPosition(2, i + 1);
                var col = (Button)m_table.GetControlFromPosition(3, i + 1);
                var role = (Label)m_table.GetControlFromPosition(5, i + 1);
                Fill(run, rid);
                if (!lab.Focused) lab.Text = Show(r["Label"]);
                bool isHist = hist.Contains(rid);
                bas.Checked = r["Baseline"] != DBNull.Value && Convert.ToBoolean(r["Baseline"]); bas.Enabled = !isHist;
                Color c = Color.Empty; if (r["Colour"] != DBNull.Value) try { c = ColorTranslator.FromHtml(Convert.ToString(r["Colour"])); } catch (Exception) { }
                col.BackColor = c.IsEmpty ? SystemColors.Control : c; col.Text = c.IsEmpty ? "auto" : "";
                role.Text = isHist ? "the history (black)" : (!anyBase && r == first) ? "the baseline (first projection)" : "";
            }
            HashSet<int> missing = new HashSet<int>(hist.Where(h => !chosen.Contains(h)));
            m_add.Enabled = m_runs.Any(i => !chosen.Contains(Convert.ToInt32(i.Key)));
            m_state.Text = rows.Count == 0 ? "No runs chosen yet: Add a run, then pick it from the drop-down."
                : missing.Count > 0 ? string.Format("Historical run{0} {1} will be added in front of the projections.", missing.Count == 1 ? "" : "s", string.Join(", ", missing.Select(h => "[" + h + "]")))
                : rows.Count == 1 ? "Add at least one more run to compare." : "";
        }
    }
}
