extends SceneTree

const G = preload("res://main.gd")
var count := 0
var failed := false

func check(value: bool, description: String) -> void:
    if not value:
        push_error("FAIL: " + description)
        failed = true
        return
    count += 1

func _initialize() -> void:
    call_deferred("run")

func solve_path(start: Array, cards: Array) -> Array:
    var queue: Array = [[start.duplicate(),[]]]
    var seen := {str(start):true}
    var pos := 0
    while pos < queue.size():
        var node: Array = queue[pos]
        pos+=1
        var ring: Array = node[0]
        if G.solved(ring,cards): return node[1]
        for i in range(ring.size()):
            for j in range(i+1,ring.size()):
                var next := ring.duplicate()
                var temp = next[i]; next[i]=next[j]; next[j]=temp
                var key := str(next)
                if not seen.has(key):
                    seen[key]=true
                    var steps: Array = node[1].duplicate()
                    steps.append([i,j])
                    queue.append([next,steps])
    return []

func run() -> void:
    check(G.adjacent(0,3,4),"circular end adjacency")
    check(not G.adjacent(0,2,4),"opposite not adjacent")
    check(G.evaluate([0,1,2,3],[["sum",0,10]])[0],"neighbor price sum")
    check(not G.evaluate([0,2,1,3],[["near",0,1]])[0],"red neighbor card")
    var scene := load("res://main.tscn")
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    check(game.levels.size()==12,"12 levels")
    var missing: Array = []
    var glyphs := FileAccess.get_file_as_string("res://main.gd") + FileAccess.get_file_as_string("res://levels.json")
    for c in glyphs:
        if c.unicode_at(0)>127 and not game.ui_font.has_char(c.unicode_at(0)) and not missing.has(c): missing.append(c)
    print("FONT missing glyphs: ",missing)
    check(missing.is_empty(),"Korean/UI glyph coverage")
    var save_path := "user://auction.cfg"
    var backup := ""
    if FileAccess.file_exists(save_path):
        backup=FileAccess.get_file_as_string(save_path)
    game.stars.fill(0); game.unlocked=0
    for k in range(12):
        var level: Dictionary = game.levels[k]
        var path := solve_path(level.start, level.cards)
        check(not path.is_empty(),"solvable level %d" % k)
        check(path.size()==int(level.optimal),"optimal BFS level %d" % k)
        check(not G.solved(level.start,level.cards),"unsolved start %d" % k)
        game._start_level(k)
        check(game.screen=="game","level selectable %d" % k)
        var old: Array = game.ring.duplicate()
        game._select(path[0][0]); game._select(path[0][1])
        if game.screen=="game":
            var changed: Array = game.ring.duplicate()
            game._undo()
            check(game.ring==old,"undo %d" % k)
            game._redo()
            check(game.ring==changed,"redo %d" % k)
        for step in path.slice(1):
            game._select(step[0]); game._select(step[1])
        check(game.screen=="win","victory %d" % k)
        check(int(game.stars[k])==3,"optimal stars %d" % k)
        game._load_save()
        check(int(game.stars[k])==3,"save restore %d" % k)
    game.screen="ending"; game.render()
    check(game.stars.count(3)==12,"full completion")
    game._start_level(0)
    game.moves=int(game.levels[0]["optimal"])+4
    var bad_pair := []
    for i in range(game.ring.size()):
        for j in range(i+1,game.ring.size()):
            var candidate: Array = game.ring.duplicate()
            var temp = candidate[i]; candidate[i]=candidate[j]; candidate[j]=temp
            if not G.solved(candidate,game.cards): bad_pair=[i,j]; break
        if not bad_pair.is_empty(): break
    check(not bad_pair.is_empty(),"failure candidate exists")
    game._select(bad_pair[0]); game._select(bad_pair[1])
    check(game.screen=="loss","move limit failure")
    game._reset()
    check(game.screen=="game" and game.moves==0,"failure retry")
    game._start_tutorial(0)
    check(game.screen=="tutorial","tutorial one")
    game._select(1); game._select(2)
    check(game.screen=="tutorial" and game.tutorial_index==1,"tutorial transition")
    var tutorial_path := solve_path(game.ring,game.cards)
    for step in tutorial_path:
        game._select(step[0]); game._select(step[1])
    check(game.screen=="home","tutorial completed")
    game._start_level(0)
    game._reset()
    check(game.moves==0,"reset")
    game.high_contrast=true; game.muted=true; game.reduced_motion=true; game._save()
    game.high_contrast=false; game.muted=false; game.reduced_motion=false
    game._load_save()
    check(game.high_contrast and game.muted and game.reduced_motion,"settings restore")
    if backup.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    else:
        var restore := FileAccess.open(save_path,FileAccess.WRITE)
        restore.store_string(backup)
    game.queue_free()
    await process_frame
    if not failed: print("PASS %d assertions / 12 BFS levels / UI transitions / save" % count)
    quit(1 if failed else 0)
