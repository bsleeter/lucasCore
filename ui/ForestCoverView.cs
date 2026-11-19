// =============================================================================
// ForestCoverView.cs - the Forest Cover page of a Build: what counts as forest in the start year
// =============================================================================
// User 2026-11-18: "rather than use NLCD to tell us what is forest in 1985, we use the tree cover product ... set the tree cover %
// threshold (i.e. 10%)". Single-row sheet lucasCore_ForestCoverOptions (ForestDefinition, CanopyThreshold, CanopyGate, CellShare,
// TreeCanopyFolder); stage 5 reads it (src/forest-cover.R, forest_cover_options). Choices as radio buttons with what each means, as
// on the Stand Age page.
// =============================================================================
using System;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class ForestCoverView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ForestCoverOptions"; } }
        private readonly Choice m_def = new Choice("ForestDefinition", 1), m_gate = new Choice("CanopyGate", 1);
        private readonly TextBox m_th = Box(50), m_share = Box(50);
        private readonly TextBox m_folder = new TextBox { Width = 460, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_browse = new Button { Text = "Browse...", AutoSize = true };

        public ForestCoverView()
        {
            this.SuspendLayout();
            var d = Column();
            d.Controls.Add(Note("Every class comes from the annual NLCD of the start year. This page sets what else starts as forest."));
            d.Controls.Add(Option(m_def, 1, "Annual NLCD"));
            d.Controls.Add(Indent(Note("A natural cell is forest when NLCD maps it as forest in the start year or in any later year (regrowing and reforesting cells are then given their own start, see Reforestation Options). NLCD maps much open western forest as shrub or grass: in 2016 it has 44% of Yellowstone's land and 66% of the Northern Sierra Nevada's as forest, where the forest inventory (FIA) has 83% and 85%.")));
            d.Controls.Add(Option(m_def, 2, "Annual NLCD and tree canopy cover"));
            d.Controls.Add(Indent(Note("As above, and a cell NLCD maps as barren, shrub or grass in the start year also starts as forest when its tree canopy cover in the start year is at or over the threshold below (USFS Science Tree Canopy Cover, 30 m, 1985 to 2023). It takes the forest type map's type and the age map's age. Needs the tree canopy cover of the start year: run a Data Download with Datasets = TreeCanopyFolder.")));
            AddGroup(Group("Forest in the start year", d));

            var c = Column();
            var t = Row(); t.Controls.Add(Caption("Canopy cover threshold (percent):")); t.Controls.Add(m_th); t.Controls.Add(Note("Blank = 10, the forest inventory's own definition of forest land."));
            c.Controls.Add(t);
            c.Controls.Add(Option(m_gate, 1, "Only where LANDFIRE BpS is forest"));
            c.Controls.Add(Indent(Note("A pixel counts when its canopy cover is at or over the threshold and its potential vegetation (LANDFIRE Biophysical Settings) is forest. At 10% this gave 86% forest in Yellowstone and in the Northern Sierra Nevada and 57% in Great Dismal Swamp, against FIA's 83%, 85% and 52%.")));
            c.Controls.Add(Option(m_gate, 2, "Anywhere"));
            c.Controls.Add(Indent(Note("Canopy cover alone. The canopy product gives shrubland and grassland a cover of 20 to 25% in the West, so at 10% this takes in most of it (about 90% forest in both western regions); use a threshold of about 15% with it.")));
            var s = Row(); s.Controls.Add(Caption("Share of a cell's 30 m pixels that must count:")); s.Controls.Add(m_share); s.Controls.Add(Note("Blank = 0.5 (most of the cell), as a cell takes its most common NLCD class."));
            c.Controls.Add(s);
            AddGroup(Group("The canopy rule", c));

            var f = Column();
            f.Controls.Add(Note("Optional. A folder holding science_tcc_conus_<year>.tif for the start year. Blank = the tree-canopy folder of Data Sources Home, where a Data Download puts it."));
            var r = Row(); r.Controls.Add(Caption("Folder:")); r.Controls.Add(m_folder); r.Controls.Add(m_browse); f.Controls.Add(r);
            AddGroup(Group("Tree canopy cover folder", f));

            var n = Column(); n.Controls.Add(Note("These settings take effect when stage 5 runs (a new Build). Build Results > Forest by Tree Canopy Cover lists, by forest type, the cells the canopy rule made forest and what NLCD maps them as. Forest that NLCD maps is never removed: a burned or cut stand with little canopy is still forest land. When a disturbed stand counts as regrown still follows NLCD."));
            AddGroup(Group("When it applies", n));
            EndGroups();
            BindNumber(m_th, () => Sheet, "CanopyThreshold", true); BindNumber(m_share, () => Sheet, "CellShare", false);
            m_folder.Validated += (o, e) => { if (!Refreshing) Write("TreeCanopyFolder", m_folder.Text.Trim().Length == 0 ? (object)DBNull.Value : m_folder.Text.Trim()); };
            m_browse.Click += (o, e) =>
            {
                using (var dlg = new FolderBrowserDialog { Description = "Tree canopy cover folder" })
                {
                    if (dlg.ShowDialog(this) != DialogResult.OK) return;
                    m_folder.Text = dlg.SelectedPath; Write("TreeCanopyFolder", dlg.SelectedPath); RefreshControls();
                }
            };
            this.ResumeLayout(false);
        }

        private static Control Indent(Control c) { c.Margin = new Padding(22, 0, 3, 8); return c; }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            RefreshControls();
        }

        protected override void ShowData()
        {
            ShowChoice(m_def); ShowChoice(m_gate);
            m_th.Text = Show(Value("CanopyThreshold")); m_share.Text = Show(Value("CellShare"));
            object f = Value("TreeCanopyFolder"); m_folder.Text = f == DBNull.Value ? "" : Convert.ToString(f);
            bool on = IntValue("ForestDefinition", 1) == 2;
            m_th.Enabled = on; m_share.Enabled = on; m_folder.Enabled = on; m_browse.Enabled = on;
            foreach (RadioButton b in m_gate.Buttons) b.Enabled = on;
        }
    }
}
