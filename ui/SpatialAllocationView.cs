// =============================================================================
// SpatialAllocationView.cs - the Spatial Allocation page of a Projection Setup: what the placement surfaces are fitted on (stage 10)
// =============================================================================
// Feed SpatialAllocation = Suitability Options (single row) + Suitability Fitting Region + Suitability Covariates + Allocation Rule
// Weights. The fitting region uses the Study Area picker (its kind kept in SuitabilityOptions.RegionSourceId). Covariates are chosen per
// surface: rows with a blank Surface apply to every surface and a surface's own row adds or (unticked) drops one, as stage 10 reads
// them; the page shows the choice for the surface picked above the check boxes. An empty sheet means defaults/projection/covariates.csv
// (shown as such; the first change copies it in). The rule weights are SyncroSim's own grid.
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
        private static readonly int[] CODES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14 };
        private static readonly string[] NAMES = { "Distance to developed land", "Developed share within 1 km", "Housing density (census decade)", "Distance to roads",
                                                   "Slope", "Elevation", "Land cover", "GAP status", "County", "Distance to agriculture", "Agriculture share within 1 km",
                                                   "Crop productivity (NCCPI)", "Forest owner type" };
        private const int CUSTOM = 10;
        private const string EVERY = "Every surface";

        private readonly UnitPicker m_region = new UnitPicker("Fit the regression on", 70);
        private readonly ComboBox m_res = new ComboBox { Width = 80, DropDownStyle = ComboBoxStyle.DropDown, Margin = new Padding(3, 3, 12, 3) };
        private readonly TextBox m_test = Box(50), m_burn = Box(50), m_controls = Box(70), m_radius = Box(70), m_update = Box(50), m_flicker = Box(50);
        private readonly Label m_regionState = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 3, 3, 6) };
        private readonly CheckBox m_patches = new CheckBox { Text = "Place patches: historical event sizes become ST-Sim size distributions", AutoSize = true };
        private readonly ComboBox m_surface = List(220);
        private readonly Label m_covState = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(8, 7, 3, 3) };
        private readonly List<CheckBox> m_cov = new List<CheckBox>();
        private readonly ListBox m_custom = new ListBox { Width = 420, Height = 60, IntegralHeight = false };
        private readonly Button m_addCustom = new Button { Text = "Add raster...", AutoSize = true }, m_removeCustom = new Button { Text = "Remove", AutoSize = true };
        private readonly Panel m_rules = GridHost(200);
        private readonly Button m_resetRules = new Button { Text = "Reset rule weights to defaults", AutoSize = true };
        private readonly Label m_rulesState = new Label { AutoSize = true, Margin = new Padding(8, 8, 3, 3) };
        private List<string> m_surfaces = new List<string>();

        // a covariate row, from the sheet or (sheet empty) from the package defaults
        private class Cov { public string Surface; public int Code; public bool On; public string Name, File; public DataRow Row; }
        private class Custom { public Cov C; public override string ToString() { return string.Format("{0}  ({1})", C.Name, C.File); } }

        public SpatialAllocationView()
        {
            this.SuspendLayout();
            m_region.UnitSheet = () => this.DataFeed.GetDataSheet(REGION);
            m_region.KindSheet = () => Sheet;
            m_region.KindColumn = "RegionSourceId";
            m_region.AllText = "The study area"; m_region.AllSummary = "the study area"; m_region.Subject = "Fitting region"; m_region.Confirm = "Fitting Region";
            m_region.AllNote = "A small study area has few change events: fit on a larger region (its pyrome, neighbouring counties, the state) instead.";
            m_region.Changed = RefreshControls;
            // the picker shows and edits the rows of the surface chosen at the top (blank Surface = every surface)
            m_region.RowFilter = r => string.Equals(r["Surface"] == DBNull.Value ? "" : Convert.ToString(r["Surface"]), Sel, StringComparison.OrdinalIgnoreCase);
            m_region.NewRow = r => { r["Surface"] = Sel.Length > 0 ? (object)Sel : DBNull.Value; };
            var top = Row(); top.Controls.Add(Caption("Settings for:")); top.Controls.Add(m_surface);
            top.Controls.Add(Note("the fitting region and covariates below apply to this surface; Every surface = the default the others inherit"));
            AddGroup(Group("Surface", top));
            var regionHost = GridHost(260); m_region.Dock = DockStyle.Fill; regionHost.Controls.Add(m_region);
            AddGroup(Group("Fitting region", ProjectionTransitionsView.Stack(m_regionState, regionHost)));

            foreach (int r in new[] { 30, 60, 90, 150, 300, 990 }) m_res.Items.Add(r.ToString());
            var fit = Form();
            FormRow(fit, "Fitting resolution (m):", m_res, "30 = native NLCD; coarser fits faster");
            FormRow(fit, "Out-of-sample test years:", m_test, "the last N historical years are held out to score the surface (0 = no test)");
            FormRow(fit, "Leave out burned pixels (years):", m_burn, "NLCD relabels burned forest as developed open space for a few years");
            FormRow(fit, "Unchanged pixels per year:", m_controls, "the controls sampled against the change events");
            FormRow(fit, "Agriculture flicker window (years):", m_flicker, "ag events that undo a change of the last N years are NLCD flicker, not change (0 = off)");
            var fitCol = Column(); fitCol.Controls.Add(fit); fitCol.Controls.Add(m_patches);
            fitCol.Controls.Add(Wrapped("Patches: the change events of each historical year are joined into patches; each group's patch sizes, in model cells, decide how big its projected events are. Skipped where nearly all patches fit in one model cell (1 km models).", 640));
            AddGroup(Group("Fitting", fitCol));

            var cov = Column();
            cov.Controls.Add(m_covState);
            var boxes = new FlowLayoutPanel { AutoSize = true, WrapContents = true, MaximumSize = new Size(760, 0), Margin = new Padding(0) };
            for (int i = 0; i < CODES.Length; i++)
            {
                int code = CODES[i];
                var cb = new CheckBox { Text = NAMES[i], AutoSize = true, Margin = new Padding(3, 3, 18, 3), Tag = code };
                cb.CheckedChanged += (s, e) => { if (!Refreshing) SetBuiltin(code, cb.Checked); };
                m_cov.Add(cb); boxes.Controls.Add(cb);
            }
            cov.Controls.Add(boxes);
            var cr = Row(); cr.Controls.Add(m_custom); var cbtn = Column(); cbtn.Controls.Add(m_addCustom); cbtn.Controls.Add(m_removeCustom); cr.Controls.Add(cbtn);
            cov.Controls.Add(cr);
            cov.Controls.Add(Wrapped("Every surface: the covariates all surfaces use. A surface (Ag Expansion, Clearcut, ...): ticks that differ from every surface are kept as its own rows. Custom rasters are resampled to the fitting grid.", 640));
            AddGroup(Group("Covariates", cov));

            var adj = Form();
            FormRow(adj, "Neighbourhood radius (m):", m_radius, "blank = 3 model cells; the developed (or agriculture) share within it drives the adjacency multiplier");
            FormRow(adj, "Update every (years):", m_update, null);
            AddGroup(Group("Adjacency (groups with Adjacency ticked on the Transitions page)", adj));

            var rr = Row(); rr.Controls.Add(m_resetRules); rr.Controls.Add(m_rulesState);
            AddGroup(Group("Rule weights (Rules method)", ProjectionTransitionsView.Stack(
                Note("A weight per WUI class (2020) and per GAP status for each surface; the surface is their product (0 = never; no weights = 1 everywhere)."), m_rules, rr)));
            EndGroups();

            m_res.Validated += (s, e) => { if (Refreshing) return; int v; if (int.TryParse(m_res.Text.Trim(), out v) && v >= 30 && v % 30 == 0) Write("FitResolution", v); RefreshControls(); };
            m_res.SelectionChangeCommitted += (s, e) => { if (!Refreshing && m_res.SelectedItem != null) Write("FitResolution", int.Parse((string)m_res.SelectedItem)); };
            BindNumber(m_test, () => Sheet, "TestYears", true); BindNumber(m_burn, () => Sheet, "BurnWindow", true); BindNumber(m_controls, () => Sheet, "ControlsPerYear", true);
            BindNumber(m_radius, () => Sheet, "AdjacencyRadius", false); BindNumber(m_update, () => Sheet, "AdjacencyUpdate", true);
            BindNumber(m_flicker, () => Sheet, "FlickerYears", true);
            m_patches.CheckedChanged += (s, e) => { if (!Refreshing) Write("PatchSizes", m_patches.Checked); };
            m_surface.SelectionChangeCommitted += (s, e) => RefreshControls();
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
            // the surfaces: this scenario's Projection Allocation (read once: another feed), else the package defaults, plus any in the covariates
            var names = new List<string>();
            try
            {
                Scenario sc = this.DataFeed.Scenario;
                if (sc != null) names.AddRange(sc.GetDataSheet("lucasCore_ProjectionAllocation").GetData().Rows.Cast<DataRow>()
                    .Where(r => r.RowState != DataRowState.Deleted && r["Surface"] != DBNull.Value).Select(r => Convert.ToString(r["Surface"])));
            }
            catch (Exception) { }
            if (names.Count == 0)
            {
                string f = Defaults.PackageFile("defaults", "projection", "allocation.csv");
                if (File.Exists(f)) { List<string[]> rows = Defaults.ReadCsv(f); int j = Array.IndexOf(rows[0], "Surface"); if (j >= 0) names.AddRange(rows.Skip(1).Where(r => r.Length > j).Select(r => r[j])); }
            }
            names.AddRange(Rows().Select(c => c.Surface));
            names.AddRange(Live(this.DataFeed.GetDataSheet(REGION).GetData()).Where(r => r["Surface"] != DBNull.Value).Select(r => Convert.ToString(r["Surface"])));
            m_surfaces = names.Where(n => !string.IsNullOrEmpty(n)).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(n => n).ToList();
            m_surface.Items.Clear(); m_surface.Items.Add(EVERY); foreach (string n in m_surfaces) m_surface.Items.Add(n); m_surface.SelectedIndex = 0;
            RefreshControls();
        }

        private DataSheet CovSheet { get { return this.DataFeed.GetDataSheet(COVARIATES); } }
        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted); }
        private string Sel { get { return m_surface.SelectedIndex <= 0 ? "" : (string)m_surface.SelectedItem; } }
        private bool Empty { get { return !Live(CovSheet.GetData()).Any(); } }

        private List<Cov> Rows()
        {
            List<DataRow> live = Live(CovSheet.GetData()).ToList();
            if (live.Count > 0)
                return live.Select(r => new Cov { Surface = r["Surface"] == DBNull.Value ? "" : Convert.ToString(r["Surface"]), Code = r["Covariate"] == DBNull.Value ? 0 : Convert.ToInt32(r["Covariate"]),
                    On = r["Include"] == DBNull.Value || Convert.ToBoolean(r["Include"]), Name = Show(r["Name"]), File = Show(r["File"]), Row = r }).ToList();
            // the package defaults, as stage 10 reads an empty sheet
            var res = new List<Cov>(); string f = Defaults.PackageFile("defaults", "projection", "covariates.csv");
            if (!File.Exists(f)) return res;
            List<string[]> rows = Defaults.ReadCsv(f); string[] h = rows[0];
            Func<string[], string, string> at = (r, k) => { int j = Array.IndexOf(h, k); return j >= 0 && j < r.Length ? r[j].Trim() : ""; };
            foreach (string[] r in rows.Skip(1))
            {
                string name = at(r, "Covariate"); int i = Array.IndexOf(NAMES, name);
                res.Add(new Cov { Surface = at(r, "Surface"), Code = i >= 0 ? CODES[i] : (name == "Custom raster" ? CUSTOM : 0), On = at(r, "Include").Equals("Yes", StringComparison.OrdinalIgnoreCase), Name = at(r, "Name"), File = at(r, "File") });
            }
            return res;
        }

        // what a surface uses: its own row, else the row for every surface
        private static bool Effective(List<Cov> rows, int code, string surface)
        {
            Cov own = rows.FirstOrDefault(c => c.Code == code && string.Equals(c.Surface, surface, StringComparison.OrdinalIgnoreCase));
            if (own != null) return own.On;
            if (surface.Length == 0) return false;
            Cov all = rows.FirstOrDefault(c => c.Code == code && c.Surface.Length == 0);
            return all != null && all.On;
        }

        private void EnsureRows()
        {
            if (!Empty) return;
            Defaults.Load(CovSheet, Defaults.PackageFile("defaults", "projection", "covariates.csv"), null);
        }

        private void SetBuiltin(int code, bool on)
        {
            EnsureRows();
            DataSheet ds = CovSheet; DataTable dt = ds.GetData(); string s = Sel; List<Cov> rows = Rows();
            Cov own = rows.FirstOrDefault(c => c.Code == code && string.Equals(c.Surface, s, StringComparison.OrdinalIgnoreCase));
            bool inherited = s.Length > 0 && Effective(rows.Where(c => c != own).ToList(), code, s) == on;
            if (own != null && inherited) ds.DeleteRows(new[] { own.Row });                       // same as every surface: no row of its own
            else if (own != null) { ds.BeginModifyRows(); own.Row["Include"] = on; ds.EndModifyRows(); }
            else if (!inherited)
            {
                ds.BeginAddRows(); DataRow nr = dt.NewRow(); nr["Surface"] = s.Length > 0 ? (object)s : DBNull.Value; nr["Covariate"] = code; nr["Include"] = on; dt.Rows.Add(nr); ds.EndAddRows();
            }
            RefreshControls();
        }

        private void AddCustom()
        {
            using (var dlg = new OpenFileDialog { Title = "Custom covariate raster", Filter = "Rasters (*.tif;*.tiff;*.img;*.vrt)|*.tif;*.tiff;*.img;*.vrt|All files (*.*)|*.*" })
            {
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                EnsureRows();
                DataSheet ds = CovSheet; DataTable dt = ds.GetData();
                ds.BeginAddRows();
                DataRow nr = dt.NewRow(); nr["Surface"] = Sel.Length > 0 ? (object)Sel : DBNull.Value; nr["Covariate"] = CUSTOM; nr["Include"] = true;
                nr["Name"] = Path.GetFileNameWithoutExtension(dlg.FileName); nr["File"] = dlg.FileName;
                dt.Rows.Add(nr);
                ds.EndAddRows();
            }
            RefreshControls();
        }

        private void RemoveCustom()
        {
            var c = m_custom.SelectedItem as Custom; if (c == null || c.C.Row == null) return;
            CovSheet.DeleteRows(new[] { c.C.Row });
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
            m_radius.Text = Show(Value("AdjacencyRadius")); m_update.Text = Show(Value("AdjacencyUpdate")); m_flicker.Text = Show(Value("FlickerYears"));
            List<DataRow> rrows = Live(this.DataFeed.GetDataSheet(REGION).GetData()).ToList();
            Func<DataRow, string> rs = r => r["Surface"] == DBNull.Value ? "" : Convert.ToString(r["Surface"]);
            int ownR = rrows.Count(r => string.Equals(rs(r), Sel, StringComparison.OrdinalIgnoreCase)), allR = rrows.Count(r => rs(r).Length == 0);
            m_regionState.Text = Sel.Length == 0 ? "The region every surface without units of its own is fitted on." : ownR > 0 ? string.Format("{0} fits on its own {1} unit{2}.", Sel, ownR, ownR == 1 ? "" : "Sel")
                : allR > 0 ? string.Format("{0} has no units of its own: it fits on the every-surface region ({1} unit{2}). Add units here to give it its own.", Sel, allR, allR == 1 ? "" : "Sel")
                : string.Format("{0} has no units of its own: it fits on the study area. Add units here to give it its own.", Sel);
            object ps = Value("PatchSizes"); m_patches.Checked = ps == DBNull.Value || Convert.ToBoolean(ps);
            List<Cov> rows = Rows(); string s = Sel;
            foreach (CheckBox cb in m_cov) cb.Checked = Effective(rows, (int)cb.Tag, s);
            m_custom.BeginUpdate(); m_custom.Items.Clear();
            foreach (Cov c in rows.Where(x => x.Code == CUSTOM && (string.Equals(x.Surface, s, StringComparison.OrdinalIgnoreCase) || (s.Length > 0 && x.Surface.Length == 0)))) m_custom.Items.Add(new Custom { C = c });
            m_custom.EndUpdate();
            int own = s.Length == 0 ? 0 : rows.Count(c => string.Equals(c.Surface, s, StringComparison.OrdinalIgnoreCase));
            m_covState.Text = Empty ? "(package defaults)" : s.Length == 0 ? "" : own == 0 ? "same as every surface" : string.Format("{0} row{1} of its own", own, own == 1 ? "" : "s");
            m_addCustom.Enabled = m_removeCustom.Enabled = m_resetRules.Enabled = editable;
        }

        protected override void OnRowsAdded(object sender, DataSheetRowEventArgs e) { if (m_region.IsRefreshing) return; base.OnRowsAdded(sender, e); }
        protected override void OnRowsDeleted(object sender, DataSheetRowEventArgs e) { if (m_region.IsRefreshing) return; base.OnRowsDeleted(sender, e); }
    }
}
