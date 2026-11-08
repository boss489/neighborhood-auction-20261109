extends Control
class_name AuctionGame

const NAMES = ["찻잔", "우산", "화분", "시계", "책", "등불"]
const ICONS = ["●", "◆", "▲", "■", "★", "◇"]
const PRICES = [2, 3, 5, 7, 6, 4]
const INK = Color("263941")
const PAPER = Color("f5f1e6")
const CREAM = Color("fffaf0")
const GREEN = Color("286d56")
const ORANGE = Color("a65134")
const ACCENT = Color("bd6443")
const TUTORIAL = [
    {"name":"첫 종소리", "start":[0,2,1,3], "cards":[["near",0,1]], "optimal":1},
    {"name":"가격표의 비밀", "start":[1,3,0,2], "cards":[["apart",0,2],["sum",0,10],["near",1,2]], "optimal":1}
]

var levels: Array = []
var stars: Array = []
var unlocked := 0
var high_contrast := false
var reduced_motion := false
var muted := false
var screen := "home"
var level_index := 0
var tutorial_index := 0
var ring: Array = []
var cards: Array = []
var history: Array = []
var redo_stack: Array = []
var selected := -1
var hovered := -1
var moves := 0
var paused := false
var panel: VBoxContainer
var board: Control
var hint: Label
var ui_font: Font
var audio: AudioStreamPlayer

static func adjacent(a: int, b: int, n: int) -> bool:
    var d := absi(a - b)
    return d == 1 or d == n - 1

static func evaluate(order: Array, rules: Array) -> Array:
    var states: Array = []
    for rule in rules:
        var a: int = int(rule[1])
        var ia := order.find(a)
        if rule[0] == "sum":
            var n := order.size()
            states.append(PRICES[int(order[(ia+n-1)%n])] + PRICES[int(order[(ia+1)%n])] == int(rule[2]))
        else:
            var ib := order.find(int(rule[2]))
            var meets := adjacent(ia, ib, order.size())
            states.append(meets if rule[0] == "near" else not meets)
    return states

static func solved(order: Array, rules: Array) -> bool:
    for value in evaluate(order, rules):
        if not value: return false
    return true

func _ready() -> void:
    var file := FileAccess.open("res://levels.json", FileAccess.READ)
    levels = JSON.parse_string(file.get_as_text())
    # JSON numbers arrive as floats; item IDs must be exact integer identifiers.
    for level in levels:
        for i in range(level["start"].size()): level["start"][i] = int(level["start"][i])
        for card in level["cards"]:
            card[1] = int(card[1])
            card[2] = int(card[2])
        level["optimal"] = int(level["optimal"])
    stars.resize(levels.size())
    stars.fill(0)
    var font_file := load("res://assets/NotoSansKR.ttf")
    ui_font = font_file
    theme = Theme.new()
    theme.default_font = ui_font
    theme.default_font_size = 20
    audio = AudioStreamPlayer.new()
    add_child(audio)
    _load_save()
    render()
    get_viewport().size_changed.connect(_on_resized)

func _on_resized() -> void:
    if panel != null and is_instance_valid(panel):
        panel.custom_minimum_size.x = minf(760.0, maxf(300.0, size.x - 24.0))

func _load_save() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://auction.cfg") != OK: return
    unlocked = clampi(int(cfg.get_value("progress","unlocked",0)),0,levels.size()-1)
    var saved: Array = cfg.get_value("progress","stars",[])
    for i in range(mini(saved.size(),stars.size())): stars[i] = clampi(int(saved[i]),0,3)
    high_contrast = bool(cfg.get_value("settings","contrast",false))
    reduced_motion = bool(cfg.get_value("settings","motion",false))
    muted = bool(cfg.get_value("settings","mute",false))

func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress","unlocked",unlocked)
    cfg.set_value("progress","stars",stars)
    cfg.set_value("settings","contrast",high_contrast)
    cfg.set_value("settings","motion",reduced_motion)
    cfg.set_value("settings","mute",muted)
    cfg.save("user://auction.cfg")

func _style(color: Color, edge: Color = INK) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = edge
    box.set_border_width_all(2)
    box.set_corner_radius_all(12)
    box.set_content_margin_all(10)
    return box

func _label(text: String, font_size: int = 20, center := false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color", INK if not high_contrast else Color.BLACK)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if center: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

func _button(text: String, action: Callable, color: Color = CREAM) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(90,52)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_stylebox_override("normal",_style(color))
    b.add_theme_stylebox_override("hover",_style(Color("ffe5c7"), ACCENT))
    b.add_theme_stylebox_override("pressed",_style(Color("ead5bc")))
    b.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT, Color("116f9a")))
    b.add_theme_color_override("font_color", INK)
    b.add_theme_color_override("font_hover_color", INK)
    b.add_theme_color_override("font_pressed_color", INK)
    b.add_theme_font_size_override("font_size",18)
    b.pressed.connect(action)
    return b

func _row(parent: Node) -> HFlowContainer:
    var r := HFlowContainer.new()
    r.alignment = FlowContainer.ALIGNMENT_CENTER
    r.add_theme_constant_override("h_separation",8)
    r.add_theme_constant_override("v_separation",8)
    parent.add_child(r)
    return r

func _add(parent: Node, text: String, size_px := 20, centered := false) -> Label:
    var l := _label(text,size_px,centered)
    parent.add_child(l)
    return l

func _clear() -> void:
    for child in get_children():
        if child != audio:
            remove_child(child)
            child.queue_free()

func render() -> void:
    _clear()
    var bg := ColorRect.new()
    bg.color = Color("f0e7d7") if not high_contrast else Color.WHITE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var sc := ScrollContainer.new()
    sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(sc)
    var align := CenterContainer.new()
    align.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(align)
    panel = VBoxContainer.new()
    panel.custom_minimum_size.x = minf(760.0,maxf(300.0,size.x-24.0))
    panel.add_theme_constant_override("separation",12)
    align.add_child(panel)
    _add(panel,"★  이웃 경매판  ★",38,true)
    _add(panel,"NEIGHBORHOOD AUCTION  /  손그림 종이 경매",15,true)
    if screen == "home": _home()
    elif screen == "levels": _levels()
    elif screen == "tutorial" or screen == "game": _game()
    elif screen == "win": _win()
    elif screen == "loss": _loss()
    elif screen == "ending": _ending()
    elif screen == "pause": _pause()
    _add(panel,"두 물건을 선택해 교환 · Z 실행 취소 · Y 다시 실행 · R 재시작 · Esc 일시정지",15,true)
    _add(panel,"© 2026 이웃 경매판 · 자작 도형/효과음 · Noto Sans KR (OFL)",13,true)

func _settings() -> void:
    var row := _row(panel)
    row.add_child(_button("고대비: %s" % ("켬" if high_contrast else "끔"),func():
        high_contrast = not high_contrast; _save(); render()))
    row.add_child(_button("움직임 축소: %s" % ("켬" if reduced_motion else "끔"),func():
        reduced_motion = not reduced_motion; _save(); render()))
    row.add_child(_button("소리: %s" % ("끔" if muted else "켬"),func():
        muted = not muted; _save(); render()))

func _home() -> void:
    _add(panel,"동네 물건들을 원형 진열대에서 맞바꾸세요. 모든 주문 카드가 ✓이면 종이 울립니다.",22,true)
    _add(panel,"● ◆ ▲ ■ ★ ◇  가격표는 물건을 따라 움직여요.",23,true)
    var row := _row(panel)
    row.add_child(_button("처음 배우기  →",func(): _start_tutorial(0), Color("d2eadb")))
    row.add_child(_button("이어하기  →",func(): _start_level(unlocked)))
    row.add_child(_button("12판 고르기",func(): screen="levels"; render()))
    _settings()
    var total := 0
    for s in stars: total += int(s)
    _add(panel,"진행 %d / 12  ·  모은 별 %d / 36" % [stars.filter(func(s): return s > 0).size(),total],19,true)

func _levels() -> void:
    _add(panel,"12장의 주문서 · 한 판을 클리어하면 다음 판이 열립니다.",21,true)
    var grid := GridContainer.new()
    grid.columns = 3 if size.x < 600 else 4
    panel.add_child(grid)
    for i in range(levels.size()):
        var index := i
        var text := "%02d  %s\n%s" % [i+1,levels[i]["name"],"★".repeat(int(stars[i])) if i<=unlocked else "잠김"]
        var b := _button(text,func(): _start_level(index))
        b.custom_minimum_size = Vector2(90,82)
        b.disabled = i>unlocked
        grid.add_child(b)
    _row(panel).add_child(_button("← 제목",func(): screen="home"; render()))
    _settings()

func _start_tutorial(index: int) -> void:
    tutorial_index = index
    _load_round(TUTORIAL[index])
    screen = "tutorial"
    render()

func _start_level(index: int) -> void:
    if index < 0 or index > unlocked or index >= levels.size(): return
    level_index = index
    _load_round(levels[index])
    screen = "game"
    render()

func _load_round(data: Dictionary) -> void:
    ring = data["start"].duplicate()
    cards = data["cards"].duplicate(true)
    history.clear(); redo_stack.clear()
    selected = -1; hovered = -1; moves = 0; paused = false

func _card_text(card: Array) -> String:
    var a: String = NAMES[int(card[1])]
    if card[0] == "sum": return "◇ %s 양옆 가격 합 = %d" % [a,int(card[2])]
    var b: String = NAMES[int(card[2])]
    return "↔ %s · %s : %s" % [a,b,"이웃" if card[0] == "near" else "서로 떨어짐"]

func _game() -> void:
    var data: Dictionary = TUTORIAL[tutorial_index] if screen == "tutorial" else levels[level_index]
    _add(panel,("학습 %d / 2" % (tutorial_index+1)) if screen == "tutorial" else ("%02d / 12  %s" % [level_index+1,data["name"]]),27,true)
    if screen == "tutorial":
        _add(panel,"두 물건을 순서대로 탭해 위치를 교환해 보세요. 빨간 주문 카드를 초록 ✓로 바꾸면 통과!" if tutorial_index == 0 else "이웃뿐 아니라 '떨어짐'과 양옆 가격 합도 확인하세요. 첫 칸과 끝 칸도 이웃입니다.",18,true)
    _add(panel,"교환 %d회  ·  ★★★ 기준 %d회  ·  카드 %d장%s" % [moves,int(data["optimal"]),cards.size(),"  ·  남은 교환 %d회" % (int(data["optimal"])+5-moves) if screen=="game" else ""],18,true)
    board = Control.new()
    board.custom_minimum_size = Vector2(0,340 if size.x > 400 else 300)
    panel.add_child(board)
    board.resized.connect(_layout_slots)
    board.draw.connect(_draw_board)
    for i in range(ring.size()):
        var slot := i
        var item := int(ring[i])
        var b := _button("%s\n%s · %d냥" % [ICONS[item],NAMES[item],PRICES[item]],func(): _select(slot),Color("d7e8da") if selected == i else CREAM)
        b.name = "Slot%d" % i
        b.custom_minimum_size = Vector2(92,68)
        b.size_flags_horizontal = 0
        b.mouse_entered.connect(func(): hovered=slot; _update_hint())
        b.mouse_exited.connect(func(): hovered=-1; _update_hint())
        board.add_child(b)
    _layout_slots()
    hint = _add(panel,"",17,true)
    _update_hint()
    _add(panel,"주문 카드 · 초록 ✓ 충족 / 주황 ! 미충족",19,true)
    var results := evaluate(ring,cards)
    var preview := _preview_order()
    var next_states := evaluate(preview,cards) if not preview.is_empty() else results
    for i in range(cards.size()):
        var row := HBoxContainer.new()
        panel.add_child(row)
        var mark := "✓" if results[i] else "!"
        var change := "  → %s" % ("✓" if next_states[i] else "!") if not preview.is_empty() and results[i] != next_states[i] else ""
        var l := _add(row,"%s  %s%s" % [mark,_card_text(cards[i]),change],17)
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.add_theme_stylebox_override("normal",_style((Color("def0e4") if results[i] else Color("ffe1cd")) if not high_contrast else Color.WHITE, GREEN if results[i] else ORANGE))
        l.add_theme_color_override("font_color",GREEN if results[i] else ORANGE)
    var row := _row(panel)
    row.add_child(_button("← 취소 Z",_undo))
    row.add_child(_button("→ 다시 Y",_redo))
    row.add_child(_button("재시작 R",_reset))
    row.add_child(_button("Ⅱ 일시정지",func(): paused = screen=="tutorial"; screen="pause"; render()))
    _row(panel).add_child(_button("← 레벨 선택",func(): screen="levels"; render()))

func _draw_board() -> void:
    if board == null or not is_instance_valid(board): return
    var center := board.size * 0.5
    var radius := minf(board.size.x * 0.34, board.size.y * 0.34)
    board.draw_circle(center,radius+34,Color("eadbc3") if not high_contrast else Color.WHITE)
    board.draw_arc(center,radius+14,0,TAU,64,ACCENT,6,true)
    for i in range(ring.size()):
        var angle := -PI/2 + TAU*i/ring.size()
        var point := center + Vector2(cos(angle),sin(angle))*radius
        board.draw_line(center,point,Color("cda883"),2,true)
    board.draw_circle(center,29,INK)
    board.draw_circle(center,23,Color("f3ce85"))

func _layout_slots() -> void:
    if board == null or not is_instance_valid(board): return
    var center := board.size*0.5
    var radius := minf(board.size.x*0.34,board.size.y*0.34)
    for i in range(ring.size()):
        var b := board.get_node_or_null("Slot%d" % i) as Button
        if b == null: continue
        b.size = Vector2(100,72)
        var angle := -PI/2 + TAU*i/ring.size()
        b.position = center + Vector2(cos(angle),sin(angle))*radius - b.size*0.5
    board.queue_redraw()

func _preview_order() -> Array:
    if selected<0 or hovered<0 or selected==hovered: return []
    var candidate := ring.duplicate()
    var tmp = candidate[selected]
    candidate[selected] = candidate[hovered]
    candidate[hovered] = tmp
    return candidate

func _update_hint() -> void:
    if hint == null or not is_instance_valid(hint): return
    if selected<0: hint.text = "물건 하나를 선택하세요 · Tab으로 이동, Enter/Space로 선택"
    elif hovered>=0 and selected != hovered:
        var next := _preview_order()
        hint.text = "%s ↔ %s 예고 · 조건 %d/%d → %d/%d" % [NAMES[int(ring[selected])],NAMES[int(ring[hovered])],evaluate(ring,cards).count(true),cards.size(),evaluate(next,cards).count(true),cards.size()]
    else: hint.text = "%s 선택됨 · 바꿀 물건을 선택하세요" % NAMES[int(ring[selected])]
    if board != null and is_instance_valid(board):
        for i in range(ring.size()):
            var b := board.get_node_or_null("Slot%d" % i) as Button
            if b != null: b.add_theme_stylebox_override("normal",_style(Color("d7e8da") if i==selected else CREAM))

func _select(index: int) -> void:
    if selected<0:
        selected=index; _update_hint(); return
    if selected==index:
        selected=-1; _update_hint(); return
    history.append(ring.duplicate())
    redo_stack.clear()
    var tmp = ring[selected]
    ring[selected] = ring[index]
    ring[index] = tmp
    selected=-1; hovered=-1; moves+=1
    if solved(ring,cards):
        _bell()
        if screen=="tutorial":
            if tutorial_index==0: _start_tutorial(1)
            else: screen="home"; render()
        else:
            var optimal := int(levels[level_index]["optimal"])
            var earned := 3 if moves<=optimal else (2 if moves<=optimal+2 else 1)
            stars[level_index] = maxi(int(stars[level_index]),earned)
            unlocked = maxi(unlocked,mini(level_index+1,levels.size()-1))
            _save()
            screen="win"; render()
    else:
        if screen=="game" and moves>=int(levels[level_index]["optimal"])+5: screen="loss"
        render()

func _bell() -> void:
    if muted: return
    var sample := AudioStreamWAV.new()
    sample.format = AudioStreamWAV.FORMAT_16_BITS
    sample.mix_rate = 22050
    var bytes := PackedByteArray()
    for i in range(9000):
        var t := float(i)/22050.0
        var amp := exp(-t*10.0) * (sin(TAU*660*t)+0.45*sin(TAU*990*t)) * 0.28
        var value := clampi(int(amp*32767),-32768,32767)
        bytes.append(value & 255)
        bytes.append((value >> 8) & 255)
    sample.data=bytes
    audio.stream=sample
    audio.play()

func _undo() -> void:
    if history.is_empty(): return
    redo_stack.append(ring.duplicate())
    ring=history.pop_back()
    moves=maxi(0,moves-1)
    selected=-1; render()

func _redo() -> void:
    if redo_stack.is_empty(): return
    history.append(ring.duplicate())
    ring=redo_stack.pop_back()
    moves+=1
    selected=-1
    if solved(ring,cards):
        _bell()
        if screen=="game":
            var optimal := int(levels[level_index]["optimal"])
            stars[level_index]=maxi(int(stars[level_index]),3 if moves<=optimal else (2 if moves<=optimal+2 else 1))
            unlocked=maxi(unlocked,mini(level_index+1,11)); _save()
            screen="win"
        elif tutorial_index==0: _start_tutorial(1); return
        else: screen="home"
    elif screen=="game" and moves>=int(levels[level_index]["optimal"])+5: screen="loss"
    render()

func _reset() -> void:
    if screen=="tutorial": _start_tutorial(tutorial_index)
    else: _start_level(level_index)

func _win() -> void:
    _add(panel,"✓ 주문 완료!",33,true)
    _add(panel,"교환 %d회 · 최단 %d회" % [moves,int(levels[level_index]["optimal"])],22,true)
    _add(panel,"★".repeat(int(stars[level_index])) + "☆".repeat(3-int(stars[level_index])),36,true)
    _add(panel,"모든 카드를 충족했습니다. 더 적은 교환으로 별을 올릴 수 있어요.",19,true)
    var row := _row(panel)
    if level_index<11: row.add_child(_button("다음 주문 →",func(): _start_level(level_index+1),Color("d2eadb")))
    else: row.add_child(_button("완주 화면 →",func(): screen="ending"; render(),Color("d2eadb")))
    row.add_child(_button("다시 도전",func(): _start_level(level_index)))
    row.add_child(_button("12판 선택",func(): screen="levels"; render()))

func _loss() -> void:
    _add(panel,"! 주문 실패",33,true)
    _add(panel,"교환 %d회 · 제한 %d회" % [moves,int(levels[level_index]["optimal"])+5],22,true)
    _add(panel,"교환 횟수가 다했습니다. 카드와 원형 진열대를 다시 살펴보세요.",19,true)
    var row := _row(panel)
    row.add_child(_button("다시 도전",func(): _start_level(level_index),Color("d2eadb")))
    row.add_child(_button("12판 선택",func(): screen="levels"; render()))

func _ending() -> void:
    var total:=0
    for s in stars: total+=int(s)
    _add(panel,"★  열두 번의 종소리  ★",34,true)
    _add(panel,"동네의 모든 주문을 배달했습니다! 별 %d / 36" % total,24,true)
    var row:=_row(panel)
    row.add_child(_button("레벨 다시 보기",func(): screen="levels"; render()))
    row.add_child(_button("처음으로",func(): screen="home"; render()))

func _pause() -> void:
    _add(panel,"Ⅱ  잠시 쉬는 중",29,true)
    _settings()
    var row:=_row(panel)
    row.add_child(_button("계속하기",func(): screen="tutorial" if paused else "game"; render()))
    row.add_child(_button("제목으로",func(): screen="home"; render()))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is not InputEventKey or not event.pressed or event.echo: return
    if event.keycode==KEY_ESCAPE:
        if screen=="game" or screen=="tutorial":
            paused = screen=="tutorial"
            screen="pause"; render()
        elif screen=="pause": screen="tutorial" if paused else "game"; render()
        get_viewport().set_input_as_handled()
    elif screen=="game" or screen=="tutorial":
        if event.keycode==KEY_Z: _undo(); get_viewport().set_input_as_handled()
        elif event.keycode==KEY_Y: _redo(); get_viewport().set_input_as_handled()
        elif event.keycode==KEY_R: _reset(); get_viewport().set_input_as_handled()
