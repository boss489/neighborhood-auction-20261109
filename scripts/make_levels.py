"""Deterministic hand-authored scenarios; BFS certifies their optimal swap counts."""
import json
from collections import deque
from pathlib import Path

# Price belongs to an item, never to a position. Each tuple is a designed
# target ring, an initial ring, and 2-4 explicitly authored order cards.
SCENARIOS = [
    ([0,1,2,3], [0,2,1,3], [('near',0,1),('sum',0,10)]),
    ([0,1,2,3], [0,2,1,3], [('apart',0,2),('near',1,2)]),
    ([0,1,2,3], [2,0,3,1], [('near',0,1),('near',2,3),('sum',1,7)]),
    ([0,1,2,3], [1,3,0,2], [('apart',0,2),('sum',0,10),('near',1,2)]),
    ([0,1,2,3,4], [2,0,4,1,3], [('near',0,1),('apart',0,2),('sum',3,11)]),
    ([0,1,2,3,4], [4,1,3,0,2], [('near',1,2),('apart',1,3),('sum',4,9)]),
    ([0,1,2,3,4], [1,4,2,0,3], [('near',3,4),('apart',0,3),('sum',0,9),('near',1,2)]),
    ([0,1,2,3,4], [3,0,4,2,1], [('apart',0,2),('near',0,4),('sum',2,10),('near',1,2)]),
    ([0,1,2,3,4,5], [3,0,5,2,4,1], [('near',0,1),('apart',0,3),('sum',2,10),('near',4,5)]),
    ([0,1,2,3,4,5], [2,4,0,5,1,3], [('apart',1,4),('near',2,3),('sum',0,7),('near',4,5)]),
    ([0,1,2,3,4,5], [5,2,4,0,3,1], [('near',0,5),('apart',0,2),('sum',3,11),('near',1,2)]),
    ([0,1,2,3,4,5], [1,3,5,0,2,4], [('apart',1,4),('near',3,4),('sum',5,8),('near',0,1)]),
]
PRICES = [2, 3, 5, 7, 6, 4]


def evaluate(ring, cards):
    n = len(ring)
    def near(a,b):
        d = abs(ring.index(a)-ring.index(b))
        return d == 1 or d == n-1
    result = []
    for kind,a,b in cards:
        if kind == 'near': result.append(near(a,b))
        elif kind == 'apart': result.append(not near(a,b))
        else:
            i = ring.index(a)
            result.append(PRICES[ring[(i-1)%n]] + PRICES[ring[(i+1)%n]] == b)
    return result


def min_swaps(start,cards):
    q = deque([(tuple(start),0)])
    seen = {tuple(start)}
    while q:
        ring, depth = q.popleft()
        if all(evaluate(list(ring),cards)): return depth
        for i in range(len(ring)):
            for j in range(i+1,len(ring)):
                nxt=list(ring); nxt[i],nxt[j]=nxt[j],nxt[i]
                nxt=tuple(nxt)
                if nxt not in seen:
                    seen.add(nxt); q.append((nxt,depth+1))
    return None


def main():
    levels=[]
    for idx,(target,start,cards) in enumerate(SCENARIOS):
        assert sorted(start)==target
        assert all(evaluate(target,cards)), (idx,target,cards)
        assert not all(evaluate(start,cards)), idx
        optimal=min_swaps(start,cards)
        assert optimal is not None and optimal>0
        levels.append({'name': ['첫 종소리','서로 떨어져','이중 주문','가격의 비밀','다섯 자리','모서리 손님','엇갈린 주문','고리의 끝','여섯 상인','우회 거래','복잡한 오후','마지막 경매'][idx], 'start': start, 'cards': [list(c) for c in cards], 'optimal': optimal})
        print(f'{idx+1:02} items={len(start)} cards={len(cards)} optimal={optimal}')
    out=Path(__file__).resolve().parents[1]/'levels.json'
    out.write_text(json.dumps(levels,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert len(levels)==12

if __name__ == '__main__': main()
