// =============================================================================
// SpatialAllocationView.cs - the Spatial Allocation page of a Projection Setup: what the placement surfaces are fitted on (stage 10)
// =============================================================================
// Feed SpatialAllocation = Suitability Options (single row) + Suitability Fitting Region + Suitability Covariates + Allocation Rule
// Weights. The fitting region uses the Study Area picker (its kind kept in SuitabilityOptions.RegionSourceId); the covariates are check
// boxes over the built-in list plus custom rasters (rows of SuitabilityCovariate: an empty sheet = all built-in, which stage 10 still
// reads that way); the rule weights are SyncroSim's own grid.
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
    public class SpatialAllocationView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_SuitabilityOptions"; } }
        private const string REGION = "lucasCore_SuitabilityRegion", COVARIATES = "lucasCore_SuitabilityCovariate", RULES = "lucasCore_RuleWeight";
        private static readonly string[] BUILTIN = { "Distance to developed land", "Developed share within 1 km", "Housing density (census decade)", "Distance to roads",
                                                     "Slope", "Elevation", "Land cover", "GAP status", "County" };
        private const int CUSTOM = 10;

        private readonly UnitPicker m_region = new UnitPicker("Fit the regression on", 70);
        private readonly ComboBox m_res = new ComboBox { Width = 80, DropDownStyle = ComboBoxStyle.DropDown, Margin = new Padding(3, 3, 12, 3) };
        private readonly TextBox m_test = Box(50), m_burn = Box(50), m_controls = Box(70), m_radius = Box(70), m_update = Box(50);
        private readonly List<CheckBox> m_cov = new List<CheckBox>();
        private readonly ListBox m_custom = new ListBox { Width = 420, Height = 60, IntegralHeight = false };
        private readonly Button m_addCustom = new Button { Text = "Add raster...", AutoSize = true }, m_removeCustom = new Button { Text = "Remove", AutoSize = true };
        private readonly Panel m_rules = GridHost(200);
        private readonly Button m_resetRules = new Button { Text = "Reset rule weights to defaults", AutoSize = true };
        private readonly Label m_rulesState = new Label { AutoSize = true, Margin = new Padding(8, 8, 3, 3) };

        private class Custom { public DataRow Row; public override string ToString() { return string.Format("{0}  ({1})", Show(Row["Name"]), Show(Row["File"])); } }

        public SpatialAllocationView()
        {
            this.SuspendLayout();
            m_region.UnitSheet = () => this.DataFeed.GetDataSheet(REGION);
            m_region.KindSheet = () => Sheet;
            m_region.KindColumn = "RegionSourceId";
            m_region.AllText = "The study area"; m_region.AllSummary = "the study area"; m_region.Subject = "Fitting region"; m_region.Confirm = "Fitting Region";
            m_region.AllNote = "A small study area has few change events: fit on a larger region (its pyrome, neighbouring counties, the state) instead.";
            m_region.Changed = RefreshControls;
            var regionHost = GridHost(260); m_region.Dock = DockStyle.Fill; regionHost.Controls.Add(m_region);
            AddGroup(Group("Fitting region", ProjectionTransitionsView.Stack(regionHost)));

            foreach (int r in new[] { 30, 60, 90, 150, 300, 990 }) m_res.Items.Add(r.ToString());
            var fit = Form();
            FormRow(fit, "Fitting resolution (m):", m_res, "30 = native NLCD; coarser fits faster");
            FormRow(fit, "Out-of-sample test years:", m_test, "the last N historical years are held out to score the surface (0 = no test)");
            FormRow(fit, "Leave out burned pixels (years):", m_burn, "NLCD relabels burned forest as developed open space for a few years");
            FormRow(fit, "Unchanged pixels per year:", m_controls, "the controls sampled against the change events");
            AddGroup(Group("Fitting", fit));

            var cov = Column();
            cov.Controls.Add(Note("The regression's predictors. Untick one to leave it out; add your own rasters (resampled to the fitting grid)."));
            var boxes = new FlowLayoutPanel { AutoSize = true, WrapContents = true, MaximumSize = new Size(720, 0), Margin = new Padding(0) };
            for (int i = 0; i < BUILTIN.Length; i++)
            {
                int code = i + 1;
                var cb = new CheckBox { Text = BUILTIN[i], AutoSize = true, Margin = new Padding(3, 3, 18, 3), Tag = code };
                cb.CheckedChanged += (s, e) => { if (!Refreshing) SetBuiltin(code, cb.Checked); };
                m_cov.Add(cb); boxes.Controls.Add(cb);
            }
            cov.Controls.Add(boxes);
            var cr = Row(); cr.Controls.Add(m_custom); var cbtn = Column(); cbtn.Controls.Add(m_addCustom); cbtn.Controls.Add(m_removeCustom); cr.Controls.Add(cbtn);
            cov.Controls.Add(cr);
            AddGroup(Group("Covariates", cov));

            var adj = Form();
            FormRow(adj, "Neighbourhood radius (m):", m_radius, "blank = 3 model cells; developed share within it drives the adjacency multiplier");
            FormRow(adj, "Update every (years):", m_update, null);
            AddGroup(Group("Adjacency (groups with Adjacency ticked on the Transitions page)", adj));

            var rr = Row(); rr.Controls.Add(m_resetRules); rr.Controls.Add(m_rulesState);
            AddGroup(Group("Rule weights (Rules method)", ProjectionTransitionsView.Stack(
                Note("A weight per WUI class (2020) and per GAP status for each surface; the surface is their product (0 = never)."), m_rules, rr)));
            EndGroups();

            m_res.Validated += (s, e) => { if (Refreshing) return; int v; if (int.TryParse(m_res.Text.Trim(), out v) && v >= 30 && v % 30 == 0) Write("FitResolution", v); RefreshControls(); };
            m_res.SelectionChangeCommitted += (s, e) => { if (!Refreshing && m_res.SelectedItem != null) Write("FitResolution", int.Parse((string)m_res.SelectedItem)); };
            BindNumber(m_test, () => Sheet, "TestYears", true); BindNumber(m_burn, () => Sheet, "BurnWindow", true); BindNumber(m_controls, () => Sheet, "ControlsPerYear", true);
            BindNumber(m_radius, () => Sheet, "AdjacencyRadius", false); BindNumber(m_update, () => Sheet, "AdjacencyUpdate", true);
            m_addCustom.Click += (s, e) => AddCustom();
            m_removeCustom.Click += (s, e) => RemoveCustom();
            m_resetRules.Click += (s, e) => ResetRules();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_region.LoadLists(dataFeed.Project);
            LoadGrid(m_rules, RULES);
            RefreshControls();
        }

        private DataSheet Cov { get { return this.DataFeed.GetDataSheet(COVARIATES); } }
        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }
        private static int Code(DataRow r) { return r["Covariate"] == DBNull.Value ? 0 : Convert.ToInt32(r["Covariate"]); }
        private static bool On(DataRow r) { return r["Include"] == DBNull.Value || Convert.ToBoolean(r["Include"]); }

        // the first change writes every built-in row (an empty sheet means all on), then sets the one changed
        private void SetBuiltin(int code, bool on)
        {
            DataSheet ds = Cov; DataTable dt = ds.GetData();
            var have = new HashSet<int>(Live(dt).Select(Code));
            if (Enumerable.Range(1, BUILTIN.Length).Any(c => !have.Contains(c)))
            {
                ds.BeginAddRows();
                foreach (int c in Enumerable.Range(1, BUILTIN.Length).Where(c => !have.Contains(c))) { DataRow nr = dt.NewRow(); nr["Covariate"] = c; nr["Include"] = true; dt.Rows.Add(nr); }
                ds.EndAddRows();
            }
            ds.BeginModifyRows();
            foreach (DataRow r in Live(dt).Where(x => Code(x) == code)) r["Include"] = on;
            ds.EndModifyRows();
            RefreshControls();
        }

        private void AddCustom()
        {
            using (var dlg = new OpenFileDialog { Title = "Custom covariate raster", Filter = "Rasters (*.tif;*.tiff;*.img;*.vrt)|*.tif;*.tiff;*.img;*.vrt|All files (*.*)|*.*" })
            {
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                if (Live(Cov.GetData()).All(r => Code(r) == CUSTOM)) SetBuiltin(1, m_cov[0].Checked);   // keep the built-ins as they are shown
                DataSheet ds = Cov; DataTable dt = ds.GetData();
                ds.BeginAddRows();
                DataRow nr = dt.NewRow(); nr["Covariate"] = CUSTOM; nr["Include"] = true; nr["Name"] = Path.GetFileNameWithoutExtension(dlg.FileName); nr["File"] = dlg.FileName;
                dt.Rows.Add(nr);
                ds.EndAddRows();
            }
            RefreshControls();
        }

        private void RemoveCustom()
        {
            var c = m_custom.SelectedItem as Custom; if (c == null) return;
            Cov.DeleteRows(new[] { c.Row });
            RefreshControls();
        }

        private void ResetRules()
        {
            if (MessageBox.Show(this, "Replace the rule weights with the package defaults (defaults/projection/rule-weights.csv)?", "Rule Weights",
                                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var p = Defaults.Load(this.DataFeed.GetDataSheet(RULES), Defaults.PackageFile("defaults", "projection", "rule-weights.csv"), null);
            m_rulesState.Text = p.Count == 0 ? "Defaults loaded." : "Loaded, except: " + string.Join("; ", p.Take(5));
            m_rulesState.ForeColor = p.Count == 0 ? SystemColors.GrayText : Color.Firebrick;
            LoadGrid(m_rules, RULES);
        }

        protected override void ShowData()
        {
            bool editable = !(this.Scenario != null && this.Scenario.IsResult);
            m_region.ShowData(editable);
            m_res.Text = Show(Value("FitResolution"));
            m_test.Text = Show(Value("TestYears")); m_burn.Text = Show(Value("BurnWindow")); m_controls.Text = Show(Value("ControlsPerYear"));
            m_radius.Text = Show(Value("AdjacencyRadius")); m_update.Text = Show(Value("AdjacencyUpdate"));
            List<DataRow> rows = Live(Cov.GetData()).ToList();
            bool anyBuiltin = rows.Any(r => Code(r) >= 1 && Code(r) <= BUILTIN.Length);
            foreach (CheckBox cb in m_cov) { int code = (int)cb.Tag; cb.Checked = !anyBuiltin || rows.Any(r => Code(r) == code && On(r)); }
            m_custom.BeginUpdate(); m_custom.Items.Clear();
            foreach (DataRow r in rows.Where(x => Code(x) == CUSTOM)) m_custom.Items.Add(new Custom { Row = r });
            m_custom.EndUpdate();
            m_addCustom.Enabled = m_removeCustom.Enabled = m_resetRules.Enabled = editable;
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { if (m_region.IsRefreshing) return; base.OnRowsAdded(sender, e); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { if (m_region.IsRefreshing) return; base.OnRowsDeleted(sender, e); }
    }
}
