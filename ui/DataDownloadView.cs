// =============================================================================
// DataDownloadView.cs - the Data Download page (stage 15, to-do 12): which datasets to fetch into Data Sources Home, and how
// =============================================================================
// Single-row sheet lucasCore_DataDownloadOptions. The region is the scenario's Study Area page plus the buffer here. Datasets: one
// tick per Data Sources dataset, named as on the Data Sources page with its size from defaults/download/endpoints.csv; those the
// stage cannot fetch yet (endpoints.csv Fetched = no) are shown greyed with their method. All fetchable ticked writes a blank
// (every one); otherwise the ticked columns, comma separated. The home folder is shown from the project's Data Sources.
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
    public class DataDownloadView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_DataDownloadOptions"; } }

        private class Ds { public string Column, Name, Category, Method, Login, Note; public double SizeGb; public bool Fetched; public CheckBox Box; }
        private readonly List<Ds> m_ds = new List<Ds>();
        private readonly TextBox m_buffer = Box(60), m_from = Box(60), m_to = Box(60), m_con = Box(40);
        private readonly CheckBox m_keep = new CheckBox { Text = "Keep national copies (else each whole file is clipped to the region after download)", AutoSize = true, Margin = new Padding(3, 5, 3, 3) };
        private readonly CheckBox m_check = new CheckBox { Text = "Check only: list what would download, and how big, without fetching anything", AutoSize = true, Margin = new Padding(3, 5, 3, 3) };
        private readonly TextBox m_models = new TextBox { Width = 420, Margin = new Padding(3, 3, 6, 3) }, m_scen = new TextBox { Width = 260, Margin = new Padding(3, 3, 6, 3) }, m_member = new TextBox { Width = 120, Margin = new Padding(3, 3, 6, 3) };
        private readonly Label m_home = new Label { AutoSize = true, Margin = new Padding(3, 7, 3, 3), Font = new Font(SystemFonts.DefaultFont, FontStyle.Bold) };
        private readonly Label m_total = new Label { AutoSize = true, Margin = new Padding(3, 6, 3, 3), ForeColor = SystemColors.GrayText };
        private readonly ToolTip m_tip = new ToolTip { AutoPopDelay = 20000 };
        private bool m_built;

        public DataDownloadView() { }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            if (!m_built) { BuildPage(); m_built = true; }
            RefreshControls();
        }

        private void BuildPage()
        {
            this.SuspendLayout();
            var where = Column();
            var hr = Row(); hr.Controls.Add(Caption("Into Data Sources Home:")); hr.Controls.Add(m_home); where.Controls.Add(hr);
            var br = Row(); br.Controls.Add(Caption("Buffer around the study area (km):")); br.Controls.Add(m_buffer); br.Controls.Add(Note("blank = 10")); where.Controls.Add(br);
            where.Controls.Add(Wrapped("The region is this scenario's Study Area page (blank = all of CONUS, national copies) plus the buffer. One download serves every Build whose study area it holds; a rerun fetches only what the home folder's manifest does not yet show as done, and resumes partial files.", 680));
            AddGroup(Group("Region", where));

            // the datasets, grouped as on the Data Sources page
            var meta = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            var ep = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            List<string> epHead = new List<string>();
            try
            {
                foreach (string[] r in Csv.Read(Path.Combine(LibrarySetup.PackageDirectory(), "defaults", "library", "data-sources.csv")).Skip(1)) if (r.Length >= 5) meta[r[0]] = r;
                List<string[]> e = Csv.Read(Path.Combine(LibrarySetup.PackageDirectory(), "defaults", "download", "endpoints.csv"));
                epHead = e[0].ToList(); foreach (string[] r in e.Skip(1)) ep[r[0]] = r;
            }
            catch (Exception) { }
            Func<string[], string, string> col = (r, k) => { int i = epHead.IndexOf(k); return r != null && i >= 0 && i < r.Length ? r[i] : ""; };
            foreach (var kv in meta)
            {
                string[] e; ep.TryGetValue(kv.Key, out e); double gb;
                double.TryParse(col(e, "SizeGb"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out gb);
                m_ds.Add(new Ds { Column = kv.Key, Name = kv.Value[4], Category = kv.Value[1], Method = col(e, "Method"), Login = col(e, "Login"), Note = col(e, "Note"),
                                  SizeGb = gb, Fetched = string.Equals(col(e, "Fetched"), "yes", StringComparison.OrdinalIgnoreCase) });
            }
            var list = Column();
            var quick = Row();
            var all = new Button { Text = "Tick all", AutoSize = true }; var none = new Button { Text = "Clear", AutoSize = true };
            quick.Controls.Add(all); quick.Controls.Add(none); quick.Controls.Add(m_total); list.Controls.Add(quick);
            foreach (string cat in m_ds.Select(d => d.Category).Distinct().ToList())
            {
                list.Controls.Add(new Label { Text = cat, AutoSize = true, Font = new Font(this.Font, FontStyle.Bold), Margin = new Padding(3, 8, 3, 2) });
                foreach (Ds d in m_ds.Where(x => x.Category == cat))
                {
                    string size = d.SizeGb <= 0 ? "region only" : d.SizeGb < 1 ? string.Format("{0:0} MB", d.SizeGb * 1000) : string.Format("{0:0.#} GB", d.SizeGb);
                    string why = d.Fetched ? "" : d.Method == "manual" ? " - no public source: supply it yourself" : d.Method == "package" ? " - ships with lucasCore" : string.Format(" - {0}: in a later version", Method(d.Method));
                    d.Box = new CheckBox { Text = string.Format("{0} ({1}){2}", d.Name, size, why), AutoSize = true, Enabled = d.Fetched, Margin = new Padding(18, 2, 3, 2) };
                    m_tip.SetToolTip(d.Box, d.Column + (d.Note.Length > 0 ? Environment.NewLine + d.Note : "") + (d.Login.Length > 0 && d.Login != "none" ? Environment.NewLine + "Login: " + d.Login : ""));
                    Ds dd = d; d.Box.CheckedChanged += (s, a) => { if (!Refreshing) WriteDatasets(); };
                    list.Controls.Add(d.Box);
                }
            }
            all.Click += (s, a) => { Refreshing = true; foreach (Ds d in m_ds.Where(x => x.Fetched)) d.Box.Checked = true; Refreshing = false; WriteDatasets(); };
            none.Click += (s, a) => { Refreshing = true; foreach (Ds d in m_ds) d.Box.Checked = false; Refreshing = false; WriteDatasets(); };
            AddGroup(Group("Datasets", list));

            var yr = Column();
            var y = Row(); y.Controls.Add(Caption("Years:")); y.Controls.Add(m_from); y.Controls.Add(Caption("to")); y.Controls.Add(m_to);
            y.Controls.Add(Note("the annual datasets (MTBS, LCMS, PRISM); blank = 1985 to the latest each source has")); yr.Controls.Add(y);
            AddGroup(Group("Years", yr));

            var lc = Column();
            var m1 = Row(); m1.Controls.Add(Caption("Models:")); m1.Controls.Add(m_models); lc.Controls.Add(m1);
            var m2 = Row(); m2.Controls.Add(Caption("Scenarios:")); m2.Controls.Add(m_scen); m2.Controls.Add(Caption("Member:")); m2.Controls.Add(m_member); lc.Controls.Add(m2);
            lc.Controls.Add(Wrapped("Comma separated. Blank models = the project's Climate Model list; blank scenarios = ssp245, ssp370, ssp585; blank member = r1i1p1f1. The historical run of each model comes too.", 680));
            AddGroup(Group("LOCA2 climate projections", lc));

            var how = Column(); how.Controls.Add(m_check); how.Controls.Add(m_keep);
            var c = Row(); c.Controls.Add(Caption("Downloads at once:")); c.Controls.Add(m_con); c.Controls.Add(Note("blank = 4")); how.Controls.Add(c);
            AddGroup(Group("How", how));
            EndGroups();

            BindNumber(m_buffer, () => Sheet, "BufferKm", false); BindNumber(m_from, () => Sheet, "YearFrom", true);
            BindNumber(m_to, () => Sheet, "YearTo", true); BindNumber(m_con, () => Sheet, "Connections", true);
            m_keep.CheckedChanged += (s, a) => { if (!Refreshing) Write("KeepNational", m_keep.Checked); };
            m_check.CheckedChanged += (s, a) => { if (!Refreshing) Write("CheckOnly", m_check.Checked); };
            BindText(m_models, "Loca2Models"); BindText(m_scen, "Loca2Scenarios"); BindText(m_member, "Loca2Member");
            this.ResumeLayout(false);
        }

        private static string Method(string m)
        {
            switch (m) { case "wcs": return "web coverage service"; case "lfps": return "LANDFIRE Product Service"; case "rest": return "ArcGIS REST";
                         case "cog": return "cloud-optimized GeoTIFF"; case "stac": return "Planetary Computer"; case "login": return "needs an Earthdata login"; default: return m; }
        }

        private void BindText(TextBox t, string column)
        {
            t.Validated += (s, a) => { if (Refreshing) return; string v = t.Text.Trim(); Write(column, v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); };
        }

        // every fetchable dataset ticked = blank (every one); else the ticked columns
        private void WriteDatasets()
        {
            List<Ds> f = m_ds.Where(d => d.Fetched).ToList();
            bool every = f.All(d => d.Box.Checked);
            Write("Datasets", every ? (object)DBNull.Value : string.Join(", ", m_ds.Where(d => d.Box.Checked).Select(d => d.Column)));
            RefreshControls();
        }

        protected override void ShowData()
        {
            string home = "";
            try { DataSheet src = this.DataFeed.Project.GetDataSheet("lucasCore_DataSource"); if (src.HasData() && src.GetData().Columns.Contains("DataSourcesHome")) home = Show(src.GetDataRow()["DataSourcesHome"]).Trim(); }
            catch (Exception) { }
            m_home.Text = home.Length > 0 ? home : "not set: set it on the Data Sources page (project)";
            m_home.ForeColor = home.Length > 0 ? SystemColors.ControlText : Color.Firebrick;
            m_buffer.Text = Show(Value("BufferKm")); m_from.Text = Show(Value("YearFrom")); m_to.Text = Show(Value("YearTo")); m_con.Text = Show(Value("Connections"));
            object k = Value("KeepNational"); m_keep.Checked = k != DBNull.Value && Convert.ToBoolean(k);
            object c = Value("CheckOnly"); m_check.Checked = c != DBNull.Value && Convert.ToBoolean(c);
            m_models.Text = Show(Value("Loca2Models")); m_scen.Text = Show(Value("Loca2Scenarios")); m_member.Text = Show(Value("Loca2Member"));
            string ds = Show(Value("Datasets")).Trim();
            var picked = new HashSet<string>(ds.Split(',').Select(x => x.Trim()).Where(x => x.Length > 0), StringComparer.OrdinalIgnoreCase);
            foreach (Ds d in m_ds) d.Box.Checked = d.Fetched && (ds.Length == 0 || picked.Contains(d.Column));
            double gb = m_ds.Where(d => d.Box.Checked).Sum(d => d.SizeGb);
            m_total.Text = string.Format("{0} datasets ticked, about {1:0.#} GB as national files (much less once clipped)", m_ds.Count(d => d.Box.Checked), gb);
        }
    }
}
