// =============================================================================
// FireOptionsView.cs - the Fire page of a projection: which fire method, and each method's settings
// =============================================================================
// Single-row sheet lucasCore_FireOptions, unchanged (stage 9 reads it). The three methods are radio buttons; each method's settings
// sit in their own group, enabled only when that method is chosen. Blank still means default: the fire group Fire, the burn
// probability of Data Sources (FSim CONUS 270 m), ignitions from the burn probability, a 5,000 m ignition smoothing.
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
    public class FireOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_FireOptions"; } }

        private class Item { public object Key; public string Name; public override string ToString() { return Name; } }

        private readonly Choice m_method = new Choice("FireMethod", 1);
        private readonly Choice m_ign = new Choice("IgnitionSource", 1);
        private readonly ComboBox m_group = List(260);
        private readonly CheckBox m_slope = new CheckBox { Text = "Slope selectivity: burned share by slope from the fire record", AutoSize = true, Margin = new Padding(3, 5, 3, 3) };
        private readonly TextBox m_bp = new TextBox { Width = 460, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_bpBrowse = new Button { Text = "Browse...", AutoSize = true };
        private readonly TextBox m_bw = Box(70);
        private readonly TextBox m_lib = new TextBox { Width = 460, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_libBrowse = new Button { Text = "Browse...", AutoSize = true };
        private readonly TextBox m_rid = Box(70);
        private GroupBox m_g1, m_g2, m_g3;
        private List<Item> m_groups = new List<Item>();

        public FireOptionsView()
        {
            this.SuspendLayout();
            var top = Column();
            var gr = Row(); gr.Controls.Add(Caption("Fire group:")); gr.Controls.Add(m_group); top.Controls.Add(gr);
            top.Controls.Add(Option(m_method, 1, "1. Historical rates: each year burns the drawn historical year's share of each pyrome"));
            top.Controls.Add(Option(m_method, 2, "2. Burn probability: as 1, with spread and ignitions guided by a burn-probability map"));
            top.Controls.Add(Option(m_method, 3, "3. lucasFireC2F seasons: each year takes a whole simulated fire season (perimeters and severity)"));
            top.Controls.Add(Wrapped("Methods 1 and 2 keep each pyrome's burned area from the drawn year, use the drawn year's own mix of low, medium and high severity, and size fires from the interagency perimeters (an ST-Sim size distribution from the first projection year). Method 3 takes all of that from the C2F season.", 680));
            AddGroup(Group("Fire method", top));

            var c1 = Column(); c1.Controls.Add(m_slope);
            c1.Controls.Add(Wrapped("Each cell's fire probability is scaled by how much more (or less) its slope burned in the historical record, rescaled within the pyrome so the pyrome's burned area holds.", 680));
            m_g1 = Group("Method 1: historical rates", c1); AddGroup(m_g1);

            var c2 = Column();
            var b = Row(); b.Controls.Add(Caption("Burn probability raster:")); b.Controls.Add(m_bp); b.Controls.Add(m_bpBrowse); c2.Controls.Add(b);
            c2.Controls.Add(Wrapped("Blank = the Data Sources burn probability (FSim CONUS LF2020, 270 m). WRC or a lucasFireC2F burn probability work too. It replaces slope selectivity, which it already holds.", 680));
            var ig = Row(); ig.Controls.Add(Caption("Ignitions from:")); ig.Controls.Add(Option(m_ign, 1, "the burn probability")); ig.Controls.Add(Option(m_ign, 2, "FPA-FOD ignition density")); c2.Controls.Add(ig);
            var bwr = Row(); bwr.Controls.Add(Caption("Ignition smoothing (m):")); bwr.Controls.Add(m_bw); bwr.Controls.Add(Note("FPA-FOD fire origins smoothed with a Gaussian of this width (blank = 5000)")); c2.Controls.Add(bwr);
            m_g2 = Group("Method 2: burn probability", c2); AddGroup(m_g2);

            var c3 = Column();
            var l = Row(); l.Controls.Add(Caption("lucasFireC2F library:")); l.Controls.Add(m_lib); l.Controls.Add(m_libBrowse); c3.Controls.Add(l);
            var r = Row(); r.Controls.Add(Caption("Result scenario Id:")); r.Controls.Add(m_rid); r.Controls.Add(Note("a C2F run or merge whose stage 8 wrote the per-burn effects table")); c3.Controls.Add(r);
            c3.Controls.Add(Wrapped("One-way coupling: the C2F run is made first, and each projection year and iteration draws one of its seasons. Dynamic coupling (fuels and climate passed back to C2F every N years) comes later.", 680));
            m_g3 = Group("Method 3: lucasFireC2F seasons", c3); AddGroup(m_g3);
            EndGroups();

            m_group.SelectionChangeCommitted += (s, e) => { var i = m_group.SelectedItem as Item; Write("TransitionGroupId", i == null ? DBNull.Value : i.Key); };
            m_slope.CheckedChanged += (s, e) => { if (!Refreshing) Write("SlopeSelectivity", m_slope.Checked); };
            m_bp.Validated += (s, e) => { if (!Refreshing) Write("BurnProbabilityFile", m_bp.Text.Trim().Length == 0 ? (object)DBNull.Value : m_bp.Text.Trim()); };
            m_lib.Validated += (s, e) => { if (!Refreshing) Write("C2FLibrary", m_lib.Text.Trim().Length == 0 ? (object)DBNull.Value : m_lib.Text.Trim()); };
            BindNumber(m_bw, () => Sheet, "IgnitionBandwidth", false); BindNumber(m_rid, () => Sheet, "C2FScenarioId", true);
            m_bpBrowse.Click += (s, e) => Browse(m_bp, "BurnProbabilityFile", "Rasters (*.tif;*.tiff;*.img;*.vrt)|*.tif;*.tiff;*.img;*.vrt|All files (*.*)|*.*");
            m_libBrowse.Click += (s, e) => Browse(m_lib, "C2FLibrary", "SyncroSim libraries (*.ssim)|*.ssim");
            this.ResumeLayout(false);
        }

        private void Browse(TextBox t, string column, string filter)
        {
            using (var dlg = new OpenFileDialog { Filter = filter })
            {
                if (dlg.ShowDialog(this) != DialogResult.OK) return;
                t.Text = dlg.FileName; Write(column, dlg.FileName); RefreshControls();
            }
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            m_groups = this.DataFeed.Project.GetDataSheet("stsim_TransitionGroup").GetData().Rows.Cast<DataRow>()
                .Where(x => x.RowState != DataRowState.Deleted && !Convert.ToString(x["Name"]).EndsWith("[Type]"))
                .Select(x => new Item { Key = Convert.ToInt32(x["TransitionGroupId"]), Name = Convert.ToString(x["Name"]) }).OrderBy(x => x.Name).ToList();
            RefreshControls();
        }

        protected override void OnChoiceChanged(Choice c) { RefreshControls(); }

        protected override void ShowData()
        {
            ShowChoice(m_method); ShowChoice(m_ign);
            object gid = Value("TransitionGroupId");
            m_group.BeginUpdate(); m_group.Items.Clear(); m_group.Items.Add(new Item { Key = DBNull.Value, Name = "(Fire)" });
            int idx = 0; foreach (Item i in m_groups) { m_group.Items.Add(i); if (gid != DBNull.Value && Convert.ToInt32(i.Key) == Convert.ToInt32(gid)) idx = m_group.Items.Count - 1; }
            m_group.SelectedIndex = idx; m_group.EndUpdate();
            object sl = Value("SlopeSelectivity"); m_slope.Checked = sl == DBNull.Value || Convert.ToBoolean(sl);
            m_bp.Text = Show(Value("BurnProbabilityFile")); m_bw.Text = Show(Value("IgnitionBandwidth"));
            m_lib.Text = Show(Value("C2FLibrary")); m_rid.Text = Show(Value("C2FScenarioId"));
            int m = IntValue("FireMethod", 1);
            m_g1.Enabled = m == 1; m_g2.Enabled = m == 2; m_g3.Enabled = m == 3;
        }
    }
}
