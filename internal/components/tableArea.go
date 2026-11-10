package components

import (
	"fmt"
	"log"
	"math"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	lib "mt-y0/ECE-screen/lib/fonts"
	"mt-y0/ECE-screen/lib/raycss"

	rl "github.com/gen2brain/raylib-go/raylib"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

const eveningHour = 14 // local hour when evening sections replace morning ones

var arabicDays = [7]string{
	"الاحد", "الاثنين", "الثلاثاء", "الاربعاء", "الخميس", "الجمعة", "السبت",
}

var (
	shapedNoLectures = lib.Reshape("لا يوجد")
	shapedExamBadge  = lib.Reshape("امتحان")
)

var (
	examBg     = rl.NewColor(255, 243, 224, 255)
	examAccent = rl.NewColor(180, 83, 9, 255)
)

type secDef struct {
	key    string
	label  string
	period string // morning | evening | all
}

type stageDef struct {
	Number   int
	Title    string
	Sections []secDef
}

type classStruct struct {
	Id            string
	Stage         int
	Section       string
	ShapedSubject string
	ShapedHall    string
	StartTimeStr  string
	StartTime     time.Time
	EndTime       time.Time
	IsExam        bool
}

type stageCard struct {
	Rect   rl.Rectangle
	Mask   raycss.MaskContainer
	Title  string
	Number int
}

type TableLayout struct {
	screenSize [2]int32
	zoom       float64

	cards []stageCard
	mu    sync.RWMutex
	// stages is the configured class list (with all sections); filtered by period in Draw.
	stages []stageDef
	data   []classStruct
	dirty  atomic.Bool

	lastMinute int
	lastPeriod string // "morning" / "evening" — dirty when it flips

	pb        *pocketbase.PocketBase
	loadedDay atomic.Int32
	reloading atomic.Bool
}

func Parse12HourTime(s string) (time.Time, error) {
	s = strings.ToUpper(strings.TrimSpace(s))
	if t, err := time.Parse("03:04 PM", s); err == nil {
		return t, nil
	}
	return time.Parse("3:04 PM", s)
}

func currentPeriod(hour int) string {
	if hour < eveningHour {
		return "morning"
	}
	return "evening"
}

func visibleSections(all []secDef, period string) []secDef {
	out := make([]secDef, 0, len(all))
	for _, s := range all {
		p := strings.ToLower(strings.TrimSpace(s.period))
		if p == "" {
			p = "all"
		}
		if p == "all" || p == period {
			out = append(out, s)
		}
	}
	return out
}

func periodOf(key string, all []secDef) string {
	for _, s := range all {
		if s.key == key {
			p := strings.ToLower(strings.TrimSpace(s.period))
			if p == "" {
				return "all"
			}
			return p
		}
	}
	return ""
}

// sectionMatches reports whether a schedule row belongs in the given section column.
// Exams mirror across every section that shares the exam key's period on that stage
// (e.g. morning A/B both show a morning exam; evening مسائي stays evening-only).
func sectionMatches(lec classStruct, sectionKey string, stageSecs []secDef) bool {
	if !lec.IsExam {
		return lec.Section == sectionKey
	}
	lecPeriod := periodOf(lec.Section, stageSecs)
	keyPeriod := periodOf(sectionKey, stageSecs)
	if lecPeriod != "" && keyPeriod != "" && lecPeriod == keyPeriod && lecPeriod != "all" {
		return true
	}
	return lec.Section == sectionKey
}

func GetTableLayout(screenSize [2]int32, zoom float64) *TableLayout {
	l := &TableLayout{
		screenSize: screenSize,
		zoom:       zoom,
	}
	l.dirty.Store(true)
	l.lastMinute = -1
	l.loadedDay.Store(-1)
	return l
}

func (l *TableLayout) rebuildCards(stages []stageDef) {
	for i := range l.cards {
		l.cards[i].Mask.Unload()
	}
	l.cards = nil
	n := len(stages)
	if n == 0 {
		return
	}
	padding := roundPx(15 * l.zoom)
	stageW := roundPx(float64(l.screenSize[0]-padding*int32(n+1)) / float64(n))
	stageH := roundPx(float64(l.screenSize[1])*tableBandFrac) - padding
	l.cards = make([]stageCard, n)
	for i, st := range stages {
		x := padding + (padding+stageW)*int32(i)
		title := st.Title
		if strings.TrimSpace(title) == "" {
			title = fmt.Sprintf("المرحلة%d", st.Number)
		}
		l.cards[i] = stageCard{
			Rect: rl.Rectangle{
				X: float32(x), Y: float32(padding),
				Width: float32(stageW), Height: float32(stageH),
			},
			Mask:   raycss.NewMaskContainer(stageW, stageH, cardRadius),
			Title:  lib.Reshape(title + "  "),
			Number: st.Number,
		}
	}
}

func (l *TableLayout) loadStages(pb *pocketbase.PocketBase) ([]stageDef, error) {
	stageRecs, err := pb.FindRecordsByFilter("Stages", "", "+display_order,+number", 50, 0)
	if err != nil {
		return nil, err
	}
	secRecs, err := pb.FindRecordsByFilter("Sections", "", "+display_order,+key", 200, 0)
	if err != nil {
		return nil, err
	}

	byStage := map[int][]secDef{}
	for _, r := range secRecs {
		stage := r.GetInt("stage")
		key := strings.TrimSpace(r.GetString("key"))
		if stage <= 0 || key == "" {
			continue
		}
		label := strings.TrimSpace(r.GetString("label"))
		if label == "" {
			label = key
		}
		period := strings.ToLower(strings.TrimSpace(r.GetString("period")))
		if period == "" {
			period = "all"
		}
		byStage[stage] = append(byStage[stage], secDef{
			key: key, label: lib.Reshape(label + " "), period: period,
		})
	}

	stages := make([]stageDef, 0, len(stageRecs))
	for _, r := range stageRecs {
		num := r.GetInt("number")
		if num <= 0 {
			continue
		}
		stages = append(stages, stageDef{
			Number:   num,
			Title:    strings.TrimSpace(r.GetString("title")),
			Sections: byStage[num],
		})
	}

	// Fallback so a missing config still shows something usable.
	if len(stages) == 0 {
		stages = defaultStages()
	}
	return stages, nil
}

func defaultStages() []stageDef {
	out := make([]stageDef, 0, 4)
	for n := 4; n >= 1; n-- { // left-to-right: 4 … 1
		out = append(out, stageDef{
			Number: n,
			Title:  fmt.Sprintf("المرحلة%d", n),
			Sections: []secDef{
				{key: "B", label: lib.Reshape("شعبةB "), period: "morning"},
				{key: "A", label: lib.Reshape("شعبةA "), period: "morning"},
				{key: "مسائي", label: lib.Reshape("الدراسة المسائية "), period: "evening"},
			},
		})
	}
	return out
}

func (l *TableLayout) GetData(pb *pocketbase.PocketBase) error {
	weekday := int(time.Now().Weekday())
	l.loadedDay.Store(int32(weekday))

	stages, err := l.loadStages(pb)
	if err != nil {
		return err
	}

	records, err := pb.FindRecordsByFilter(
		"Schedules",
		fmt.Sprintf("day='%s'", arabicDays[weekday]),
		"", 500, 0,
	)
	if err != nil {
		return err
	}

	data := make([]classStruct, 0, len(records))
	for _, r := range records {
		start, errS := Parse12HourTime(r.GetString("start_time"))
		end, errE := Parse12HourTime(r.GetString("end_time"))
		if errS != nil || errE != nil {
			log.Printf("schedule %s: bad time (start=%q end=%q), row skipped",
				r.Id, r.GetString("start_time"), r.GetString("end_time"))
			continue
		}
		data = append(data, classStruct{
			Id:            r.Id,
			Stage:         r.GetInt("stage"),
			Section:       r.GetString("section"),
			ShapedSubject: lib.Reshape(r.GetString("subject")),
			ShapedHall:    lib.Reshape("قاعة " + r.GetString("hall") + " "),
			StartTimeStr:  r.GetString("start_time"),
			StartTime:     start,
			EndTime:       end,
			IsExam:        r.GetBool("is_exam"),
		})
	}
	sort.Slice(data, func(i, j int) bool {
		return data[i].StartTime.Before(data[j].StartTime)
	})

	l.mu.Lock()
	needRebuild := len(stages) != len(l.stages)
	if !needRebuild {
		for i := range stages {
			if stages[i].Number != l.stages[i].Number || stages[i].Title != l.stages[i].Title {
				needRebuild = true
				break
			}
		}
	}
	l.stages = stages
	l.data = data
	if needRebuild || len(l.cards) != len(stages) {
		l.rebuildCards(stages)
	}
	l.mu.Unlock()
	l.dirty.Store(true)
	return nil
}

func (l *TableLayout) Watch(pb *pocketbase.PocketBase) {
	l.pb = pb
	reload := func(e *core.RecordEvent) error {
		if err := l.GetData(pb); err != nil {
			log.Printf("table reload: %v", err)
		}
		return e.Next()
	}
	for _, col := range []string{"Schedules", "Stages", "Sections"} {
		pb.OnRecordAfterCreateSuccess(col).BindFunc(reload)
		pb.OnRecordAfterUpdateSuccess(col).BindFunc(reload)
		pb.OnRecordAfterDeleteSuccess(col).BindFunc(reload)
	}
}

func (l *TableLayout) Draw(font *rl.Font, zoom float64, blue, lightBlue rl.Color) {
	l.mu.RLock()
	data := l.data
	stages := l.stages
	cards := l.cards
	l.mu.RUnlock()

	now := time.Now()
	nowH, nowM, _ := now.Clock()
	period := currentPeriod(nowH)

	if l.pb != nil && int32(now.Weekday()) != l.loadedDay.Load() &&
		l.reloading.CompareAndSwap(false, true) {
		go func() {
			defer l.reloading.Store(false)
			if err := l.GetData(l.pb); err != nil {
				log.Printf("table day reload: %v", err)
			}
		}()
	}

	nowMin := now.Hour()*60 + now.Minute()
	if l.lastMinute != nowMin {
		l.lastMinute = nowMin
		l.dirty.Store(true)
	}
	if l.lastPeriod != period {
		l.lastPeriod = period
		l.dirty.Store(true)
	}

	headerH := float32(math.Round(48.0 * zoom))
	titleFS := float32(math.Round(36.0 * zoom))
	secNameH := float32(math.Round(34.0 * zoom))
	sLblFS := float32(math.Round(28.0 * zoom))
	timeFS := float32(math.Round(20.0 * zoom))
	subFS := float32(math.Round(24.0 * zoom))
	hallFS := float32(math.Round(18.0 * zoom))
	noLecFS := float32(math.Round(18.0 * zoom))
	badgeFS := float32(math.Round(16.0 * zoom))
	cardPad := raycss.SXY(8, 10).Scale(zoom)

	if l.dirty.Swap(false) {
		for i := range cards {
			card := cards[i]
			st := stages[i]
			sections := visibleSections(st.Sections, period)
			cards[i].Mask.PreRender(rl.White, func() {
				W, H := card.Rect.Width, card.Rect.Height
				rl.DrawRectangle(0, 0, int32(W), int32(headerH), blue)
				ts := rl.MeasureTextEx(*font, card.Title, titleFS, 0)
				rl.DrawTextEx(*font, card.Title,
					rl.Vector2{X: W/2 - ts.X/2, Y: headerH/2 - ts.Y/2},
					titleFS, 0, rl.White)

				if len(sections) == 0 {
					nSz := rl.MeasureTextEx(*font, shapedNoLectures, noLecFS, 0)
					rl.DrawTextEx(*font, shapedNoLectures,
						rl.Vector2{X: W/2 - nSz.X/2, Y: headerH + secNameH},
						noLecFS, 0, raycss.TextMuted)
					return
				}

				secW := W / float32(len(sections))
				for j, sec := range sections {
					x0 := float32(j) * secW
					rl.DrawRectangle(int32(x0), int32(headerH), int32(secW), int32(secNameH), lightBlue)
					slSz := rl.MeasureTextEx(*font, sec.label, sLblFS, 0)
					rl.DrawTextEx(*font, sec.label,
						rl.Vector2{
							X: x0 + secW/2 - slSz.X/2,
							Y: headerH + secNameH/2 - slSz.Y/2,
						}, sLblFS, 0, blue)
					if j > 0 {
						raycss.DrawVLine(x0, headerH, H-headerH, raycss.BorderColor)
					}

					y := headerH + secNameH + cardPad.Top
					hasAny := false
					for _, lec := range data {
						if lec.Stage != card.Number || !sectionMatches(lec, sec.key, st.Sections) {
							continue
						}
						endH, endM, _ := lec.EndTime.Clock()
						if endH < nowH || (endH == nowH && endM <= nowM) {
							continue
						}
						if y+subFS+hallFS+cardPad.V() > H {
							break
						}
						hasAny = true

						tSz := rl.MeasureTextEx(*font, lec.StartTimeStr, timeFS, 0)
						subSz := rl.MeasureTextEx(*font, lec.ShapedSubject, subFS, 0)
						fs := subFS
						if subSz.X > secW-cardPad.H() {
							fs = subFS * (secW - cardPad.H()) / subSz.X
							if fs < 10 {
								fs = 10
							}
						}
						if fs != subFS {
							subSz = rl.MeasureTextEx(*font, lec.ShapedSubject, fs, 0)
						}
						hSz := rl.MeasureTextEx(*font, lec.ShapedHall, hallFS, 0)

						blockTop := y - 2
						blockH := tSz.Y + 2 + subFS + 2 + hallFS + 4
						timeColor, subjectColor, hallColor := blue, raycss.TextDark, raycss.TextMuted
						if lec.IsExam {
							rl.DrawRectangle(int32(x0+2), int32(blockTop), int32(secW-4), int32(blockH), examBg)
							rl.DrawRectangle(int32(x0+2), int32(blockTop), 3, int32(blockH), examAccent)
							timeColor, subjectColor, hallColor = examAccent, examAccent, examAccent
							bSz := rl.MeasureTextEx(*font, shapedExamBadge, badgeFS, 0)
							rl.DrawTextEx(*font, shapedExamBadge,
								rl.Vector2{X: x0 + cardPad.Left + 4, Y: y + (tSz.Y-bSz.Y)/2},
								badgeFS, 0, examAccent)
						}

						rl.DrawTextEx(*font, lec.StartTimeStr,
							rl.Vector2{X: x0 + secW - cardPad.Right - tSz.X, Y: y},
							timeFS, 0, timeColor)
						y += tSz.Y + 2
						rl.DrawTextEx(*font, lec.ShapedSubject,
							rl.Vector2{X: x0 + secW - cardPad.Right - subSz.X, Y: y},
							fs, 0, subjectColor)
						y += subFS + 2
						rl.DrawTextEx(*font, lec.ShapedHall,
							rl.Vector2{X: x0 + secW - cardPad.Right - hSz.X, Y: y},
							hallFS, 0, hallColor)
						y += hallFS + 4
						if !lec.IsExam {
							raycss.DrawHLine(x0+cardPad.Left, y, secW-cardPad.H(), raycss.BorderColor)
						}
						y += cardPad.Bottom
					}

					if !hasAny {
						nSz := rl.MeasureTextEx(*font, shapedNoLectures, noLecFS, 0)
						rl.DrawTextEx(*font, shapedNoLectures,
							rl.Vector2{
								X: x0 + secW/2 - nSz.X/2,
								Y: headerH + secNameH + cardPad.Top,
							}, noLecFS, 0, raycss.TextMuted)
					}
				}
			})
		}
	}

	for i := range cards {
		raycss.DrawSoftShadow(cards[i].Rect, cardRadius, shadowSegs)
		cards[i].Mask.Blit(cards[i].Rect.X, cards[i].Rect.Y)
	}
}

func (l *TableLayout) CleanUp() {
	for i := range l.cards {
		l.cards[i].Mask.Unload()
	}
	l.cards = nil
}
