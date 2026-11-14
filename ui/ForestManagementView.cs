// =============================================================================
// ForestManagementView.cs - Forest Management: changes to a projection's harvest (improved forest management)
// =============================================================================
// Sheet lucasCore_ForestManagement (years; where: a unit at any of the three strata levels; harvest scale; clearcut moved to
// selection, by area or by volume; selection moved to light selection; minimum and maximum ages per harvest type). Stage 9 applies
// each row to the harvest it drew from the historical record (src/forest-management.R).
// User 2026-11-13: "change the target areas for clearcut and selection (increase selection and reduce clearcut), increase the minimum
// harvest age"; "Protecting old forest should just use the MaxAge field which is complimentary to MinAge for both harvest types".
// Same layout as Management Actions: one line per parameter with its note to the right edge; Add writes a grid row.
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
    public class ForestManagementView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ForestManagement"; } }

        private readonly TextBox m_start = Box(60), m_end = Box(60), m_scale = Box(60), m_shift = Box(60), m_light = Box(60),
                                 m_ccMin = Box(50), m_ccMax = Box(50), m_selMin = Box(50), m_selMax = Box(50);
        private readonly ComboBox m_basis = List(280);
        private readonly ManagementActionsView.WherePicker m_where = new ManagementActionsView.WherePicker();
        private readonly Button m_add = new Button { Text = "Add change", AutoSize = true, Margin = new Padding(3, 6, 6, 3) };
        private readonly Label m_said = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Panel m_grid = GridHost(200);
        private readonly Button m_clear = new Button { Text = "Remove all rows", AutoSize = true, Margin = new Padding(3, 3, 12, 3) };
        private readonly Label m_state = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 8, 3, 3) };
        private readonly Label m_rows = new Label { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(3, 4, 3, 6) };

        private static FlowLayoutPanel Line(string c, Control x, Label n) { return ManagementActionsView.Line(c, x, n); }
        private static FlowLayoutPanel Pair(TextBox a, string mid, TextBox b, string after) { return ManagementActionsView.Pair(a, mid, b, after); }

        public ForestManagementView()
        {
            this.SuspendLayout();
            AddGroup(Group("What forest management does in a projection", ProjectionTransitionsView.Stack(
                Note("Each row changes the harvest the projection drew from the historical record (clearcut and selection areas by county and year), in its years and place. No rows = the drawn harvest. Harvest earns a timber revenue (volume x removal x regional stumpage), so a run that harvests less shows the revenue it gives up in Compare Runs."))));
            var r = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(150, 2, 0, 0) }; r.Controls.Add(m_add); r.Controls.Add(m_said);
            AddGroup(Group("A change to the harvest", ManagementActionsView.Lines(
                Line("Years:", Pair(m_start, "to", m_end, null), Note("Blank = from the projection start, or to its end.")),
                Line("Where:", m_where.Panel(), m_where.Info),
                Line("Clearcut to selection:", m_shift, Note("Share of the clearcut area harvested by selection instead (0-1). Selection removes half the merchantable wood and leaves the slash.")),
                Line("Shift basis:", m_basis, Note("Area: a hectare for a hectare (less wood). Volume: the same wood removed (a clearcut hectare becomes 1.94 selection hectares).")),
                Line("Lighter selection:", m_light, Note("Share of selection done as light selection (0-1): 20% of the live biomass removed instead of 50%. By volume, a hectare becomes 2.5.")),
                Line("Harvest scale:", m_scale, Note("Multiplies every harvest type after the shifts: 0.8 = a fifth less, 1 = as drawn, 2 = twice.")),
                Line("Clearcut ages:", Pair(m_ccMin, "to", m_ccMax, null), Note("Stand ages that may be clearcut. Blank minimum = the Build's (it can only be raised); a maximum protects older forest.")),
                Line("Selection ages:", Pair(m_selMin, "to", m_selMax, null), Note("The same for selection and light selection.")),
                r)));
            var rr = Row(); rr.Controls.Add(m_clear); rr.Controls.Add(m_state);
            AddGroup(Group("Changes (what the Projection Setup uses)", ProjectionTransitionsView.Stack(m_rows, m_grid, rr,
                Wrapped("Edit here directly if you like. Projection Results > Forest Management (as set up) lists the drawn and managed harvest of each row.", 760))));
            EndGroups();
            m_basis.Items.AddRange(new object[] { "Area (a hectare for a hectare)", "Volume (the same wood removed)" });
            FillDefaults();
            m_add.Click += (s, e) => AddRow();
            m_clear.Click += (s, e) => ClearAll();
            this.ResumeLayout(false);
        }

        private void FillDefaults() { m_scale.Text = "1"; m_shift.Text = "0"; m_light.Text = "0"; m_basis.SelectedIndex = 0; }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            Project p = this.Scenario != null ? this.Scenario.Project : this.DataFeed.Project;
            if (p != null) { var ms = new ManagementActionsView.ModelStrata(); try { ms.Load(p, this.Scenario); } catch (Exception) { } m_where.Load(ms); }
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }
        private static string Read(TextBox t, string what, bool integer, double min, double max, out object value)
        {
            value = DBNull.Value; string v = t.Text.Trim(); double d;
            if (v.Length == 0) return null;
            if (!double.TryParse(v, out d) || (integer && d != Math.Floor(d)) || d < min || d > max) return string.Format("{0} must be {1} from {2} to {3}", what, integer ? "a whole number" : "a number", min, max);
            value = integer ? (object)Convert.ToInt32(d) : d; return null;
        }

        private void AddRow()
        {
            object start = DBNull.Value, end = DBNull.Value, scale = DBNull.Value, shift = DBNull.Value, light = DBNull.Value,
                   ccMin = DBNull.Value, ccMax = DBNull.Value, selMin = DBNull.Value, selMax = DBNull.Value;
            string err = Read(m_start, "the start year", true, 1900, 2200, out start) ?? Read(m_end, "the end year", true, 1900, 2200, out end)
                      ?? Read(m_scale, "the harvest scale", false, 0, 100, out scale) ?? Read(m_shift, "the clearcut share", false, 0, 1, out shift)
                      ?? Read(m_light, "the light selection share", false, 0, 1, out light)
                      ?? Read(m_ccMin, "the clearcut minimum age", true, 0, 500, out ccMin) ?? Read(m_ccMax, "the clearcut maximum age", true, 0, 500, out ccMax)
                      ?? Read(m_selMin, "the selection minimum age", true, 0, 500, out selMin) ?? Read(m_selMax, "the selection maximum age", true, 0, 500, out selMax);
            if (err == null && start != DBNull.Value && end != DBNull.Value && (int)start > (int)end) err = "the start year is after the end year";
            if (err == null && ccMin != DBNull.Value && ccMax != DBNull.Value && (int)ccMin > (int)ccMax) err = "the clearcut ages run backwards";
            if (err == null && selMin != DBNull.Value && selMax != DBNull.Value && (int)selMin > (int)selMax) err = "the selection ages run backwards";
            DataTable dt = Sheet.GetData(); DataRow nr = dt.NewRow();
            if (err == null) err = m_where.Apply(nr);
            if (err != null) { m_said.ForeColor = Color.Firebrick; m_said.Text = "Not added: " + err + "."; return; }
            nr["StartYear"] = start; nr["EndYear"] = end; nr["HarvestScale"] = scale; nr["ClearcutToSelection"] = shift; nr["ShiftBasis"] = m_basis.SelectedIndex == 1 ? 2 : 1;
            nr["LightSelection"] = light; nr["ClearcutMinAge"] = ccMin; nr["ClearcutMaxAge"] = ccMax; nr["SelectionMinAge"] = selMin; nr["SelectionMaxAge"] = selMax;
            Sheet.BeginAddRows();
            try { dt.Rows.Add(nr); }
            finally { Sheet.EndAddRows(); }
            m_said.ForeColor = SystemColors.GrayText; m_said.Text = "Added as row " + Live(dt).Count() + ". Change any setting and add again for other years or another place.";
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private void ClearAll()
        {
            List<DataRow> rows = Live(Sheet.GetData()).ToList();
            if (rows.Count == 0) return;
            if (MessageBox.Show(this, "Remove every forest management change, so the projection keeps the drawn harvest?", "Forest Management", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            Sheet.DeleteRows(rows);
            LoadGrid(m_grid, SheetName);
            RefreshControls();
        }

        private static string Num(object v, string blank) { return v == DBNull.Value || v == null ? blank : Convert.ToDouble(v).ToString("0.##"); }
        private string Lookup(string column, object v)
        {
            if (v == DBNull.Value || v == null) return null;
            DataSheetColumn col = Sheet.Columns.Cast<DataSheetColumn>().FirstOrDefault(x => x.Name == column);
            if (col == null || col.ValidationTable == null) return Convert.ToString(v);
            foreach (DataRow r in Live(col.ValidationTable.DataSource))
                if (Convert.ToString(r[col.ValidationTable.ValueMember]) == Convert.ToString(v)) return Convert.ToString(r[col.ValidationTable.DisplayMember]);
            return Convert.ToString(v);
        }

        // one line per row, in words
        private string Describe(DataRow r, int i)
        {
            string[] cols = { "StratumId", "SecondaryStratumId", "TertiaryStratumId" };
            string where = string.Join(" / ", cols.Where(c => r.Table.Columns.Contains(c)).Select(c => Lookup(c, r[c])).Where(x => x != null));
            string years = r["StartYear"] == DBNull.Value && r["EndYear"] == DBNull.Value ? "every projection year"
                         : string.Format("{0} to {1}", Num(r["StartYear"], "the first projection year"), Num(r["EndYear"], "the end"));
            var parts = new List<string>();
            double shift = r["ClearcutToSelection"] == DBNull.Value ? 0 : Convert.ToDouble(r["ClearcutToSelection"]);
            double light = r["LightSelection"] == DBNull.Value ? 0 : Convert.ToDouble(r["LightSelection"]);
            double scale = r["HarvestScale"] == DBNull.Value ? 1 : Convert.ToDouble(r["HarvestScale"]);
            bool vol = r["ShiftBasis"] != DBNull.Value && Convert.ToInt32(r["ShiftBasis"]) == 2;
            if (shift > 0) parts.Add(string.Format("{0:0}% of clearcut to selection{1}", 100 * shift, vol ? " (same wood)" : ""));
            if (light > 0) parts.Add(string.Format("{0:0}% of selection to light selection", 100 * light));
            if (Math.Abs(scale - 1) > 1e-9) parts.Add(string.Format("harvest x {0:0.##}", scale));
            Func<string, string, string, string> ages = (what, a, b) => r[a] == DBNull.Value && r[b] == DBNull.Value ? null
                : string.Format("{0} ages {1}-{2}", what, Num(r[a], "the Build's"), Num(r[b], "any"));
            string ca = ages("clearcut", "ClearcutMinAge", "ClearcutMaxAge"), sa = ages("selection", "SelectionMinAge", "SelectionMaxAge");
            if (ca != null) parts.Add(ca); if (sa != null) parts.Add(sa);
            return string.Format("{0}. {1}, in {2}: {3}.", i, years, where.Length > 0 ? where : "the whole study area", parts.Count > 0 ? string.Join("; ", parts) : "no change");
        }

        protected override void ShowData()
        {
            bool edit = !(this.Scenario != null && this.Scenario.IsResult) && this.ShouldEnableView();
            List<DataRow> rows = Sheet.HasData() ? Live(Sheet.GetData()).ToList() : new List<DataRow>();
            m_add.Enabled = edit; m_clear.Enabled = edit && rows.Count > 0;
            m_state.Text = rows.Count == 0 ? "No changes: the projection keeps the drawn harvest." : string.Format("{0} change{1}.", rows.Count, rows.Count == 1 ? "" : "s");
            m_rows.Text = rows.Count == 0 ? "No changes yet." : string.Join(Environment.NewLine, rows.Select((x, i) => Describe(x, i + 1)));
        }
    }
}
