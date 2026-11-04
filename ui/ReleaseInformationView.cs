// =============================================================================
// ReleaseInformationView.cs - the Release Information page (stage 17): what only a person can supply for a data release
// =============================================================================
// Single-row sheet lucasCore_ReleaseInformation and multi-row lucasCore_ReleaseOriginator, both on this page, on the Data Release scenario. People
// come from the project's People list (lucasCore_Person), so a release picks them rather than retyping them. A blank field takes the stage's
// drafted text or the package default and is listed as still to supply. Release status: a Draft lists what is missing and runs on; Provisional and
// Approved stop the stage on it. src/release.R rl_read_info reads this page, by the same column names.
// Each note sits under its control: beside a wide control the frame cuts it off (see DataReleaseView).
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
    public class ReleaseInformationView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_ReleaseInformation"; } }
        private DataSheet OriginatorSheet { get { return this.DataFeed.GetDataSheet("lucasCore_ReleaseOriginator"); } }

        private class PersonItem { public int Id; public string Name; public override string ToString() { return Name; } }

        private readonly Choice m_status = new Choice("ReleaseStatus", 1);
        private readonly Dictionary<string, TextBox> m_texts = new Dictionary<string, TextBox>();
        private readonly Label m_toSupply = new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(3, 6, 3, 3) };
        private readonly TableLayoutPanel m_table = new TableLayoutPanel { AutoSize = true, ColumnCount = 2, Margin = new Padding(0, 3, 0, 3) };
        private readonly Button m_add = new Button { Text = "Add an originator", AutoSize = true, Margin = new Padding(3, 3, 3, 3) };
        private readonly Label m_noPeople = new Label { AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Margin = new Padding(3, 3, 3, 6) };
        private readonly ComboBox m_contact = List(320);
        private readonly ToolTip m_tip = new ToolTip();
        private List<PersonItem> m_people = new List<PersonItem>();
        private string m_shown = null;   // the row ids the table was built for

        private const int Wide = 560;

        private static Label Cap(string text) { var l = Caption(text); l.AutoSize = false; l.Width = 124; l.Height = 24; return l; }
        private static Label Under(string text) { var l = Note(text); l.Margin = new Padding(130, 0, 3, 10); return l; }

        private TextBox Entry(string column, int width, int lines)
        {
            var t = new TextBox { Width = width, Margin = new Padding(3, 3, 3, 3) };
            if (lines > 1) { t.Multiline = true; t.ScrollBars = ScrollBars.Vertical; t.Height = 16 * lines + 8; t.AcceptsReturn = false; }
            m_texts[column] = t;
            t.Validated += (s, e) => { if (Refreshing) return; string v = t.Text.Trim(); Write(column, v.Length == 0 ? (object)DBNull.Value : v); RefreshControls(); };
            return t;
        }

        // caption and control on a line, its note under them
        private static void Field(FlowLayoutPanel c, string caption, Control control, string note)
        {
            var r = Row(); r.Controls.Add(Cap(caption)); r.Controls.Add(control); c.Controls.Add(r);
            if (note != null) c.Controls.Add(Under(note));
        }

        public ReleaseInformationView()
        {
            this.SuspendLayout();
            var st = Column();
            var radios = Row();
            radios.Controls.Add(Option(m_status, 1, "Draft")); radios.Controls.Add(Option(m_status, 2, "Provisional")); radios.Controls.Add(Option(m_status, 3, "Approved"));
            st.Controls.Add(radios);
            st.Controls.Add(Note("Draft: the folder is written and what is missing is listed, so a blank never stops you. Provisional and Approved: the stage fails while anything below is missing. Approved takes the USGS approved-data statement; the others take the provisional one."));
            st.Controls.Add(m_toSupply);
            AddGroup(Group("Release status", st));

            var w = Column();
            Field(w, "Title", Entry("Title", Wide, 2), "Blank = drafted from the study area and years.");
            Field(w, "Abstract", Entry("Abstract", Wide, 6), "Blank = drafted from the runs. Say what the release holds and how it was made. Metadata does not interpret results.");
            Field(w, "Purpose", Entry("Purpose", Wide, 3), "Blank = a drafted sentence. These three are for the whole release; each run's record keeps its own factual wording.");
            AddGroup(Group("Wording", w));

            var p = Column();
            p.Controls.Add(Note("Originators, in citation order: to move someone down, remove and add them again. People come from the project's People list (Project > LUCAS Core > People)."));
            for (int k = 0; k < 2; k++) m_table.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            p.Controls.Add(m_table);
            var ar = Row(); ar.Controls.Add(m_add); p.Controls.Add(ar);
            p.Controls.Add(m_noPeople);
            Field(p, "Point of contact", m_contact, "Every record names this person. CSDGM requires an address, phone and email, so fill them in on the People list.");
            Field(p, "Contact email", Entry("ContactEmail", 320, 1), "A shared group address, which SM 502.7 asks for so the contact outlives staff changes. Blank = the person's email.");
            AddGroup(Group("People", p));

            var u = Column();
            Field(u, "Publisher", Entry("Publisher", 320, 1), "Blank = U.S. Geological Survey.");
            Field(u, "Publication place", Entry("PubPlace", 320, 1), "Blank = Reston, VA.");
            Field(u, "Publication date", Entry("PubDate", 120, 1), "YYYYMMDD. Blank = the day the stage runs.");
            Field(u, "Version", Entry("Version", 120, 1), "Blank = 1.0.");
            Field(u, "Revision notes", Entry("RevisionNotes", Wide, 2), "What changed from the last version, if any.");
            AddGroup(Group("Publication", u));

            var d = Column();
            Field(d, "Data DOI", Entry("Doi", Wide, 1), "The full https://doi.org/ address, reserved through the USGS Science Data Portal.");
            Field(d, "Landing page", Entry("LandingPage", Wide, 1), "Optional: the release's page, if it is not what the DOI resolves to.");
            Field(d, "Metadata identifier", Entry("MetadataId", 320, 1), "Optional: in a ScienceBase release the Data Release team assigns it during publication. If you have one, it goes on the parent record only.");
            Field(d, "IPDS number", Entry("IpdsNumber", 320, 1), "Required before a final release. It stays out of the published records.");
            Field(d, "Methods citation", Entry("MethodsCitation", Wide, 3), "The peer-reviewed product that describes the methods, which SM 502.8 requires for derived data.");
            Field(d, "Associated publications", Entry("AssociatedPublications", Wide, 2), "Optional.");
            AddGroup(Group("Identifiers and citations", d));

            var k2 = Column();
            k2.Controls.Add(Note("The USGS Thesaurus terms and the study area's places go in by themselves. Add any others here, separated by ;"));
            Field(k2, "More theme", Entry("ThemeKeywords", Wide, 1), null);
            Field(k2, "More place", Entry("PlaceKeywords", Wide, 1), null);
            AddGroup(Group("Keywords", k2));
            EndGroups();

            m_add.Click += (s, e) => AddOriginator();
            m_contact.DropDown += (s, e) => { ReadPeople(); FillContact(); };
            m_contact.SelectionChangeCommitted += (s, e) =>
            {
                if (Refreshing) return;
                var it = m_contact.SelectedItem as PersonItem;
                Write("ContactPersonId", it == null || it.Id < 0 ? (object)DBNull.Value : it.Id); RefreshControls();
            };
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            ReadPeople();
            RefreshControls();
        }

        private void ReadPeople()
        {
            m_people = new List<PersonItem>();
            try
            {
                foreach (DataRow r in this.DataFeed.Project.GetDataSheet("lucasCore_Person").GetData().Rows)
                    if (r.RowState != DataRowState.Deleted && r["PersonId"] != DBNull.Value)
                        m_people.Add(new PersonItem { Id = Convert.ToInt32(r["PersonId"]), Name = Convert.ToString(r["Name"]) });
            }
            catch (Exception) { }
        }

        private DataRow Person(object id)
        {
            if (id == DBNull.Value || id == null) return null;
            try { foreach (DataRow r in this.DataFeed.Project.GetDataSheet("lucasCore_Person").GetData().Rows)
                      if (r.RowState != DataRowState.Deleted && r["PersonId"] != DBNull.Value && Convert.ToInt32(r["PersonId"]) == Convert.ToInt32(id)) return r; }
            catch (Exception) { }
            return null;
        }

        private List<DataRow> Rows() { return OriginatorSheet == null ? new List<DataRow>() : OriginatorSheet.GetData().Rows.Cast<DataRow>().Where(r => r.RowState != DataRowState.Deleted).OrderBy(Order).ToList(); }
        // the citation order is a column, because SyncroSim does not keep rows in the order they were added
        private static int Order(DataRow r) { return r["SortOrder"] == DBNull.Value ? int.MaxValue : Convert.ToInt32(r["SortOrder"]); }
        private static int Pid(DataRow r) { return r["PersonId"] == DBNull.Value ? -1 : Convert.ToInt32(r["PersonId"]); }

        private void AddOriginator()
        {
            ReadPeople();
            List<DataRow> now = Rows(); HashSet<int> have = new HashSet<int>(now.Select(Pid));
            int order = now.Count == 0 ? 1 : now.Where(r => r["SortOrder"] != DBNull.Value).Select(Order).DefaultIfEmpty(now.Count).Max() + 1;
            PersonItem next = m_people.FirstOrDefault(i => !have.Contains(i.Id));
            if (next == null) return;
            DataSheet ds = OriginatorSheet; if (ds == null) { m_noPeople.Text = "This page cannot reach the Release Originators sheet."; return; } DataTable dt = ds.GetData();
            ds.BeginAddRows(); DataRow nr = dt.NewRow(); nr["PersonId"] = next.Id; nr["SortOrder"] = order; dt.Rows.Add(nr); ds.EndAddRows();
            m_shown = null; RefreshControls();
        }

        private void Build(List<DataRow> rows)
        {
            m_table.SuspendLayout();
            m_table.Controls.Clear(); m_table.RowStyles.Clear(); m_table.RowCount = 0;
            foreach (DataRow row in rows)
            {
                DataRow rw = row; int i = m_table.RowCount;
                m_table.RowCount = i + 1; m_table.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                var rm = new Button { Text = "✕", Width = 26, Height = 24, FlatStyle = FlatStyle.Flat, ForeColor = Color.Firebrick, Margin = new Padding(3, 3, 3, 3) };
                m_tip.SetToolTip(rm, "Remove this originator from the release");
                rm.Click += (s, e) => { OriginatorSheet.DeleteRows(new[] { rw }); m_shown = null; RefreshControls(); };
                var who = List(320);
                who.DropDown += (s, e) => { ReadPeople(); FillOne(who, Pid(rw)); };
                who.SelectionChangeCommitted += (s, e) =>
                {
                    var it = who.SelectedItem as PersonItem; if (it == null) return;
                    OriginatorSheet.BeginModifyRows(); rw["PersonId"] = it.Id; OriginatorSheet.EndModifyRows(); RefreshControls();
                };
                m_table.Controls.Add(rm, 0, i); m_table.Controls.Add(who, 1, i);
            }
            m_table.ResumeLayout(true);
        }

        private void FillOne(ComboBox cb, int id)
        {
            cb.BeginUpdate(); cb.Items.Clear(); int idx = -1;
            foreach (PersonItem p in m_people) { int at = cb.Items.Add(p); if (p.Id == id) idx = at; }
            cb.SelectedIndex = idx; cb.EndUpdate();
        }

        private void FillContact()
        {
            object v = Value("ContactPersonId"); int id = v == DBNull.Value ? -1 : Convert.ToInt32(v);
            m_contact.BeginUpdate(); m_contact.Items.Clear(); m_contact.Items.Add(new PersonItem { Id = -1, Name = "(choose a person)" }); int idx = 0;
            foreach (PersonItem p in m_people) { int at = m_contact.Items.Add(p); if (p.Id == id) idx = at; }
            m_contact.SelectedIndex = idx; m_contact.EndUpdate();
        }

        // what the stage will list as still to supply, by the same rules as src/release.R rl_to_supply and record-defaults.csv
        private string Missing(List<DataRow> rows)
        {
            var m = new List<string>();
            Action<string, string> need = (col, name) => { if (Show(Value(col)).Trim().Length == 0) m.Add(name); };
            need("Title", "title"); need("Abstract", "abstract"); need("Purpose", "purpose");
            if (rows.Count == 0) m.Add("originators");
            DataRow c = Person(Value("ContactPersonId"));
            if (c == null) m.Add("point of contact");
            else
            {
                foreach (string[] f in new[] { new[] { "Address", "contact address" }, new[] { "City", "contact city" }, new[] { "State", "contact state" }, new[] { "PostalCode", "contact postal code" }, new[] { "Phone", "contact phone" } })
                    if (Show(c[f[0]]).Trim().Length == 0) m.Add(f[1]);
                if (Show(Value("ContactEmail")).Trim().Length == 0 && Show(c["Email"]).Trim().Length == 0) m.Add("contact email");
            }
            need("Doi", "DOI"); need("IpdsNumber", "IPDS number"); need("MethodsCitation", "methods citation");
            return string.Join(", ", m);
        }

        protected override void ShowData()
        {
            ShowChoice(m_status);
            foreach (KeyValuePair<string, TextBox> t in m_texts) if (!t.Value.Focused) t.Value.Text = Show(Value(t.Key));
            ReadPeople(); FillContact();
            List<DataRow> rows = Rows();
            string ids = string.Join(",", rows.Select(r => r.GetHashCode().ToString()));
            if (ids != m_shown) { Build(rows); m_shown = ids; }
            for (int i = 0; i < rows.Count; i++) FillOne((ComboBox)m_table.GetControlFromPosition(1, i), Pid(rows[i]));
            HashSet<int> chosen = new HashSet<int>(rows.Select(Pid));
            m_add.Enabled = m_people.Any(i => !chosen.Contains(i.Id));
            m_noPeople.Text = m_people.Count == 0 ? "The People list is empty: add people there first (Project > LUCAS Core > People)." : "";
            string miss = Missing(rows);
            m_toSupply.Text = miss.Length == 0 ? "Nothing is missing." : "Still to supply: " + miss + ".";
            m_toSupply.ForeColor = miss.Length == 0 ? Color.ForestGreen : Color.Firebrick;
        }
    }

    // The People page of the project: the people a data release can name
    public class PeopleView : LucasView
    {
        protected override string SheetName { get { return "lucasCore_Person"; } }
        private readonly Panel m_grid = GridHost(340);
        private bool m_loaded;

        public PeopleView()
        {
            this.SuspendLayout();
            AddGroup(Group("Who this list is for", Note("The people a data release can name as originators or its point of contact, on the Release Information page. Write the name as it is cited (Sleeter, B.M.). A point of contact needs an address, phone and email, because FGDC metadata requires them in every contact.")));
            AddGroup(Group("People", m_grid));
            EndGroups();
            this.ResumeLayout(false);
        }

        public override void LoadDataFeed(DataFeed dataFeed)
        {
            base.LoadDataFeed(dataFeed);
            if (!m_loaded) { LoadGrid(m_grid, SheetName); m_loaded = true; }
            RefreshControls();
        }

        protected override void ShowData() { }
    }
}
