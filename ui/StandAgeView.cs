// =============================================================================
// StandAgeView.cs - the Stand Age page of a Build: how a cell takes its age, and the age of forest the age map cannot know
// =============================================================================
// User 2026-11-18: "For stands where the age is unknown, have a default approach, one based of a user input value for each forest
// type, or an uploaded raster would all be good options to have in place." Single-row sheet lucasCore_StandAgeOptions (Aggregation,
// UnknownRule, UnknownPercentile, AgeRasterFile, AgeRasterYear); stage 5 reads it (src/stand-age.R, age_options). The ages by forest
// type are the multi-row sheet lucasCore_StandAgeUnknown of the same feed (StandAge), shown as a grid under Manual settings with the
// stand age raster (user 2026-11-19: one page, not two; the table is a manual setting). Choices as radio buttons with what each means.
// =============================================================================
using System;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class StandAgeView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_StandAgeOptions"; } }
        private readonly Choice m_agg = new Choice("Aggregation", 1), m_unknown = new Choice("UnknownRule", 1);
        private readonly TextBox m_pct = Box(50), m_year = Box(60);
        private readonly TextBox m_file = new TextBox { Width = 460, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_browse = new Button { Text = "Browse...", AutoSize = true };
        private const string AGES = "lucasCore_StandAgeUnknown";
        private readonly Panel m_grid = GridHost(190);

        public StandAgeView()
        {
            this.SuspendLayout();
            var a = Column();
            a.Controls.Add(Note("Stand ages come from the Stand Age Source on Build Options (NASA CMS 1990 or TreeMap 2016), at 30 m, moved to the start year."));
            a.Controls.Add(Option(m_agg, 1, "The pixel at the cell's centre"));
            a.Controls.Add(Indent(Note("One stand's age for each cell, so the landscape keeps the young and old stands the age map has. A cell whose centre pixel has no age takes the mean of its pixels that do.")));
            a.Controls.Add(Option(m_agg, 2, "Mean of the cell's pixels"));
            a.Controls.Add(Indent(Note("The rule until lucasCore 1.6.0. Smoother from cell to cell, but it pulls every cell toward the middle: a landscape of cell means has few young and few old stands, and carbon does not rise in a straight line with age.")));
            AddGroup(Group("A cell's stand age", a));

            var u = Column();
            u.Controls.Add(Note("The age maps were made after the start year. Forest that burned or was clearcut between the start year and the map's year shows in the map as what grew back, or as its unburned remnants, not as what stood there in the start year."));
            u.Controls.Add(Option(m_unknown, 1, "Estimate it"));
            u.Controls.Add(Indent(Note("A forest cell inside a fire perimeter of those years (stage 5), or clearcut in them (stage 6, from the harvest maps), takes, in this order: the manual settings below (the stand age raster, then the age for its forest type); NASA CMS 1990 where that saw the stand before its fire or cut (a TreeMap Build); else the percentile below of the ages of forest of its type in its ecodivision that neither burned nor was cut. A cut stand is then still at least its minimum harvest age at its cut.")));
            var p = Row(); p.Controls.Add(Caption("Percentile:")); p.Controls.Add(m_pct); p.Controls.Add(Note("Blank = 75. The upper part, because the stands a fire or a harvest takes are on average older than the ones it leaves; 50 assumes they were alike."));
            u.Controls.Add(Indent(p));
            u.Controls.Add(Option(m_unknown, 2, "Keep the age map's value"));
            u.Controls.Add(Indent(Note("As before lucasCore 1.6.0. The stand age raster under Manual settings is still used where it has a value.")));
            AddGroup(Group("Forest burned or clearcut between the start year and the age map's year", u));

            var f = Row(); f.Controls.Add(Caption("Raster:")); f.Controls.Add(m_file); f.Controls.Add(m_browse);
            var y = Row(); y.Controls.Add(Caption("Its ages are for the year:")); y.Controls.Add(m_year); y.Controls.Add(Note("Blank = the start year. Another year's ages are moved to the start year."));
            AddGroup(Group("Manual settings", ProjectionTransitionsView.Stack(
                Note("Optional. Ages you set yourself, which come before the estimates above. Leave both empty to use the estimates."),
                Heading("Ages by forest type"),
                Note("The stand age in the start year of forest of a type that burned or was clearcut before the age map's year, where the fire or harvest history is known. A row with an ecodivision comes before a row for all ecodivisions; a forest type with no row is estimated as above."),
                m_grid,
                Heading("Stand age raster"),
                Note("A raster of stand age in years. Every forest cell it gives a value takes that age, burned or not, and before the ages by forest type; cells it leaves empty follow the rules above."),
                f, y)));
            var n = Column(); n.Controls.Add(Note("These settings take effect when stages 5 and 6 run (a new Build). Build Results > Stand Age Summary (burned forest) and Stand Age Summary: Cut Stands list, by forest type, how many cells each rule set and the ages it gave."));
            AddGroup(Group("When it applies", n));
            EndGroups();
            BindNumber(m_pct, () => Sheet, "UnknownPercentile", true); BindNumber(m_year, () => Sheet, "AgeRasterYear", true);
            m_file.Validated += (s, e) => { if (!Refreshing) Write("AgeRasterFile", m_file.Text.Trim().Length == 0 ? (object)DBNull.Value : m_file.Text.Trim()); };
            m_browse.Click += (s, e) =>
            {
                using (var dlg = new OpenFileDialog { Filter = "Rasters (*.tif;*.tiff;*.img;*.vrt)|*.tif;*.tiff;*.img;*.vrt|All files (*.*)|*.*", Title = "Stand age raster" })
                {
                    if (dlg.ShowDialog(this) != DialogResult.OK) return;
                    m_file.Text = dlg.FileName; Write("AgeRasterFile", dlg.FileName); RefreshControls();
                }
            };
            this.ResumeLayout(false);
        }

        private static Control Indent(Control c) { c.Margin = new Padding(22, 0, 3, 8); return c; }
        private static Label Heading(string text) { return new Label { Text = text, AutoSize = true, Font = new System.Drawing.Font(System.Drawing.SystemFonts.DefaultFont, System.Drawing.FontStyle.Bold), Margin = new Padding(3, 10, 3, 0) }; }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            LoadGrid(m_grid, AGES);
            RefreshControls();
        }

        protected override void ShowData()
        {
            ShowChoice(m_agg); ShowChoice(m_unknown);
            m_pct.Text = Show(Value("UnknownPercentile")); m_year.Text = Show(Value("AgeRasterYear"));
            object f = Value("AgeRasterFile"); m_file.Text = f == DBNull.Value ? "" : Convert.ToString(f);
            m_pct.Enabled = IntValue("UnknownRule", 1) == 1;
        }
    }
}
