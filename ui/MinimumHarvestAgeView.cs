// =============================================================================
// MinimumHarvestAgeView.cs - Minimum Harvest Age: the youngest stand a clearcut or selection cut may take, by forest type (to-do 34)
// =============================================================================
// Feed HarvestAge: the single-row lucasCore_HarvestAgeOptions (study area maps on/off, minimum mapped area, selection offset and floor)
// and the multi-row lucasCore_MinimumHarvestAge (Ecodivision, Forest Type, Harvest, Minimum Age). The package's values are in
// defaults/transitions/harvest-age.csv (tools/calibrate-harvest-age.R: the 10th percentile of FIA stand age at the cut, per forest type
// and, where FIA has enough cuts, per ecodivision). A row here replaces the package value with the same ecodivision, forest type and
// harvest, or adds one. Stage 6 writes them into the harvest pathways and raises the start age of cells cut in the historical period.
// "Add the package values" lists the package's rows, to edit; "Remove all rows" goes back to the package values.
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
    public class MinimumHarvestAgeView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_MinimumHarvestAge"; } }

        private const string OPTIONS = "lucasCore_HarvestAgeOptions";
        private DataSheet Opts { get { return this.DataFeed.GetDataSheet(OPTIONS); } }

        private readonly CheckBox m_maps = new CheckBox { Text = "Lower the package values to the study area's mapped cuts", AutoSize = true, Margin = new Padding(3, 5, 12, 3) };
        private readonly TextBox m_area = Box(60);
        private readonly TextBox m_offset = Box(50);
        private readonly TextBox m_floor = Box(50);
        private readonly Panel m_grid = GridHost(380);
        private readonly Button m_add = new Button { Text = "Add the package values", AutoSize = true, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private string m_note = "";   // what the last button did, shown once

        public MinimumHarvestAgeView()
        {
            this.SuspendLayout();
            var f = Form();
            FormRow(f, "Study area:", m_maps, null);
            FormRow(f, "Minimum mapped cuts:", m_area, "km2 of first cuts a forest type needs in the study area before its own value is used");
            FormRow(f, "Selection younger than clearcut by:", m_offset, "yr (blank = 10)");
            FormRow(f, "Selection minimum at least:", m_floor, "yr (blank = 5)");
            AddGroup(Group("How stage 6 sets the minimum harvest ages", ProjectionTransitionsView.Stack(
                Note("The youngest stand a clearcut or selection cut may take. 1. The package's values: the 10th percentile of the stand age at which FIA saw each forest type cut (clearcut: 75% or more of the live basal area removed; selection: 10-75%), over all states, and per ecodivision where FIA has at least 30 cuts; types with too few cuts use the age of peak mean annual increment. 2. Each is lowered to the study area's own value where it is younger: the 10th percentile of stand age at a cell's first cut in the LCMS harvest maps, for types with enough mapped cuts (in P26 these were 10-30 years younger than FIA's). 3. Rows below replace or add values. 4. Selection is at most the clearcut minimum minus the offset, and at least the floor, unless a row below sets it."),
                f,
                Note("Projections cut only stands at least this old. In the historical period, the start age of a cell cut before it reached the minimum is raised to meet it, so a change here also changes the initial ages and carbon. Build Results > Minimum Harvest Ages lists the values used and where each came from."),
                m_grid)));
            m_maps.CheckedChanged += (s, e) => { if (!Refreshing) { Write(Opts, "UseStudyArea", m_maps.Checked); RefreshControls(); } };
            BindNumber(m_area, () => Opts, "MinMapArea", false);
            BindNumber(m_offset, () => Opts, "SelectionOffset", true);
            BindNumber(m_floor, () => Opts, "SelectionFloor", true);
            var r = Row(); r.Controls.Add(m_add); r.Controls.Add(m_clear); r.Controls.Add(m_state);
            var c = Column();
            c.Controls.Add(r);
            c.Controls.Add(Wrapped("Add the package values lists the package's rows for this library's forest types, ready to edit; a row that keeps its value changes nothing. Stage 6's log lists the values used and how many start ages were raised. A change takes effect the next time the Build runs.", 720));
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

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }

        // name -> id of a lookup column of this sheet (ecodivision, forest type, harvest type)
        private Dictionary<string, int> Ids(string column)
        {
            var d = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            DataSheetColumn col = Sheet.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (col != null && col.ValidationTable != null)
                foreach (DataRow r in Live(col.ValidationTable.DataSource))
                    d[Convert.ToString(r[col.ValidationTable.DisplayMember]).Trim()] = Convert.ToInt32(r[col.ValidationTable.ValueMember]);
            return d;
        }

        private static string Key(object eco, object type, object harvest) { return string.Format("{0}|{1}|{2}", eco == DBNull.Value ? "" : Convert.ToString(eco), type, harvest); }

        private void AddAll()
        {
            List<string[]> rows = Defaults.ReadCsv(Defaults.PackageFile("defaults", "transitions", "harvest-age.csv"));
            Dictionary<string, int> eco = Ids("StratumId"), cls = Ids("StateClassId"), tt = Ids("TransitionTypeId");
            DataTable dt = Sheet.GetData();
            var have = new HashSet<string>(Live(dt).Select(x => Key(x["StratumId"], x["StateClassId"], x["TransitionTypeId"])));
            int added = 0, skipped = 0;
            Sheet.BeginAddRows();
            try
            {
                foreach (string[] r in rows.Skip(1))   // Ecodivision, StateClassId, TransitionTypeId, AgeMin, Cuts, Source
                {
                    if (r.Length < 4) continue;
                    int c, t, e = 0, age;
                    bool hasEco = r[0].Trim().Length > 0;
                    if (!cls.TryGetValue(r[1].Trim(), out c) || !tt.TryGetValue(r[2].Trim(), out t) || (hasEco && !eco.TryGetValue(r[0].Trim(), out e)) || !int.TryParse(r[3], out age)) { skipped++; continue; }
                    object eo = hasEco ? (object)e : DBNull.Value;
                    if (have.Contains(Key(eo, c, t))) continue;
                    DataRow nr = dt.NewRow(); nr["StratumId"] = eo; nr["StateClassId"] = c; nr["TransitionTypeId"] = t; nr["AgeMin"] = age; dt.Rows.Add(nr); added++;
                }
            }
            finally { Sheet.EndAddRows(); }
            m_note = added == 0 ? "Every package value already has a row." : string.Format("Added {0} row{1}{2}.", added, added == 1 ? "" : "s", skipped > 0 ? string.Format(" ({0} for forest types or ecodivisions this library does not define left out)", skipped) : "");
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void ClearAll()
        {
            List<DataRow> rows = Live(Sheet.GetData()).ToList();
            if (rows.Count == 0) return;
            if (MessageBox.Show(this, "Remove every row, so all forest types use the package values?", "Minimum Harvest Age", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Sheet.DeleteRows(rows);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        protected override void ShowData()
        {
            object um = Value(Opts, "UseStudyArea");
            m_maps.Checked = um == DBNull.Value || Convert.ToBoolean(um);
            m_area.Text = Show(Value(Opts, "MinMapArea")); m_offset.Text = Show(Value(Opts, "SelectionOffset")); m_floor.Text = Show(Value(Opts, "SelectionFloor"));
            if (m_area.Text.Length == 0) m_area.Text = "1";
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            m_maps.Enabled = m_area.Enabled = m_offset.Enabled = m_floor.Enabled = edit;
            int n = Sheet.HasData() ? Live(Sheet.GetData()).Count() : 0;
            m_add.Enabled = edit; m_clear.Enabled = edit && n > 0;
            m_state.Text = (m_note.Length > 0 ? m_note + " " : "") + (n == 0 ? "No rows: every forest type uses the package values." : string.Format("{0} row{1}.", n, n == 1 ? "" : "s"));
            m_note = "";
        }
    }
}
