package components

import "testing"

func sampleStageSecs() []secDef {
	return []secDef{
		{key: "B", label: "B", period: "morning"},
		{key: "A", label: "A", period: "morning"},
		{key: "C", label: "C", period: "morning"},
		{key: "مسائي", label: "eve", period: "evening"},
	}
}

func TestSectionMatches(t *testing.T) {
	secs := sampleStageSecs()
	lectureA := classStruct{Section: "A", IsExam: false}
	lectureEve := classStruct{Section: "مسائي", IsExam: false}
	examA := classStruct{Section: "A", IsExam: true}
	examEve := classStruct{Section: "مسائي", IsExam: true}
	examC := classStruct{Section: "C", IsExam: true}

	cases := []struct {
		name string
		lec  classStruct
		key  string
		want bool
	}{
		{"lecture A in A", lectureA, "A", true},
		{"lecture A not in B", lectureA, "B", false},
		{"lecture evening only", lectureEve, "مسائي", true},
		{"lecture evening not in A", lectureEve, "A", false},
		{"exam A in A", examA, "A", true},
		{"exam A also in B", examA, "B", true},
		{"exam A also in C (same morning period)", examA, "C", true},
		{"exam A not in evening", examA, "مسائي", false},
		{"exam C in A (same morning period)", examC, "A", true},
		{"exam evening only", examEve, "مسائي", true},
		{"exam evening not in A", examEve, "A", false},
	}
	for _, tc := range cases {
		if got := sectionMatches(tc.lec, tc.key, secs); got != tc.want {
			t.Errorf("%s: got %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestVisibleSections(t *testing.T) {
	all := sampleStageSecs()
	m := visibleSections(all, "morning")
	if len(m) != 3 || m[0].key != "B" || m[2].key != "C" {
		t.Fatalf("morning=%v", m)
	}
	e := visibleSections(all, "evening")
	if len(e) != 1 || e[0].key != "مسائي" {
		t.Fatalf("evening=%v", e)
	}
}

func TestParse12HourTime(t *testing.T) {
	good := map[string][2]int{
		"08:00 AM":   {8, 0},
		"8:00 AM":    {8, 0},
		"8:00 am":    {8, 0},
		" 12:30 PM ": {12, 30},
		"01:05 PM":   {13, 5},
		"12:00 AM":   {0, 0},
	}
	for in, want := range good {
		got, err := Parse12HourTime(in)
		if err != nil {
			t.Errorf("%q: unexpected error %v", in, err)
			continue
		}
		if h, m, _ := got.Clock(); h != want[0] || m != want[1] {
			t.Errorf("%q: got %02d:%02d, want %02d:%02d", in, h, m, want[0], want[1])
		}
	}
	for _, in := range []string{"", "25:00 PM", "noon", "13:00"} {
		if _, err := Parse12HourTime(in); err == nil {
			t.Errorf("%q: expected an error", in)
		}
	}
}
