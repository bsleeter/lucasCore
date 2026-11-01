// =============================================================================
// DataDownloadView.cs - the Data Download page (stage 15, to-do 12): which datasets to fetch into Data Sources Home, and how
// =============================================================================
// Single-row sheet lucasCore_DataDownloadOptions. The region is the scenario's Study Area page plus the buffer here. Datasets: one
// tick per Data Sources dataset, named as on the Data Sources page with its size from defaults/download/endpoints.csv; those the
// stage cannot fetch yet (endpoints.csv Fetched = no) are shown greyed with their method. All fetchable ticked writes a blank
// (every one); otherwise the ticked columns, comma separated. The home folder is shown from the project's Data Sources.
// LOCA2: ticks from defaults/download/loca2-catalog.csv (the runs UCSD serves; tools/loca2-catalog.R), written to the same comma
// separated columns. Blank (a new scenario) = one run: the project's first Climate Model UCSD serves (else the catalog's first), ssp245,
// and each model's r1i1p1f1 (else its first). Unticking every model goes back to that one; no scenario ticked = historical only.
// Members: the members the ticked models have; none ticked = each model's r1i1p1f1, else its first.
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
        // LOCA2 catalog rows: model, member, scenario, has the west regional cut
        private class Run { public string Model, Member, Scenario; public bool West; }
        private static readonly string[] SSPS = { "ssp245", "ssp370", "ssp585" };
        private readonly List<Run> m_runs = new List<Run>();
        private readonly Dictionary<string, CheckBox> m_modelBox = new Dictionary<string, CheckBox>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, CheckBox> m_scenBox = new Dictionary<string, CheckBox>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, CheckBox> m_memBox = new Dictionary<string, CheckBox>(StringComparer.OrdinalIgnoreCase);
        private readonly FlowLayoutPanel m_models = Grid(), m_members = Grid();
        private readonly Label m_modelNote = new Label { AutoSize = true, MaximumSize = new Size(680, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 2, 3, 4) };
        private readonly Label m_locaTotal = new Label { AutoSize = true, MaximumSize = new Size(680, 0), Margin = new Padding(3, 6, 3, 3) };
        private readonly Label m_home = new Label { AutoSize = true, Margin = new Padding(3, 7, 3, 3), Font = new Font(SystemFonts.DefaultFont, FontStyle.Bold) };
        private readonly TextBox m_email = new TextBox { Width = 260, Margin = new Padding(3, 3, 6, 3) };
        private readonly Label m_emailNote = new Label { AutoSize = true, Margin = new Padding(3, 7, 3, 3) };
        private readonly TextBox m_token = new TextBox { Width = 260, Margin = new Padding(3, 3, 6, 3), UseSystemPasswordChar = true };
        private readonly Label m_tokenNote = new Label { AutoSize = true, Margin = new Padding(3, 7, 3, 3) };
        private string m_homeDir = "";
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

            AddGroup(Group("LOCA2 climate projections", BuildLoca2()));

            var how = Column(); how.Controls.Add(m_check); how.Controls.Add(m_keep);
            var c = Row(); c.Controls.Add(Caption("Downloads at once:")); c.Controls.Add(m_con); c.Controls.Add(Note("blank = 4")); how.Controls.Add(c);
            var em = Row(); em.Controls.Add(Caption("LANDFIRE email:")); em.Controls.Add(m_email); em.Controls.Add(m_emailNote); how.Controls.Add(em);
            how.Controls.Add(Wrapped("The LANDFIRE Product Service clips the LANDFIRE layers to the region and needs an email address with each job. It is kept in the home folder's settings.csv, not in the scenario, so every download into that folder uses it.", 680));
            var tk = Row(); tk.Controls.Add(Caption("Earthdata token:")); tk.Controls.Add(m_token); tk.Controls.Add(m_tokenNote); how.Controls.Add(tk);
            how.Controls.Add(Wrapped("NASA CMS forest age needs an Earthdata login: sign in at urs.earthdata.nasa.gov, choose Generate Token, and paste it here (tokens last 60 days). It is kept in plain text in the home folder's settings.csv, so anyone who can open that folder can read it; set the EARTHDATA_TOKEN environment variable instead to keep it out of the folder.", 680));
            AddGroup(Group("How", how));
            EndGroups();
            m_email.Validated += (s, a) => { if (!Refreshing) SaveEmail(); };
            m_token.Validated += (s, a) => { if (!Refreshing) SaveSetting("EarthdataToken", m_token.Text.Trim()); };

            BindNumber(m_buffer, () => Sheet, "BufferKm", false); BindNumber(m_from, () => Sheet, "YearFrom", true);
            BindNumber(m_to, () => Sheet, "YearTo", true); BindNumber(m_con, () => Sheet, "Connections", true);
            m_keep.CheckedChanged += (s, a) => { if (!Refreshing) Write("KeepNational", m_keep.Checked); };
            m_check.CheckedChanged += (s, a) => { if (!Refreshing) Write("CheckOnly", m_check.Checked); };
            this.ResumeLayout(false);
        }

        private static FlowLayoutPanel Grid() { return new FlowLayoutPanel { AutoSize = true, WrapContents = true, FlowDirection = FlowDirection.LeftToRight, MaximumSize = new Size(700, 0), Margin = new Padding(14, 0, 0, 0) }; }

        private Control BuildLoca2()
        {
            try
            {
                List<string[]> c = Csv.Read(Path.Combine(LibrarySetup.PackageDirectory(), "defaults", "download", "loca2-catalog.csv"));
                List<string> h = c[0].ToList(); int im = h.IndexOf("Model"), ie = h.IndexOf("Member"), isc = h.IndexOf("Scenario"), iw = h.IndexOf("West");
                foreach (string[] r in c.Skip(1)) if (r.Length > iw) m_runs.Add(new Run { Model = r[im], Member = r[ie], Scenario = r[isc], West = r[iw] == "yes" });
            }
            catch (Exception) { }
            var lc = Column();
            if (m_runs.Count == 0) { lc.Controls.Add(Note("defaults/download/loca2-catalog.csv is missing: run tools/loca2-catalog.R")); return lc; }

            var sr = Row(); sr.Controls.Add(Caption("Scenarios:"));
            foreach (string s in SSPS) { var b = new CheckBox { Text = s, AutoSize = true, Margin = new Padding(3, 6, 8, 3) }; b.CheckedChanged += (o, a) => { if (!Refreshing) WriteScenarios(); }; m_scenBox[s] = b; sr.Controls.Add(b); }
            sr.Controls.Add(Note("the historical run (1950-2014) always comes too")); lc.Controls.Add(sr);

            var mh = Row(); mh.Controls.Add(Caption("Models:"));
            var proj = new Button { Text = "Project's models", AutoSize = true }; var all = new Button { Text = "All models", AutoSize = true };
            mh.Controls.Add(proj); mh.Controls.Add(all); lc.Controls.Add(mh);
            foreach (string m in m_runs.Select(r => r.Model).Distinct().OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
            {
                List<Run> rs = m_runs.Where(r => r.Model == m).ToList(); bool west = rs.Any(r => r.West);
                var b = new CheckBox { Text = m + (west ? "" : " *"), Width = 165, Margin = new Padding(3, 1, 3, 1) };
                m_tip.SetToolTip(b, string.Format("Members: {0}{1}Runs: {2}{3}", string.Join(", ", rs.Select(r => r.Member).Distinct()), Environment.NewLine,
                    string.Join(", ", rs.Select(r => r.Scenario).Distinct().OrderBy(x => x)), west ? "" : Environment.NewLine + "No monthly files in UCSD's west cut: comes as the larger CONUS files"));
                b.CheckedChanged += (o, a) => { if (!Refreshing) WriteModels(); };
                m_modelBox[m] = b; m_models.Controls.Add(b);
            }
            lc.Controls.Add(m_models); lc.Controls.Add(m_modelNote);
            proj.Click += (o, a) => { List<string> p = ProjectModels().Where(m => m_modelBox.ContainsKey(m)).ToList(); Write("Loca2Models", p.Count == 0 ? (object)DBNull.Value : string.Join(", ", p)); RefreshControls(); };
            all.Click += (o, a) => { Write("Loca2Models", string.Join(", ", m_modelBox.Keys)); RefreshControls(); };

            var me = Row(); me.Controls.Add(Caption("Members:")); me.Controls.Add(Note("those the ticked models have; none ticked = each model's r1i1p1f1 (or its first, when it has none)")); lc.Controls.Add(me);
            lc.Controls.Add(m_members); lc.Controls.Add(m_locaTotal);
            return lc;
        }

        private List<string> ProjectModels()
        {
            var r = new List<string>();
            try { DataTable t = this.DataFeed.Project.GetDataSheet("lucasCore_ClimateModel").GetData(); foreach (DataRow d in t.Rows) if (d.RowState != DataRowState.Deleted) r.Add(Show(d["Name"]).Trim()); }
            catch (Exception) { }
            return r.Where(x => x.Length > 0).ToList();
        }

        // the stage's blank: the project's first Climate Model (by name) that UCSD serves, else the catalog's first
        private string DefaultModel()
        {
            string p = ProjectModels().Where(m => m_modelBox.ContainsKey(m)).OrderBy(m => m, StringComparer.Ordinal).FirstOrDefault();
            return p ?? m_modelBox.Keys.OrderBy(m => m, StringComparer.Ordinal).First();
        }

        private static List<string> Split(object v) { return Show(v).Split(',').Select(x => x.Trim()).Where(x => x.Length > 0).ToList(); }

        private void WriteScenarios()
        {
            List<string> t = SSPS.Where(s => m_scenBox[s].Checked).ToList();
            Write("Loca2Scenarios", t.Count == 0 ? "historical" : string.Join(", ", t)); RefreshControls();
        }

        private void WriteModels()
        {
            List<string> t = m_modelBox.Where(kv => kv.Value.Checked).Select(kv => kv.Key).ToList();
            Write("Loca2Models", t.Count == 0 ? (object)DBNull.Value : string.Join(", ", t)); RefreshControls();
        }

        private void WriteMembers()
        {
            List<string> t = m_memBox.Where(kv => kv.Value.Checked && kv.Value.Visible).Select(kv => kv.Key).ToList();
            Write("Loca2Member", t.Count == 0 ? (object)DBNull.Value : string.Join(", ", t)); RefreshControls();
        }

        private void ShowLoca2()
        {
            if (m_runs.Count == 0) return;
            List<string> sc = Split(Value("Loca2Scenarios"));
            foreach (string s in SSPS) m_scenBox[s].Checked = sc.Count == 0 ? s == "ssp245" : sc.Contains(s, StringComparer.OrdinalIgnoreCase);
            List<string> asked = Split(Value("Loca2Models")); bool byDefault = asked.Count == 0;
            List<string> models = byDefault ? new List<string> { DefaultModel() } : asked;
            foreach (var kv in m_modelBox) kv.Value.Checked = models.Contains(kv.Key, StringComparer.OrdinalIgnoreCase);
            List<string> unknown = models.Where(m => !m_modelBox.ContainsKey(m)).ToList();
            m_modelNote.Text = (byDefault ? "One model by default: the project's first Climate Model UCSD serves. Tick more to fetch them; Project's models ticks the project's whole list." : "Your choice. Untick them all to go back to the one default model.")
                + (unknown.Count > 0 ? " Not served by UCSD, skipped: " + string.Join(", ", unknown) + "." : "")
                + " * = no monthly files in UCSD's west cut: those come as the larger CONUS files.";
            m_modelNote.ForeColor = SystemColors.GrayText;

            // members: those the ticked models have, with how many of them have each
            List<string> picked = m_modelBox.Where(kv => kv.Value.Checked).Select(kv => kv.Key).ToList();
            List<Run> mine = m_runs.Where(r => picked.Contains(r.Model)).ToList();
            List<string> wantMem = Split(Value("Loca2Member"));
            m_members.SuspendLayout(); m_members.Controls.Clear();
            foreach (var g in mine.GroupBy(r => r.Member).OrderBy(g => g.Key, StringComparer.Ordinal))
            {
                CheckBox b;
                if (!m_memBox.TryGetValue(g.Key, out b)) { b = new CheckBox { Width = 165, Margin = new Padding(3, 1, 3, 1) }; b.CheckedChanged += (o, a) => { if (!Refreshing) WriteMembers(); }; m_memBox[g.Key] = b; }
                int n = g.Select(r => r.Model).Distinct().Count();
                b.Text = string.Format("{0} ({1} of {2})", g.Key, n, picked.Count); b.Visible = true; b.Checked = wantMem.Contains(g.Key);
                m_tip.SetToolTip(b, string.Join(", ", g.Select(r => r.Model).Distinct()));
                m_members.Controls.Add(b);
            }
            foreach (var kv in m_memBox) if (!m_members.Controls.Contains(kv.Value)) kv.Value.Visible = false;
            m_members.ResumeLayout();

            // the runs the stage will take
            var scen = new HashSet<string>(sc.Count == 0 ? new[] { "ssp245" } : sc.ToArray(), StringComparer.OrdinalIgnoreCase); scen.Add("historical");
            int runs = 0, conus = 0;
            foreach (string m in picked)
            {
                List<string> have = m_runs.Where(r => r.Model == m).Select(r => r.Member).Distinct().ToList();
                List<string> mem = have.Where(x => wantMem.Contains(x)).ToList();
                if (mem.Count == 0) mem.Add(have.Contains("r1i1p1f1") ? "r1i1p1f1" : have[0]);
                foreach (Run r in m_runs.Where(r => r.Model == m && mem.Contains(r.Member) && scen.Contains(r.Scenario))) { runs++; if (!r.West) conus++; }
            }
            m_locaTotal.Text = picked.Count == 0 ? "No LOCA2 runs: tick at least one model." : string.Format("{0} runs ({1} files: pr, tasmax, tasmin){2}. Check only gives the download size.",
                runs, runs * 3, conus > 0 ? string.Format("; in a west region {0} of them come as CONUS files", conus) : "");
            m_locaTotal.ForeColor = picked.Count == 0 ? Color.Firebrick : SystemColors.ControlText;
        }

        private static string Method(string m)
        {
            switch (m) { case "wcs": return "web coverage service"; case "lfps": return "LANDFIRE Product Service"; case "rest": return "ArcGIS REST";
                         case "cog": return "cloud-optimized GeoTIFF"; case "stac": return "Planetary Computer"; case "login": return "needs an Earthdata login"; default: return m; }
        }

        // every fetchable dataset ticked = blank (every one); else the ticked columns
        private void WriteDatasets()
        {
            List<Ds> f = m_ds.Where(d => d.Fetched).ToList();
            bool every = f.All(d => d.Box.Checked);
            Write("Datasets", every ? (object)DBNull.Value : string.Join(", ", m_ds.Where(d => d.Box.Checked).Select(d => d.Column)));
            RefreshControls();
        }

        // <home>/settings.csv: Key,Value rows (src/datahome.R home_setting); the email lives there, not in the scenario
        private string Setting(string key)
        {
            try { string f = Path.Combine(m_homeDir, "settings.csv"); if (m_homeDir.Length == 0 || !File.Exists(f)) return "";
                  foreach (string[] r in Csv.Read(f).Skip(1)) if (r.Length >= 2 && r[0] == key) return r[1]; }
            catch (Exception) { }
            return "";
        }

        private void SaveEmail()
        {
            string v = m_email.Text.Trim();
            if (v.Length > 0 && !v.Contains("@")) { MessageBox.Show("That does not look like an email address.", "LANDFIRE email", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
            SaveSetting("LfpsEmail", v);
        }

        // a blank value removes the key; other keys are kept
        private void SaveSetting(string key, string value)
        {
            if (m_homeDir.Length == 0) return;
            try
            {
                string f = Path.Combine(m_homeDir, "settings.csv");
                var rows = File.Exists(f) ? Csv.Read(f).Skip(1).Where(r => r.Length >= 2 && r[0] != key).Select(r => r[0] + "," + r[1]).ToList() : new List<string>();
                if (value.Length > 0) rows.Add(key + "," + value);
                Directory.CreateDirectory(m_homeDir); File.WriteAllLines(f, new[] { "Key,Value" }.Concat(rows));
            }
            catch (Exception ex) { MessageBox.Show("Could not save " + key + " in the home folder: " + ex.Message, "Data Download", MessageBoxButtons.OK, MessageBoxIcon.Warning); }
            RefreshControls();
        }

        protected override void ShowData()
        {
            string home = "";
            try { DataSheet src = this.DataFeed.Project.GetDataSheet("lucasCore_DataSource"); if (src.HasData() && src.GetData().Columns.Contains("DataSourcesHome")) home = Show(src.GetDataRow()["DataSourcesHome"]).Trim(); }
            catch (Exception) { }
            m_home.Text = home.Length > 0 ? home : "not set: set it on the Data Sources page (project)";
            m_home.ForeColor = home.Length > 0 ? SystemColors.ControlText : Color.Firebrick;
            m_homeDir = home; m_email.Enabled = home.Length > 0; m_email.Text = Setting("LfpsEmail");
            m_token.Enabled = home.Length > 0; m_token.Text = Setting("EarthdataToken");
            m_buffer.Text = Show(Value("BufferKm")); m_from.Text = Show(Value("YearFrom")); m_to.Text = Show(Value("YearTo")); m_con.Text = Show(Value("Connections"));
            object k = Value("KeepNational"); m_keep.Checked = k != DBNull.Value && Convert.ToBoolean(k);
            object c = Value("CheckOnly"); m_check.Checked = c != DBNull.Value && Convert.ToBoolean(c);
            ShowLoca2();
            string ds = Show(Value("Datasets")).Trim();
            var picked = new HashSet<string>(ds.Split(',').Select(x => x.Trim()).Where(x => x.Length > 0), StringComparer.OrdinalIgnoreCase);
            foreach (Ds d in m_ds) d.Box.Checked = d.Fetched && (ds.Length == 0 || picked.Contains(d.Column));
            double gb = m_ds.Where(d => d.Box.Checked).Sum(d => d.SizeGb);
            m_total.Text = string.Format("{0} datasets ticked, about {1:0.#} GB as national files (much less once clipped)", m_ds.Count(d => d.Box.Checked), gb);
            bool lf = m_ds.Any(d => d.Box.Checked && d.Method == "lfps"), hasEmail = m_email.Text.Contains("@");
            m_emailNote.Text = home.Length == 0 ? "set Data Sources Home first" : hasEmail ? "" : lf ? "needed: LANDFIRE layers are ticked" : "needed only for the LANDFIRE layers";
            m_emailNote.ForeColor = lf && !hasEmail ? Color.Firebrick : SystemColors.GrayText;
            bool age = m_ds.Any(d => d.Box.Checked && d.Method == "login"), envTok = (Environment.GetEnvironmentVariable("EARTHDATA_TOKEN") ?? "").Length > 0;
            m_tokenNote.Text = envTok ? "EARTHDATA_TOKEN is set: it is used first" : m_token.Text.Length > 0 ? "" : age ? "needed: NASA CMS forest age is ticked" : "needed only for NASA CMS forest age";
            m_tokenNote.ForeColor = age && !envTok && m_token.Text.Length == 0 ? Color.Firebrick : SystemColors.GrayText;
        }
    }
}
