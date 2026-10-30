// =============================================================================
// MatureAgeView.cs - Carbon Assumptions > Mature Age by Forest Type: when an FIA plot of a forest type counts as mature (to-do 28)
// =============================================================================
// Multi-row sheet lucasCore_MatureAge (Ecodivision, Forest Type, Mature Age, No Fire or Cutting Within). Stage 3's measured dead wood
// calibration fits decay to the dead wood of mature plots; a type without a row uses Decay Calibration Settings' single values, which
// the page shows. "Add every forest type" lists each forest type at those values, to edit; "Remove all rows" goes back to the single
// values for all.
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
    public class MatureAgeView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_MatureAge"; } }
        private const string SETTINGS = "lucasCore_DecayCalibrationSetting";

        private readonly Panel m_grid = GridHost(380);
        private readonly Label m_default = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 8, 3, 6), Font = new Font(SystemFonts.MessageBoxFont, FontStyle.Bold) };
        private readonly Button m_add = new Button { Text = "Add every forest type", AutoSize = true, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private string m_note = "";   // what the last button did, shown once

        public MatureAgeView()
        {
            this.SuspendLayout();
            AddGroup(Group("Mature age by forest type (stage 3, FIA measured dead wood)", ProjectionTransitionsView.Stack(
                Note("The dead wood calibration fits decay rates to FIA's measured snags, down wood, litter and duff in mature stands, where dead wood has settled to the balance of what trees shed and what decays. Forest types get there at different ages: oak woodland and lodgepole pine sooner, fir, spruce and mixed conifer later. Give a type its own mature age here, and optionally its own window without fire or cutting; a row with an ecodivision applies there only and wins over the type's all-ecodivisions row."),
                m_default,
                m_grid)));
            var r = Row(); r.Controls.Add(m_add); r.Controls.Add(m_clear); r.Controls.Add(m_state);
            var c = Column();
            c.Controls.Add(r);
            c.Controls.Add(Wrapped("Add every forest type lists each forest type at the single values, ready to edit. A row that keeps the single values changes nothing. The log of stage 3 lists the rows used and the number of mature plots.", 720));
            AddGroup(Group("Rows", c));
            EndGroups();
            m_add.Click += (s, e) => AddAll();
            m_clear.Click += (s, e) => ClearAll();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        // Decay Calibration Settings' values (blank = the defaults 60 and 30)
        private int Setting(string column, int blank)
        {
            DataSheet ds = this.DataFeed == null ? null : this.DataFeed.GetDataSheet(SETTINGS);
            object v = Value(ds, column);
            return v == DBNull.Value ? blank : Convert.ToInt32(v);
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }

        // the package's forest types (the growth inputs' state classes) that this library defines, matched by name: the crosswalk's
        // first column is the FIA forest type group code, not the library's state class Id
        private List<int> ForestTypes()
        {
            var ids = new List<int>();
            List<string[]> rows = Defaults.ReadCsv(Defaults.PackageFile("defaults", "growth", "forest-type-crosswalk.csv"));
            DataSheetColumn col = Sheet.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == "StateClassId");
            var byName = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            if (col != null && col.ValidationTable != null)
                foreach (DataRow r in Live(col.ValidationTable.DataSource))
                    byName[Convert.ToString(r[col.ValidationTable.DisplayMember]).Trim()] = Convert.ToInt32(r[col.ValidationTable.ValueMember]);
            foreach (string[] r in rows.Skip(1)) { int id; if (r.Length > 1 && byName.TryGetValue("Forest: " + r[1].Trim(), out id) && !ids.Contains(id)) ids.Add(id); }
            return ids;
        }

        private void AddAll()
        {
            DataTable dt = Sheet.GetData();
            var have = new HashSet<int>(Live(dt).Where(x => x["StratumId"] == DBNull.Value && x["StateClassId"] != DBNull.Value).Select(x => Convert.ToInt32(x["StateClassId"])));
            int age = Setting("MatureAge", 60), added = 0;
            Sheet.BeginAddRows();
            try
            {
                foreach (int id in ForestTypes().Where(i => !have.Contains(i)))
                {
                    DataRow nr = dt.NewRow(); nr["StateClassId"] = id; nr["MatureAge"] = age; dt.Rows.Add(nr); added++;
                }
            }
            finally { Sheet.EndAddRows(); }
            m_note = added == 0 ? "Every forest type already has a row." : string.Format("Added {0} forest type{1} at {2} yr.", added, added == 1 ? "" : "s", age);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void ClearAll()
        {
            List<DataRow> rows = Live(Sheet.GetData()).ToList();
            if (rows.Count == 0) return;
            if (MessageBox.Show(this, "Remove every row, so all forest types use the single values?", "Mature Age by Forest Type", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Sheet.DeleteRows(rows);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        protected override void ShowData()
        {
            m_default.Text = string.Format("Forest types without a row: mature from {0} yr, no fire or cutting within {1} yr (Decay Calibration Settings).", Setting("MatureAge", 60), Setting("ExclusionYears", 30));
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            int n = Sheet.HasData() ? Live(Sheet.GetData()).Count() : 0;
            m_add.Enabled = edit; m_clear.Enabled = edit && n > 0;
            m_state.Text = (m_note.Length > 0 ? m_note + " " : "") + (n == 0 ? "No rows: every forest type uses the single values." : string.Format("{0} row{1}.", n, n == 1 ? "" : "s"));
            m_note = "";
        }
    }
}
