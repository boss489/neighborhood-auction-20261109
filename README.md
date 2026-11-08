# 이웃 경매판 / Neighborhood Auction

Godot 4.7 독립 웹 퍼즐. **12개의 고정 수제 주문**에서 원형 진열대의 두 물건을 선택해 교환하고 모든 카드를 동시에 만족시키세요. 첫 칸과 마지막 칸은 이웃입니다. 가격은 물건에 붙어 이동합니다.

- 조작: 마우스/터치 두 번 선택; Tab/Enter 또는 Space로 버튼 탐색·선택; Z 취소, Y 다시, R 리셋, Esc 일시정지.
- 제목 → 두 단계 학습 → 12레벨 → 별·결과 → 완주. 저장은 브라우저 로컬 `user://auction.cfg`이며 계정/서버 없음.
- 초록 ✓/주황 !로 조건을 중복 표기. 고대비·움직임 축소·음소거 설정.
- 모든 12레벨 시작 위치와 카드 조건은 `scripts/make_levels.py`에서 고정 정의. BFS로 최소 교환 수를 인증하고 `levels.json`을 생성합니다.

## 개발·시험

```sh
python3 scripts/make_levels.py
godot --headless --editor --path . --quit
godot --headless --path . --script tests/game_test.gd
godot --headless --path . --export-release Web docs/index.html
```

Pages는 `main` 브랜치 `/docs`에서 제공하며 Web export의 `.html`, `.js`, `.wasm`, `.pck`을 배포합니다. 웹 서버로 열어야 합니다(`file://` 불가).

## 자산과 라이선스

진열대·카드·물건 모양은 GDScript로 직접 그린 자작 도형이며 종소리는 런타임에서 자체 합성합니다. Noto Sans KR 글꼴만 제3자 자산으로 사용하며 `assets/OFL.txt`에 SIL Open Font License를 함께 싣습니다. 다른 외부 아트·음원 없음.
