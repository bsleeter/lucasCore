// =============================================================================
// TransitionWalk.cs - the per-group walkthrough of Projection Transitions and Projection Allocation, shared by three pages
// =============================================================================
// User 2026-11-14: the Transitions page "with a more similar look and feel to the other custom UI pages", then split by what drives
// the change: Land Use (urbanization, intensification, agriculture, forest harvest; ProjectionTransitionsView), Fire (FireOptionsView)
// and Natural Change (reforestation now, insects and drought later; NaturalChangeView). The rows stay in the same two sheets, so
// nothing changes for the stages: each page shows only its families. Each group: how much (method, by strata level or rate units),
// the shared draw, protected land it may not reach, and where each of its types goes; a choice is written straight into its row.
// The Land Use page owns the two sheets (their feed); the other pages edit the scenario's own rows of them, and when the scenario has
// none (a dependency supplies the feed) show the dependency's rows read-only.
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
    internal class TransitionWalk
    {
        public const string TRANSITIONS = "lucasCore_ProjectionTransition", ALLOCATION = "lucasCore_ProjectionAllocation";
        private const int TRUE = -1;   // SyncroSim stores a ticked Boolean as -1

        // ---- families: 0 land use, 1 forest harvest, 2 fire, 3 reforestation, 4 other ----------------------------------------
        public static readonly int LAND_USE = 0, HARVEST = 1, FIRE = 2, REFOREST = 3, OTHER = 4;
        public readonly string[] Title = { "Land use", "Forest harvest", "Fire", "Reforestation", "Other transitions" };
        public readonly string[] FamilyNote = {
            "Development and agriculture.",
            "Reshaped by the Forest Management page.",
            "Spread and severity: the Fire page.",
            "Non-forest land becoming forest.",
            "Groups and placement rows outside the families above." };
        public string FireWhere = "The Fire page.";
        // drought and insect mortality (2.0.3 gave it a row of Projection Transitions; from 2.0.4 the projection's Mortality page is its only control)
        public static bool IsMortality(string g) { return g != null && g.StartsWith("Mortality"); }
        // the rows of that group a 2.0.3 page added to the sheet: removed, so the tables do not list a setting that does nothing
        public static int DropMortality(DataSheet tr)
        {
            if (tr == null) return 0; List<KeyValuePair<object, string>> tg = Choices(tr, "TransitionGroupId");
            List<DataRow> old = Rows(tr).Where(r => IsMortality(NameOf(tg, r["TransitionGroupId"]))).ToList();
            if (old.Count > 0) tr.DeleteRows(old); return old.Count;
        }
        public static int FamilyOf(string g)
        {
            if (g.StartsWith("Urbanization") || g.StartsWith("Intensification") || g.StartsWith("Ag ")) return 0;
            if (g.StartsWith("Forest Harvest")) return 1;
            if (g.StartsWith("Fire")) return 2;
            if (g.StartsWith("Reforestation")) return 3;
            return 4;
        }
        // adjacency to developed land (or agriculture) applies to land use only
        private static bool LandUse(string name) { return FamilyOf(name) == 0; }

        private class Block
        {
            public string Key, Name; public int Family;
            public ComboBox Method, Strata, Units, Set; public readonly CheckBox[] Gap = new CheckBox[3];
            public Label ByStrata, ByUnits, MethodNote; public Card Card;
            public readonly List<Place> Places = new List<Place>();
        }
        private class Place { public string Key, Name; public ComboBox Method, Size; public TextBox Surface; public CheckBox Adj; public Label Note; }

        // a card (Land Use Change page): the groups whose names start with one of Prefixes, under the page's own Head (how much), with
        // their walkthrough folded behind "Where and how" (closed: one sentence per group). Groups of no card go by family, as before
        public class Card
        {
            public string Title; public string[] Prefixes; public Control Head;
            internal FlowLayoutPanel Body; internal Label Summary; internal Button Toggle; internal bool Shown;
            internal bool Has(string g) { return Prefixes.Any(x => g.StartsWith(x)); }
        }
        public List<Card> Cards;
        private readonly HashSet<string> m_open = new HashSet<string>();

        private static readonly string[] METHOD = { "Target area", "Rate map", "Off" };
        private static readonly string[] METHOD_NOTE = { "The drawn year's area, per unit.", "The drawn year's rate, per unit.", "No change after the historical end." };
        private static readonly string[] PLACE = { "Fitted surface", "Rules (WUI, GAP)", "Random", "Adjacency only" };
        private static readonly string[] PLACE_NOTE = { "Spatial Allocation page", "WUI and GAP weights", "Within its units", "Neighbors' share of the new class" };
        private static readonly string[] SIZE = { "Auto", "On", "Off" };
        private const string OWN = "(its own draw)";

        private readonly int[] m_families;
        private readonly Func<DataSheet> m_tr, m_al;
        private readonly Func<bool> m_refreshing;
        private readonly Action m_refresh;
        public readonly TableLayoutPanel Host = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Dock = DockStyle.Top, Margin = new Padding(0) };
        public readonly ManagementActionsView.ModelStrata Ms = new ManagementActionsView.ModelStrata();
        public bool Editable = true;
        private readonly List<Block> m_blocks = new List<Block>();
        private readonly List<Place> m_loose = new List<Place>();
        private string m_shape;

        // families: the ones this page shows; tr, al: the two sheets (the scenario's own, or a dependency's); refreshing: the page's
        // Refreshing flag (events are ignored while it shows data); refresh: the page's RefreshControls
        public TransitionWalk(int[] families, Func<DataSheet> tr, Func<DataSheet> al, Func<bool> refreshing, Action refresh)
        {
            m_families = families; m_tr = tr; m_al = al; m_refreshing = refreshing; m_refresh = refresh;
            Host.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        }
        public void Rebuild() { m_shape = null; }

        // the scenario's own sheet when it has rows, else the first dependency's that has (own = false: read-only here)
        public static DataSheet OwnOrDependency(Scenario sc, string name, out bool own)
        {
            own = false; if (sc == null) return null;
            DataSheet ds = sc.GetDataSheet(name); if (ds != null && ds.HasData()) { own = true; return ds; }
            foreach (Scenario d in sc.Dependencies) { DataSheet x = d.GetDataSheet(name); if (x != null && x.HasData()) return x; }
            return ds;
        }

        // ---- small layout helpers (as LucasView's) ------------------------------------------------------------------------------
        internal static Label Note(string text) { return new Label { Text = text, AutoSize = true, MaximumSize = new Size(640, 0), ForeColor = SystemColors.GrayText, Anchor = AnchorStyles.Left, Margin = new Padding(3, 7, 3, 3) }; }
        private static ComboBox List(int width) { return new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = width, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3) }; }
        internal static GroupBox Group(string title, Control content)
        {
            var gb = new GroupBox { Text = title, Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink, Padding = new Padding(10, 6, 10, 8), Margin = new Padding(3, 3, 3, 8) };
            content.Dock = DockStyle.Top; gb.Controls.Add(content); return gb;
        }
        private static Label Heading(string text) { return new Label { Text = text, AutoSize = true, Font = new Font(SystemFonts.DefaultFont, FontStyle.Bold), Margin = new Padding(3, 10, 3, 4), Tag = Fit.Fixed }; }
        private static Label Small(string text) { return new Label { Text = text, AutoSize = true, Margin = new Padding(3, 7, 3, 3), Tag = Fit.Fixed }; }
        private static FlowLayoutPanel Flow(params Control[] cs) { var f = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0) }; foreach (Control c in cs) f.Controls.Add(c); return f; }
        private static Label Blank() { return new Label { AutoSize = true, Width = 0 }; }

        // ---- rows ---------------------------------------------------------------------------------------------------------------
        private static IEnumerable<DataRow> Live(DataTable dt) { return dt.Rows.Cast<DataRow>().Where(x => x.RowState != DataRowState.Deleted); }
        private static List<DataRow> Rows(DataSheet ds) { return ds != null && ds.HasData() ? Live(ds.GetData()).ToList() : new List<DataRow>(); }
        private static string KeyOf(DataRow r) { return Convert.ToString(r["TransitionGroupId"]); }
        private static DataRow Find(DataSheet ds, string key) { return Rows(ds).FirstOrDefault(r => KeyOf(r) == key); }
        private static object Get(DataRow r, string col) { return r != null && r.Table.Columns.Contains(col) ? r[col] : DBNull.Value; }
        private static int Int(object v, int blank) { return v == DBNull.Value || v == null ? blank : Convert.ToInt32(v); }
        private static string Txt(object v) { return v == DBNull.Value || v == null ? "" : Convert.ToString(v); }

        private static List<KeyValuePair<object, string>> Choices(DataSheet ds, string column)
        {
            var l = new List<KeyValuePair<object, string>>();
            DataSheetColumn col = ds == null ? null : ds.Columns.Cast<DataSheetColumn>().FirstOrDefault(c => c.Name == column);
            if (col == null || col.ValidationTable == null) return l;
            ValidationTable vt = col.ValidationTable;
            foreach (DataRow r in Live(vt.DataSource)) l.Add(new KeyValuePair<object, string>(r[vt.ValueMember], Convert.ToString(r[vt.DisplayMember])));
            return l;
        }
        private static string NameOf(List<KeyValuePair<object, string>> choices, object v)
        {
            if (v == DBNull.Value || v == null) return null;
            foreach (var kv in choices) if (Convert.ToString(kv.Key) == Convert.ToString(v)) return kv.Value;
            return Convert.ToString(v);
        }

        // a choice into the row's column (null = blank)
        private void Set(Func<DataSheet> sheet, string key, string col, object v)
        {
            if (m_refreshing() || !Editable) return;
            DataSheet ds = sheet(); DataRow r = Find(ds, key); if (r == null || !r.Table.Columns.Contains(col)) return;
            object now = r[col]; v = v ?? DBNull.Value;
            if (Equals(now, v) || (now != DBNull.Value && v != DBNull.Value && Convert.ToString(now) == Convert.ToString(v))) return;
            ds.BeginModifyRows(); try { r[col] = v; } finally { ds.EndModifyRows(); }
            m_refresh();
        }

        // ---- building the family sections --------------------------------------------------------------------------------------
        private string Shape()
        {
            return string.Join(",", Rows(m_tr()).Select(KeyOf)) + ";" + string.Join(",", Rows(m_al()).Select(KeyOf)) + ";" + (Ms.Source[1] ?? "") + (Ms.Source[2] ?? "");
        }

        private void Build()
        {
            Host.SuspendLayout();
            if (Cards != null) foreach (Card k in Cards) { if (k.Head != null && k.Head.Parent != null) k.Head.Parent.Controls.Remove(k.Head); k.Shown = false; k.Body = null; k.Summary = null; }   // (the heads are the page's: kept)
            foreach (Control c in Host.Controls.Cast<Control>().ToList()) c.Dispose();
            Host.Controls.Clear(); Host.RowStyles.Clear(); m_blocks.Clear(); m_loose.Clear();
            DataSheet tr = m_tr(), al = m_al();
            List<KeyValuePair<object, string>> tg = Choices(tr, "TransitionGroupId"), ag = Choices(al, "TransitionGroupId");
            var allocs = Rows(al).Select(r => new KeyValuePair<string, string>(KeyOf(r), NameOf(ag, r["TransitionGroupId"]) ?? "")).ToList();
            var used = new HashSet<string>();
            foreach (DataRow r in Rows(tr))
            {
                var b = new Block { Key = KeyOf(r), Name = NameOf(tg, r["TransitionGroupId"]) ?? "(no group)" }; b.Family = FamilyOf(b.Name);
                if (IsMortality(b.Name)) continue;   // (2.0.4) set on the Mortality page alone: no card here
                foreach (var a in allocs)
                    if (!used.Contains(a.Key) && (a.Value == b.Name || a.Value.StartsWith(b.Name + ":")))
                    { used.Add(a.Key); b.Places.Add(MakePlace(a.Key, a.Value)); }
                m_blocks.Add(b);
            }
            foreach (var a in allocs) if (!used.Contains(a.Key)) m_loose.Add(MakePlace(a.Key, a.Value));

            var sets = new List<string> { "Land use", "Harvest", "Fire", "Reforestation" };
            foreach (DataRow r in Rows(tr)) { string s = Txt(Get(r, "SamplingSet")).Trim(); if (s.Length > 0 && !sets.Contains(s)) sets.Add(s); }
            var units = Choices(tr, "UnitSourceId");
            if (Cards != null) foreach (Card k in Cards)
            {
                var kb = m_blocks.Where(x => x.Card == null && m_families.Contains(x.Family) && k.Has(x.Name)).ToList();
                if (kb.Count == 0) continue;
                k.Body = ManagementActionsView.Lines(); k.Body.Margin = new Padding(16, 0, 0, 0);
                foreach (Block b in kb) { b.Card = k; MakeBlock(b, k.Body, sets, units); }
                k.Toggle = new Button { FlatStyle = FlatStyle.Flat, AutoSize = true, TextAlign = ContentAlignment.MiddleLeft, Margin = new Padding(0, 2, 6, 2), Tag = Fit.Fixed };
                k.Toggle.FlatAppearance.BorderSize = 0;
                k.Summary = Note(""); k.Summary.Margin = new Padding(3, 8, 3, 3);
                Card card = k;
                k.Toggle.Click += (s, e) => { if (!m_open.Remove(card.Title)) m_open.Add(card.Title); Fold(card); m_refresh(); };
                Fold(k); k.Shown = true;
                var rule = new Label { AutoSize = false, Height = 1, Width = 760, BackColor = SystemColors.ControlLight, Margin = new Padding(3, 8, 3, 2), Tag = Fit.Fixed };
                Host.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                Host.Controls.Add(Group(k.Title, ManagementActionsView.Lines(k.Head, rule, Flow(k.Toggle, k.Summary), k.Body)));
            }
            foreach (int f in m_families)
            {
                var bs = m_blocks.Where(x => x.Family == f && x.Card == null).ToList();
                bool loose = f == OTHER && m_loose.Count > 0;
                if (bs.Count == 0 && !loose) continue;
                var col = ManagementActionsView.Lines(Note(FamilyNote[f]));
                foreach (Block b in bs) MakeBlock(b, col, sets, units);
                if (loose) { col.Controls.Add(Heading("Placement rows of no group")); foreach (Place p in m_loose) col.Controls.Add(PlaceLine(p, p.Name + ":")); }
                Host.RowStyles.Add(new RowStyle(SizeType.AutoSize));
                Host.Controls.Add(Group(Title[f], col));
            }
            Host.ResumeLayout(true);
        }

        private void Fold(Card k)
        {
            bool open = m_open.Contains(k.Title);
            k.Toggle.Text = (open ? "▾" : "▸") + "  Where and how"; k.Body.Visible = open; k.Summary.Visible = !open;
        }

        private void MakeBlock(Block b, FlowLayoutPanel col, List<string> sets, List<KeyValuePair<object, string>> units)
        {
            col.Controls.Add(Heading(b.Name));
            b.Method = List(120); b.Method.Items.AddRange(METHOD);
            b.Strata = List(250); b.Units = List(250);
            for (int i = 0; i < 3; i++) b.Strata.Items.Add(Ms.Source[i] == null ? ManagementActionsView.ModelStrata.Levels[i] : string.Format("{0} ({1})", ManagementActionsView.ModelStrata.Levels[i], Ms.Source[i]));
            foreach (var u in units) b.Units.Items.Add(u.Value);
            b.ByStrata = Small("by"); b.ByUnits = Small("of each"); b.MethodNote = Note("");
            col.Controls.Add(ManagementActionsView.Line("How much:", Flow(b.Method, b.ByStrata, b.Strata, b.ByUnits, b.Units), b.MethodNote));
            b.Method.SelectionChangeCommitted += (s, e) => Set(m_tr, b.Key, "Method", b.Method.SelectedIndex + 1);
            b.Strata.SelectionChangeCommitted += (s, e) => Set(m_tr, b.Key, "StrataLevel", b.Strata.SelectedIndex + 1);
            b.Units.SelectionChangeCommitted += (s, e) => { int k = b.Units.SelectedIndex; if (k >= 0 && k < units.Count) Set(m_tr, b.Key, "UnitSourceId", units[k].Key); };
            // the shared draw
            b.Set = new ComboBox { DropDownStyle = ComboBoxStyle.DropDown, Width = 200, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 12, 3) };
            b.Set.Items.Add(OWN); foreach (string s in sets) b.Set.Items.Add(s);
            Action setDraw = () => { string t = b.Set.Text.Trim(); Set(m_tr, b.Key, "SamplingSet", t.Length == 0 || t == OWN ? null : t); };
            b.Set.SelectionChangeCommitted += (s, e) => { b.Set.Text = Convert.ToString(b.Set.SelectedItem); setDraw(); };
            b.Set.Validated += (s, e) => setDraw();
            col.Controls.Add(ManagementActionsView.Line("Shared draw:", b.Set, Note("Same name = same historical year.")));
            // protected areas
            var gaps = Flow();
            for (int i = 0; i < 3; i++)
            {
                var cb = new CheckBox { Text = "GAP " + (i + 1), AutoSize = true, Margin = new Padding(3, 5, 10, 3) }; b.Gap[i] = cb;
                cb.CheckedChanged += (s, e) => SetGap(b);
                gaps.Controls.Add(cb);
            }
            col.Controls.Add(ManagementActionsView.Line("Not on:", gaps, Note("Protected land: 1-2 biodiversity, 3 multiple use.")));
            // where it goes
            if (b.Family == FIRE) col.Controls.Add(ManagementActionsView.Line("Where it goes:", Blank(), Note(FireWhere)));
            else if (b.Places.Count == 0) col.Controls.Add(ManagementActionsView.Line("Where it goes:", Blank(), Note("Random within its units (no placement row).")));
            else if (b.Places.Count == 1 && b.Places[0].Name == b.Name) col.Controls.Add(PlaceLine(b.Places[0], "Where it goes:"));
            else
            {
                col.Controls.Add(ManagementActionsView.Line("Where it goes:", Blank(), Note("By type; the same surface name = one fitted surface.")));
                foreach (Place p in b.Places) col.Controls.Add(PlaceLine(p, "   " + ShortName(p.Name, b.Name) + ":"));
            }
        }

        private static string ShortName(string name, string group)
        {
            string s = name.StartsWith(group + ":") ? name.Substring(group.Length + 1).Trim() : name;
            return s.EndsWith(" [Type]") ? s.Substring(0, s.Length - 7) : s;
        }

        private Place MakePlace(string key, string name)
        {
            var p = new Place { Key = key, Name = name };
            p.Method = List(130); p.Method.Items.AddRange(PLACE);
            p.Surface = new TextBox { Width = 150, Anchor = AnchorStyles.Left, Margin = new Padding(3, 3, 8, 3) };
            p.Adj = new CheckBox { Text = "adjacency", AutoSize = true, Margin = new Padding(3, 5, 8, 3) };
            p.Size = List(70); p.Size.Items.AddRange(SIZE);
            p.Note = Note("");
            p.Method.SelectionChangeCommitted += (s, e) => Set(m_al, p.Key, "Method", p.Method.SelectedIndex + 1);
            p.Surface.Validated += (s, e) => { string t = p.Surface.Text.Trim(); Set(m_al, p.Key, "Surface", t.Length == 0 ? null : t); };
            p.Adj.CheckedChanged += (s, e) => Set(m_al, p.Key, "Adjacency", p.Adj.Checked ? TRUE : 0);
            p.Size.SelectionChangeCommitted += (s, e) => Set(m_al, p.Key, "SizeDistribution", p.Size.SelectedIndex + 1);
            return p;
        }

        private static FlowLayoutPanel PlaceLine(Place p, string caption)
        {
            return ManagementActionsView.Line(caption, Flow(p.Method, Small("surface"), p.Surface, p.Adj, Small("patch sizes"), p.Size), p.Note);
        }

        private void SetGap(Block b)
        {
            if (m_refreshing()) return;
            string now = Txt(Get(Find(m_tr(), b.Key), "ExcludeGap"));
            var keep = now.Split(new[] { '|', ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries).Where(x => x != "1" && x != "2" && x != "3").ToList();
            var codes = Enumerable.Range(1, 3).Where(i => b.Gap[i - 1].Checked).Select(i => i.ToString()).Concat(keep).ToList();
            Set(m_tr, b.Key, "ExcludeGap", codes.Count == 0 ? null : string.Join("|", codes));
        }

        // ---- showing the rows ---------------------------------------------------------------------------------------------------
        private void ShowBlock(Block b, DataRow r, List<KeyValuePair<object, string>> units)
        {
            int m = Int(Get(r, "Method"), 1);
            b.Method.SelectedIndex = Math.Max(0, Math.Min(2, m - 1));
            int lv = Int(Get(r, "StrataLevel"), 0); b.Strata.SelectedIndex = lv >= 1 && lv <= 3 ? lv - 1 : -1;
            string un = NameOf(units, Get(r, "UnitSourceId")); b.Units.SelectedIndex = un == null ? -1 : b.Units.Items.IndexOf(un);
            b.ByStrata.Visible = b.Strata.Visible = m == 1; b.ByUnits.Visible = b.Units.Visible = m == 2;
            b.MethodNote.Text = m == 1 && lv == 0 ? "Choose a level." : METHOD_NOTE[Math.Max(0, Math.Min(2, m - 1))];
            b.MethodNote.ForeColor = m == 1 && lv == 0 ? Color.Firebrick : SystemColors.GrayText;
            string s = Txt(Get(r, "SamplingSet")).Trim();
            if (!b.Set.Focused) b.Set.Text = s.Length == 0 ? OWN : s;
            string[] gap = Txt(Get(r, "ExcludeGap")).Split(new[] { '|', ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries);
            for (int i = 0; i < 3; i++) b.Gap[i].Checked = gap.Contains((i + 1).ToString());
        }

        private static void ShowPlace(Place p, DataRow r)
        {
            int m = Int(Get(r, "Method"), 1); p.Method.SelectedIndex = Math.Max(0, Math.Min(3, m - 1));
            if (!p.Surface.Focused) p.Surface.Text = Txt(Get(r, "Surface"));
            object a = Get(r, "Adjacency"); p.Adj.Checked = a == DBNull.Value || Convert.ToBoolean(a);
            p.Size.SelectedIndex = Math.Max(0, Math.Min(2, Int(Get(r, "SizeDistribution"), 1) - 1));
            p.Surface.Enabled = m == 1 || m == 4; p.Adj.Enabled = m == 1 || m == 2; p.Adj.Visible = LandUse(p.Name);
            string to = Txt(Get(r, "EventClasses"));
            p.Note.Text = PLACE_NOTE[p.Method.SelectedIndex] + (to.Length > 0 ? "; to " + to.Replace("LCMS:", "") : "") + ".";
        }

        // one sentence per group
        private string Describe(Block b, DataRow r, List<KeyValuePair<object, string>> units, Dictionary<string, int> setSize)
        {
            int m = Int(Get(r, "Method"), 1);
            if (m == 3) return b.Name + ": off in the projection.";
            int lv = Int(Get(r, "StrataLevel"), 0);
            string per = lv >= 1 && lv <= 3 ? (Ms.Source[lv - 1] ?? ManagementActionsView.ModelStrata.Levels[lv - 1]) : "(no level chosen)";
            string s = m == 1 ? string.Format("{0}: an area per unit of {1} each year, from the drawn historical year", b.Name, per)
                              : string.Format("{0}: the drawn year's rate in each unit of {1}, as a map", b.Name, NameOf(units, Get(r, "UnitSourceId")) ?? "(no units chosen)");
            string set = Txt(Get(r, "SamplingSet")).Trim();
            if (set.Length > 0 && setSize.ContainsKey(set) && setSize[set] > 1) s += string.Format(" ({0} draw, with {1} other group{2})", set.ToLowerInvariant(), setSize[set] - 1, setSize[set] == 2 ? "" : "s");
            else s += " (its own draw)";
            string gap = Txt(Get(r, "ExcludeGap")).Trim();
            if (gap.Length > 0) s += ", not on GAP " + gap.Replace("|", ", ");
            if (b.Family == FIRE) return s + ".";
            if (b.Places.Count == 0) return s + "; placed at random within its units.";
            var ps = new List<string>();
            foreach (Place p in b.Places)
            {
                DataRow a = Find(m_al(), p.Key); int pm = Int(Get(a, "Method"), 1); object adj = Get(a, "Adjacency"); bool near = adj == DBNull.Value || Convert.ToBoolean(adj);
                string how = pm == 1 ? string.Format("the fitted {0} surface", Txt(Get(a, "Surface")).Length > 0 ? Txt(Get(a, "Surface")) : "(unnamed)") : pm == 2 ? "the WUI and protected-area rules" : pm == 3 ? "at random" : "adjacency only";
                if (near && (pm == 1 || pm == 2) && LandUse(p.Name)) how += ", with adjacency";
                ps.Add(b.Places.Count > 1 || p.Name != b.Name ? ShortName(p.Name, b.Name) + " by " + how : how);
            }
            return s + "; placed by " + string.Join("; ", ps) + ".";
        }

        // rebuilds when the rows changed, shows their values, and returns one sentence per group shown; call while the page refreshes
        public List<string> Show()
        {
            string shape = Shape(); if (shape != m_shape) { Build(); m_shape = shape; }
            Host.Enabled = Editable;
            DataSheet tr = m_tr(), al = m_al();
            var units = Choices(tr, "UnitSourceId");
            var setSize = new Dictionary<string, int>();
            foreach (DataRow r in Rows(tr)) { string s = Txt(Get(r, "SamplingSet")).Trim(); if (s.Length > 0) setSize[s] = setSize.ContainsKey(s) ? setSize[s] + 1 : 1; }
            var words = new List<string>();
            var said = new Dictionary<Card, List<string>>();
            foreach (Block b in m_blocks)
            {
                if (!m_families.Contains(b.Family)) continue;
                DataRow r = Find(tr, b.Key); if (r == null) continue;
                ShowBlock(b, r, units);
                foreach (Place p in b.Places) { DataRow a = Find(al, p.Key); if (a != null) ShowPlace(p, a); }
                string w = Describe(b, r, units, setSize); words.Add(w);
                if (b.Card != null) { if (!said.ContainsKey(b.Card)) said[b.Card] = new List<string>(); said[b.Card].Add(w); }
            }
            foreach (var kv in said) if (kv.Key.Summary != null) kv.Key.Summary.Text = string.Join("  ", kv.Value);
            if (m_families.Contains(OTHER)) foreach (Place p in m_loose) { DataRow a = Find(al, p.Key); if (a != null) ShowPlace(p, a); }
            return words;
        }

        public bool HasRows { get { return Rows(m_tr()).Count > 0; } }
        public bool Shows(int family) { return m_blocks.Any(b => b.Family == family); }
    }
}
