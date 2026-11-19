// =============================================================================
// ForestCoverView.cs - the Forest Cover page of a Build: what counts as forest in the start year
// =============================================================================
// User 2026-11-18: "rather than use NLCD to tell us what is forest in 1985, we use the tree cover product ... set the tree cover %
// threshold (i.e. 10%)". Single-row sheet lucasCore_ForestCoverOptions (ForestDefinition, CanopyThreshold, CanopyGate, CellRule, CellShare, CanopyRecovery,
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
        private readonly Choice m_def = new Choice("ForestDefinition", 1), m_gate = new Choice("CanopyGate", 1), m_rule = new Choice("CellRule", 1), m_rec = new Choice("CanopyRecovery", 1), m_stock = new Choice("Stocking", 1);
        private readonly TextBox m_th = Box(50), m_share = Box(50), m_rth = Box(50), m_mature = Box(50);
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
            AddGroup(Group("The canopy rule", c));
            var k = Column();
            k.Controls.Add(Note("A cell is larger than a 30 m pixel and takes one class. This sets which cells the canopy rule turns into forest."));
            k.Controls.Add(Option(m_rule, 1, "A share of the cell's pixels"));
            var s = Row(); s.Controls.Add(Caption("Share that must count:")); s.Controls.Add(m_share); s.Controls.Add(Note("Blank = 0.5 (most of the cell), as a cell takes its most common NLCD class. On a coarse grid this adds forest where the land is mostly forest: at 500 m the Northern Sierra Nevada gets 6.5 points more forest than the same rule gives at 30 m."));
            k.Controls.Add(Indent(s));
            k.Controls.Add(Option(m_rule, 2, "Area-matched"));
            k.Controls.Add(Indent(Note("In each secondary stratum unit, only as many cells become forest as bring the Build's forest area up to the area the rule gives at 30 m, taking the cells with the most canopy first. The result does not depend on the cell size.")));
            AddGroup(Group("Cells that become forest", k));
            var q = Column();
            q.Controls.Add(Note("In the historical years (stage 6) a burned or cut forest cell waits in a disturbed class until the record shows it as forest again."));
            q.Controls.Add(Option(m_rec, 1, "NLCD forest, or tree canopy cover at the threshold"));
            var rt = Row(); rt.Controls.Add(Caption("Canopy cover threshold for recovery (percent):")); rt.Controls.Add(m_rth); rt.Controls.Add(Note("Blank = 30. Higher than the start-year threshold on purpose: the canopy product reads about 20% on forest that has just burned at high severity, so 10% would call it forest again the next year."));
            q.Controls.Add(Indent(rt));
            q.Controls.Add(Indent(Note("The cell returns to its forest type in the year NLCD maps it as forest for the second year running, or the year its tree canopy cover has been at or over the recovery threshold (same BpS gate and cell share) for two years running, whichever comes first. Both canopy years must come after any high-severity fire or clearcut on half or more of the cell, because the canopy map of the fire year still shows the stand from before it. Needs the tree canopy cover of every year of the Build: run the Data Download with Datasets = TreeCanopyFolder for all its years.")));
            q.Controls.Add(Option(m_rec, 2, "NLCD forest only"));
            q.Controls.Add(Indent(Note("As without tree canopy cover. NLCD is slow to map an open regrowing stand as forest, and never does on a cell the canopy rule made forest, so such a cell waits to the end of its window and then converts to shrub or grass.")));
            AddGroup(Group("When a disturbed stand is forest again", q));
            var sg = Column();
            sg.Controls.Add(Note("The growth curves give every cell of a forest type the same carbon at an age. They are FIA's average over all forest land, open stands included, so the total is about right, but an open stand starts with too much carbon and a dense one with too little."));
            sg.Controls.Add(Option(m_stock, 1, "The same for every cell of a forest type"));
            sg.Controls.Add(Option(m_stock, 2, "By the cell's tree canopy cover"));
            sg.Controls.Add(Indent(Note("A forest cell's starting live and dead carbon and its growth are multiplied by its mean canopy cover in the start year over the mean of the mature forest of its type and ecodivision (kept within 0.3 to 2.5, with a mean of 1 for each type and ecodivision). Where the Build has TreeMap 2016 (Data Sources: TreeMapFolder) and the tree canopy cover of 2016, carbon follows canopy along a curve fitted to TreeMap for each forest type of the study area, which flattens where dense stands stop gaining carbon; without them it is in proportion to canopy. It multiplies with the site productivity multiplier, which is about how fast the site grows trees, not how fully they occupy it. A cell keeps its multiplier through a fire or a cut. The carbon capacity is not scaled. Works with either forest definition above; needs the tree canopy cover of the start year.")));
            var ma = Row(); ma.Controls.Add(Caption("Canopy shows stocking from a stand age of (years):")); ma.Controls.Add(m_mature); ma.Controls.Add(Note("Blank = 30. A younger stand has a low canopy for its age, which its curve already holds, so it takes the multiplier of the mature forest near it. So does forest that starts in a disturbed class."));
            sg.Controls.Add(Indent(ma));
            AddGroup(Group("Carbon of a forest cell (stocking; stage 8)", sg));
            var f = Column();
            f.Controls.Add(Note("Optional. A folder holding science_tcc_conus_<year>.tif for the start year. Blank = the tree-canopy folder of Data Sources Home, where a Data Download puts it."));
            var r = Row(); r.Controls.Add(Caption("Folder:")); r.Controls.Add(m_folder); r.Controls.Add(m_browse); f.Controls.Add(r);
            AddGroup(Group("Tree canopy cover folder", f));
            var n = Column(); n.Controls.Add(Note("These settings take effect when stages 5 and 6 run (a new Build). Build Results > Forest by Tree Canopy Cover lists, by forest type, the cells the canopy rule made forest and what NLCD maps them as; Forest Area Check (FIA) puts the Build's forest share beside the forest inventory's, to tune these settings. Forest that NLCD maps is never removed at the start: a burned or cut stand with little canopy is still forest land."));
            AddGroup(Group("When it applies", n));
            EndGroups();
            BindNumber(m_th, () => Sheet, "CanopyThreshold", true); BindNumber(m_rth, () => Sheet, "RecoveryThreshold", true); BindNumber(m_share, () => Sheet, "CellShare", false); BindNumber(m_mature, () => Sheet, "StockingMatureAge", true);
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
            ShowChoice(m_def); ShowChoice(m_gate); ShowChoice(m_rule); ShowChoice(m_rec); ShowChoice(m_stock);
            m_mature.Text = Show(Value("StockingMatureAge")); m_mature.Enabled = IntValue("Stocking", 1) == 2;
            m_th.Text = Show(Value("CanopyThreshold")); m_rth.Text = Show(Value("RecoveryThreshold")); m_rth.Enabled = IntValue("ForestDefinition", 1) == 2 && IntValue("CanopyRecovery", 1) == 1; m_share.Text = Show(Value("CellShare"));
            object f = Value("TreeCanopyFolder"); m_folder.Text = f == DBNull.Value ? "" : Convert.ToString(f);
            bool on = IntValue("ForestDefinition", 1) == 2;
            m_th.Enabled = on; m_share.Enabled = on && IntValue("CellRule", 1) == 1; m_folder.Enabled = on; m_browse.Enabled = on;
            foreach (RadioButton b in m_gate.Buttons) b.Enabled = on;
            foreach (RadioButton b in m_rule.Buttons) b.Enabled = on;
            foreach (RadioButton b in m_rec.Buttons) b.Enabled = on;
        }
    }
}
