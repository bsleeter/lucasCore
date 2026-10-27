// =============================================================================
// GrowthOptionsView.cs - the Growth Curve Options page: fit new curves or copy them from another library, then only what applies
// =============================================================================
// Single-row sheet lucasCore_GrowthOptions, unchanged. Copying (src/growth-copy.R) needs the source library and optionally its
// result scenario; fitting (stage 2) uses the FIA data and Fitting groups (FIA data: src/fia.R). The group that does not apply is greyed out.
// =============================================================================
using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using SyncroSim.Core;

namespace lucasCoreUI
{
    public class GrowthOptionsView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_GrowthOptions"; } }

        private readonly Choice m_source = new Choice("CurveSource", 1);
        private readonly Choice m_fia = new Choice("FiaSource", 1), m_dd = new Choice("DownDeadCarbon", 1);
        private FlowLayoutPanel m_ddRow;
        private readonly TextBox m_library = new TextBox { Width = 460, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 6, 3) };
        private readonly Button m_browse = new Button { Text = "Browse...", AutoSize = true, Margin = new Padding(3, 2, 12, 3) };
        private readonly TextBox m_scenario = Box(70);
        private readonly Label m_libState = new Label { AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(3, 4, 3, 3) };
        private readonly TextBox m_lag = Box(70), m_minPlotsLag = Box(70), m_maxLag = Box(70), m_penalty = Box(70), m_minPlotsEco = Box(70), m_maxAge = Box(70), m_minYear = Box(70), m_cap = Box(70);
        private GroupBox m_gCopy, m_gFit, m_gFia;

        public GrowthOptionsView()
        {
            this.SuspendLayout();
            var src = Column();
            var r = Row();
            r.Controls.Add(Option(m_source, 1, "Fit new curves"));
            r.Controls.Add(Option(m_source, 2, "Copy from another library"));
            src.Controls.Add(r);
            src.Controls.Add(Wrapped("Fitting takes about 13 minutes and covers every ecodivision x forest type in CONUS, so one fit can serve many builds. Copying reuses the curves of a library fitted with the same forest type classes.", 640));
            AddGroup(Group("Growth curves", src));

            var copy = Column();
            var lr = Row();
            lr.Controls.Add(Caption("Source library:")); lr.Controls.Add(m_library); lr.Controls.Add(m_browse);
            copy.Controls.Add(lr);
            copy.Controls.Add(m_libState);
            var sr = Row();
            sr.Controls.Add(Caption("Result scenario Id:")); sr.Controls.Add(m_scenario); sr.Controls.Add(Note("Blank = the newest result in that library that has curves."));
            copy.Controls.Add(sr);
            m_gCopy = Group("Copy from", copy);
            AddGroup(m_gCopy);

            var fia = Column();
            var fr = Row();
            fr.Controls.Add(Option(m_fia, 1, "USGS condition tables (.Rds)"));
            fr.Controls.Add(Option(m_fia, 2, "FIA DataMart (state CSVs)"));
            fia.Controls.Add(fr);
            m_ddRow = Row();
            m_ddRow.Controls.Add(Caption("Down dead carbon:"));
            m_ddRow.Controls.Add(Option(m_dd, 1, "Adjusted to field measurements by state"));
            m_ddRow.Controls.Add(Option(m_dd, 2, "As in FIADB (model)"));
            fia.Controls.Add(m_ddRow);
            fia.Controls.Add(Wrapped("The FIA plot conditions the curves, carbon shares and decay calibration are fitted to. The USGS tables are the two .Rds files in Data Sources. FIA DataMart derives the same tables from the state PLOT, COND and TREE csv files in Data Sources: FIA DataMart Folder (all 48 conterminous states for the CONUS-wide curves), cached there after the first read; it reproduces the USGS tables (newer inventories included). FIADB's down dead wood is a model of live tree carbon; the USGS tables scale it by one field/model factor per state, which the default applies too (only the decay calibration uses it).", 640));
            m_gFia = Group("FIA data", fia);
            AddGroup(m_gFia);

            var fit = Form();
            FormRow(fit, "Fixed lag before merchantable volume (yr):", m_lag, "Blank = fitted for each forest type.");
            FormRow(fit, "Minimum plots for a type's own lag:", m_minPlotsLag, "Fewer plots: the type takes its class lag.");
            FormRow(fit, "Maximum fitted lag (yr):", m_maxLag, null);
            FormRow(fit, "Pull toward the type's CONUS curve (lambda):", m_penalty, "0 = no pull.");
            FormRow(fit, "Minimum plots for an ecodivision's own parameters:", m_minPlotsEco, null);
            FormRow(fit, "Maximum age (yr):", m_maxAge, null);
            FormRow(fit, "First FIA inventory year:", m_minYear, null);
            FormRow(fit, "Volume outlier cap (quantile):", m_cap, "Within each forest type group.");
            m_gFit = Group("Fitting settings", fit);
            AddGroup(m_gFit);
            EndGroups();

            m_browse.Click += OnBrowse;
            m_library.TextChanged += (s, e) => ShowLibraryState();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            this.SetTextBoxBinding(m_library, "CurveLibrary");
            this.SetTextBoxBinding(m_scenario, "CurveScenarioId");
            this.SetTextBoxBinding(m_lag, "LagYears");
            this.SetTextBoxBinding(m_minPlotsLag, "MinPlotsLag");
            this.SetTextBoxBinding(m_maxLag, "MaximumLag");
            this.SetTextBoxBinding(m_penalty, "Penalty");
            this.SetTextBoxBinding(m_minPlotsEco, "MinPlotsEcodivision");
            this.SetTextBoxBinding(m_maxAge, "MaximumAge");
            this.SetTextBoxBinding(m_minYear, "MinInventoryYear");
            this.SetTextBoxBinding(m_cap, "VolumeCapQuantile");
            RefreshControls();
        }

        private void OnBrowse(object sender, EventArgs e)
        {
            using (var d = new OpenFileDialog { Filter = "SyncroSim libraries (*.ssim)|*.ssim|All files (*.*)|*.*", Title = "Library with fitted growth curves" })
            {
                string cur = m_library.Text.Trim();
                if (cur.Length > 0 && File.Exists(cur)) d.InitialDirectory = Path.GetDirectoryName(cur);
                if (d.ShowDialog(this) != DialogResult.OK) return;
                Write("CurveLibrary", d.FileName);
                this.RefreshBoundControls();
                RefreshControls();
            }
        }

        private void ShowLibraryState()
        {
            string p = m_library.Text.Trim();
            if (p.Length == 0) { m_libState.Text = "Choose the .ssim library to copy from."; m_libState.ForeColor = SystemColors.GrayText; }
            else if (!File.Exists(p)) { m_libState.Text = "This file was not found."; m_libState.ForeColor = Color.Firebrick; }
            else { m_libState.Text = string.Format("Found ({0:N0} MB). Stage 2 checks it has curves for this library's forest types.", new FileInfo(p).Length / 1048576.0); m_libState.ForeColor = SystemColors.GrayText; }
        }

        protected override void ShowData()
        {
            ShowChoice(m_source);
            bool copying = IntValue("CurveSource", 1) == 2;
            m_gCopy.Enabled = copying;
            m_gFit.Enabled = !copying;
            ShowChoice(m_fia); ShowChoice(m_dd);
            m_gFia.Enabled = !copying; m_ddRow.Enabled = IntValue("FiaSource", 1) == 2;
            ShowLibraryState();
        }
    }
}
