from playwright.sync_api import sync_playwright
from pathlib import Path
import os
root=Path(__file__).resolve().parents[1] / 'evidence'
root.mkdir(exist_ok=True)
base_url=os.environ.get('AUCTION_URL','http://127.0.0.1:18876/')
with sync_playwright() as p:
    b=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader'])
    for label,width,height,click in [('desktop',900,840,(180,220)),('mobile',390,844,(105,330))]:
        page=b.new_page(viewport={'width':width,'height':height},device_scale_factor=1,is_mobile=label=='mobile',has_touch=label=='mobile')
        def press(xy):
            if label=='mobile': page.touchscreen.tap(*xy)
            else: page.mouse.click(*xy)
        errs=[]; page.on('pageerror',lambda e: errs.append(str(e)))
        page.goto(base_url,wait_until='domcontentloaded'); page.wait_for_timeout(4500)
        page.screenshot(path=str(root/f'{label}-home.png'))
        press(click); page.wait_for_timeout(400)
        path=root/f'{label}-tutorial.png'; page.screenshot(path=str(path))
        coords=[(562,402),(446,520)] if label=='desktop' else [(292,412),(191,515)]
        for xy in coords: press(xy); page.wait_for_timeout(250)
        path=root/f'{label}-tutorial-win.png'; page.screenshot(path=str(path))
        coords=[(446,285),(328,402)] if label=='desktop' else [(191,310),(89,412)]
        for xy in coords: press(xy); page.wait_for_timeout(250)
        path=root/f'{label}-tutorial-complete.png'; page.screenshot(path=str(path))
        press((452,220) if label=='desktop' else (291,329)); page.wait_for_timeout(250)
        path=root/f'{label}-level1.png'; page.screenshot(path=str(path))
        coords=[(562,365),(446,480)] if label=='desktop' else [(292,344),(191,444)]
        for xy in coords: press(xy); page.wait_for_timeout(250)
        path=root/f'{label}-level1-win.png'; page.screenshot(path=str(path))
        press((197,340) if label=='desktop' else (68,375)); page.wait_for_timeout(350)
        path=root/f'{label}-level2.png'; page.screenshot(path=str(path))
        page.keyboard.press('r'); page.wait_for_timeout(300)
        path=root/f'{label}-restart.png'; page.screenshot(path=str(path))
        page.keyboard.press('Escape'); page.wait_for_timeout(300)
        path=root/f'{label}-pause.png'; page.screenshot(path=str(path))
        press((680,250) if label=='desktop' else (285,248)); page.wait_for_timeout(600)
        page.reload(); page.wait_for_timeout(3000)
        path=root/f'{label}-saved-home.png'; page.screenshot(path=str(path))
        press((452,220) if label=='desktop' else (291,329)); page.wait_for_timeout(300)
        for _ in range(6):
            for xy in ([(446,248),(562,365)] if label=='desktop' else [(191,248),(292,365)]):
                press(xy); page.wait_for_timeout(100)
        path=root/f'{label}-loss.png'; page.screenshot(path=str(path))
        print(label,'touch' if label=='mobile' else 'mouse','tutorial/win/next/restart/pause/reload/loss screenshots',root,'page errors',errs,flush=True)
        if errs: raise AssertionError(errs)
        page.close()
    b.close()
