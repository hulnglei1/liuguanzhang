"""有头模式 + MCP-Bridge 驱动：用**真实鼠标/键盘事件**模拟玩家打法，各打一遍第一关。

和 tests/probe_player_styles.gd 的区别：
  那个是 headless、进程内直接调函数；这个是**真实窗口** + 走 JSON-RPC 桥接发真实输入事件
  （Input.parse_input_event → 与玩家手点完全同一条链路），并抓真实画面截图。

玩家操作流程（和真人一致）：
  点我方单位选中 → 点绿格移动 → 再点自己弹命令菜单 → 点「⚔️ 普通攻击」/「✨ 绝技」 → 点目标

用法：
  python tools/mcp_play_styles.py [风格名 ...]
  不带参数 = 跑 4 种常规风格。
"""
import json
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(r"D:\huanglei\deepseek\game")
EXE = ROOT / ".tools" / "godot_extracted" / "Godot_v4.7.2-stable_win64.exe"
PROJ = ROOT / "zcode项目"
OUT = ROOT / ".tools" / "tmp"
SHOTS = OUT / "mcp_shots"
GAME_SHOT = PROJ / "screenshots" / "agent_view.png"

MAX_TURNS = 20
PROVOKE_TURNS = 10
ALL_STYLES = ["莽夫型", "技能流", "龟缩型", "精准型", "拖延型", "单核型", "送头型"]

DIRS4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
DIRS8 = DIRS4 + [(1, 1), (1, -1), (-1, 1), (-1, -1)]

SETTLE = 0.35        # 每次点击后让游戏把演出/状态跑完


# ---------------- 桥接 ----------------

class Bridge:
    def __init__(self, timeout=25.0):
        self.sock = socket.create_connection(("127.0.0.1", 9099), timeout=10)
        self.timeout = timeout
        self._id = 0

    def call(self, method, **params):
        self._id += 1
        req = {"jsonrpc": "2.0", "id": self._id, "method": method, "params": params}
        self.sock.sendall((json.dumps(req) + "\n").encode("utf-8"))
        self.sock.settimeout(self.timeout)
        buf = b""
        deadline = time.time() + self.timeout
        while b"\n" not in buf and time.time() < deadline:
            chunk = self.sock.recv(1 << 20)
            if not chunk:
                break
            buf += chunk
        line = buf.split(b"\n")[0].decode("utf-8", "replace")
        if not line.strip():
            return {"error": "empty"}
        try:
            return json.loads(line).get("result", {})
        except Exception as e:
            return {"error": str(e), "raw": line[:200]}

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


# ---------------- 状态读取 ----------------

def state(br):
    return br.call("get_battle_state")


def in_battle(st):
    return "units" in st


def unit(st, uid):
    for u in st.get("units", []):
        if u["id"] == uid:
            return u
    return None


def unit_at_cell(st, cell):
    for u in st.get("units", []):
        if u["cell"][0] == cell[0] and u["cell"][1] == cell[1]:
            return u
    return None


def px_of(st, cell):
    off = st["grid_offset"]
    t = float(st["tile"])
    return off[0] + cell[0] * t + t / 2.0, off[1] + cell[1] * t + t / 2.0


def dist(a, b):
    return abs(a["cell"][0] - b["cell"][0]) + abs(a["cell"][1] - b["cell"][1])


def adjacent(a, b):
    return dist(a, b) == 1


def occupied(st, cell):
    if unit_at_cell(st, cell):
        return True
    for g in st.get("gates", []):
        if g[0] == cell[0] and g[1] == cell[1]:
            return True
    return False


# ---------------- 真实输入 ----------------

RIGHT = 2


def click_cell(br, st, cell, button=1):
    x, y = px_of(st, cell)
    br.call("click_coord", x=x, y=y, button=button)
    time.sleep(SETTLE)


def click_at(br, x, y, button=1):
    br.call("click_coord", x=x, y=y, button=button)
    time.sleep(SETTLE)


def right_click(br, st, cell):
    click_cell(br, st, cell, RIGHT)


def press(br, key="space"):
    br.call("press_key", key=key)
    time.sleep(0.25)


def query(br, text, cls="Button"):
    """只在 Button 里找 —— 仪表盘上的说明文字也含"待机""✨"，不加过滤会点错"""
    r = br.call("query_node_coord", query=text, class_filter=cls)
    return r if r.get("found") else None


def click_text(br, text):
    r = query(br, text)
    if not r or not r.get("center"):
        return False
    click_at(br, r["center"][0], r["center"][1])
    return True


def shot(br, name):
    br.call("capture_screenshot")
    if GAME_SHOT.exists():
        dst = SHOTS / name
        dst.write_bytes(GAME_SHOT.read_bytes())
        return dst
    return None


# ---------------- 玩家动作 ----------------

def open_menu(br, st, u, log):
    """点自己选中 → 再点自己弹出命令菜单（玩家真实的两步操作）"""
    click_cell(br, st, u["cell"])
    if query(br, "待机") or query(br, "✨"):
        return state(br)
    click_cell(br, state(br), u["cell"])
    return state(br)


def menu_button(br, text):
    r = query(br, text)
    if not r or r.get("disabled"):
        return None
    return r


def push_menu_button(br, text):
    r = menu_button(br, text)
    if r is None:
        return False
    click_at(br, r["center"][0], r["center"][1])
    return True


def do_wait(br, st, u, log):
    open_menu(br, st, u, log)
    if not push_menu_button(br, "待机"):
        push_menu_button(br, "撤回")
    log.append("%s 待机" % u["name"])


def do_skill(br, st, u, sk):
    """点「✨」按钮放技能；返回 True 表示确实出手了"""
    r = menu_button(br, "✨")
    if r is None:
        return False
    click_at(br, r["center"][0], r["center"][1])
    st2 = state(br)
    if sk == "roar":
        for _ in range(3):
            press(br, "space")
        time.sleep(1.3)          # 停手 0.9 秒自动出手
        return True
    if sk == "arrow_rain":
        t = nearest(st2, u)
        if t is None:
            return False
        click_cell(br, st2, t["cell"])
        return True
    if sk == "dragon_slash":
        adj = None
        for d in DIRS4:
            e = unit_at_cell(st2, (u["cell"][0] + d[0], u["cell"][1] + d[1]))
            if e and e["camp"] != u["camp"]:
                adj = e
                break
        if adj is None:
            return False
        click_cell(br, st2, adj["cell"])
        return True
    return False


def try_attack_someone(br, st, u, log):
    """真实玩家的攻击流程：菜单里点「⚔️ 普通攻击」→ 挨个点候选目标，点到生效为止。

    关键：**"能不能打到"由游戏自己判定**（菜单按钮的 disabled 状态 + 点上去是否有反应），
    不在驱动脚本里猜。之前用"曼哈顿距离==1"当攻击范围，漏掉了远程单位 →
    龟缩型的公孙瓒从头到尾一箭没放，误判成"打不过"。
    """
    st = open_menu(br, st, u, log)
    if query(br, "普通攻击") is None:
        return False
    if not push_menu_button(br, "普通攻击"):
        return False                       # 按钮禁用 = 当前射程内没有目标
    st2 = state(br)
    es = sorted(enemies(st2, u), key=lambda e: dist(u, e))
    for e in es[:5]:
        click_cell(br, st2, e["cell"])
        me = unit(state(br), u["id"])
        if me and me["acted"]:
            log.append("%s 攻击 %s（菜单）" % (u["name"], e["name"]))
            return True
    right_click(br, st2, u["cell"])        # 一个都打不到：右键取消，交给调用方去走位
    return False


def attack(br, st, u, t, log):
    """对指定目标发起攻击（先菜单点按钮，再点目标）"""
    st2 = open_menu(br, st, u, log)
    r = menu_button(br, "普通攻击")
    if r is not None:
        click_at(br, r["center"][0], r["center"][1])
        st3 = state(br)
        t3 = unit(st3, t["id"]) or t
        click_cell(br, st3, t3["cell"])
        log.append("%s 攻击 %s（菜单）" % (u["name"], t["name"]))
        return
    t2 = unit(st2, t["id"]) or t
    click_cell(br, st2, t2["cell"])
    log.append("%s 攻击 %s（直接点）" % (u["name"], t["name"]))


def enemies(st, u):
    return [e for e in st.get("units", []) if e["camp"] != u["camp"]]


def nearest(st, u):
    es = enemies(st, u)
    if not es:
        return None
    best = es[0]
    for e in es:
        if dist(u, e) < dist(u, best):
            best = e
    return best


def pick_target(st, u, style, turn):
    es = enemies(st, u)
    if not es:
        return None
    if style == "拖延型" and turn <= PROVOKE_TURNS:
        ms = [e for e in es if not e.get("commander")]
        if ms:
            es = ms
    if style == "精准型":
        best = es[0]
        for e in es:
            if e["hp"] < best["hp"]:
                best = e
        return best
    best = es[0]
    for e in es:
        if dist(u, e) < dist(u, best):
            best = e
    return best


def move_candidates(st, u, goal_cell):
    cands = []
    for d in DIRS8:
        c = (u["cell"][0] + d[0], u["cell"][1] + d[1])
        if c[0] < 0 or c[1] < 0 or c[0] >= st["map"][0] or c[1] >= st["map"][1]:
            continue
        if occupied(st, c):
            continue
        dd = abs(c[0] - goal_cell[0]) + abs(c[1] - goal_cell[1])
        cands.append((dd, c))
    cands.sort(key=lambda x: x[0])
    return [c for _, c in cands]


def try_move(br, st, u, goal_cell):
    """尝试走一步靠近目标；成功返回新状态，全失败返回 None"""
    click_cell(br, st, u["cell"])          # 确保单位是选中态（上一次右键可能已取消选择）
    st = state(br)
    for cand in move_candidates(st, u, goal_cell)[:5]:
        click_cell(br, st, cand)
        st2 = state(br)
        me = unit(st2, u["id"])
        if me and me["cell"] != u["cell"]:
            return st2
    return None


def back_to_menu(br, limit=60):
    """回主菜单：先按空格把胜利/失败对白推完，结算面板才会出现「返回主城 🏰」"""
    for _ in range(limit):
        st = state(br)
        if not in_battle(st):
            return True
        if st.get("dialog_showing"):
            press(br, "space")
            continue
        if click_text(br, "返回主城"):
            time.sleep(1.5)
            continue
        if click_text(br, "返回"):
            time.sleep(1.5)
            continue
        press(br, "space")          # 结算演出可能还要按一下
        time.sleep(0.5)
    return not in_battle(state(br))


# ---------------- 一个风格打一局 ----------------

def play_style(br, style):
    log = []
    if not back_to_menu(br):
        return {"style": style, "win": False, "turns": 0, "note": "  ← 无法回到主菜单"}

    if not click_text(br, "btn_chapter1"):
        click_text(br, "进军出征")
    time.sleep(2.0)

    for _ in range(40):                     # 序章 / 开场对白
        st = state(br)
        if in_battle(st) and not st.get("dialog_showing"):
            break
        press(br, "space")
    st = state(br)
    if not in_battle(st):
        return {"style": style, "win": False, "turns": 0, "note": "  ← 未能进入战斗"}
    shot(br, "battle_%s.png" % style)

    sacrifice_done = False
    turn = 0
    while turn < MAX_TURNS:
        st = state(br)
        if st.get("victory") or st.get("defeat"):
            break
        turn += 1
        stuck = {}
        for _ in range(16):
            st = state(br)
            if st.get("victory") or st.get("defeat"):
                break
            actors = [u for u in st.get("units", [])
                      if u["camp"] == "player" and not u["acted"] and u["stun"] == 0]
            if not actors:
                break
            u = actors[0]
            act(br, st, u, style, turn, log, sacrifice_done)
            st_after = state(br)
            after_u = unit(st_after, u["id"])
            if after_u and not after_u["acted"]:
                stuck[u["id"]] = stuck.get(u["id"], 0) + 1
                if stuck[u["id"]] >= 3:
                    do_wait(br, st_after, after_u, log)
                    log.append("⚠ %s 连续 3 次动作未生效，强制待机" % after_u["name"])
                    u2 = unit(state(br), u["id"])
                    if u2 and not u2["acted"]:
                        log.append("⚠ %s 连待机都点不动 → 本回合放弃" % u2["name"])
                        break
        if style == "送头型" and not sacrifice_done:
            st = state(br)
            if not [x for x in st.get("units", []) if x["id"].startswith("yi_bing")]:
                sacrifice_done = True
                log.append("★ 义军全部战死 → 转正常打法")
        st = state(br)
        if st.get("victory") or st.get("defeat"):
            break
        press(br, "space")                  # 第一次：有未行动者会警告
        press(br, "space")                  # 第二次：确认结束回合
        time.sleep(1.6)
        for _ in range(12):
            st = state(br)
            if not st.get("dialog_showing"):
                break
            press(br, "space")
        if style in ("拖延型", "送头型") and turn % 5 == 0:
            hx = unit(state(br), "huaxiong")
            if hx:
                log.append("[华雄] 第 %d 回合：HP %d" % (turn, hx["hp"]))

    st = state(br)
    win = bool(st.get("victory"))
    if win:
        shot(br, "victory_%s.png" % style)
    return {"style": style, "win": win, "turns": turn, "log": log,
            "must_win": style != "单核型"}


def act(br, st, u, style, turn, log, sacrifice_done):
    click_cell(br, st, u["cell"])
    st = state(br)

    if st.get("stage_idx") == 1 and u["id"] == "guanyu":     # 阶段 2：劈城门
        return breach(br, st, u, log)
    if style == "单核型" and u["id"] != "guanyu":
        return do_wait(br, st, u, log)
    if style == "送头型" and not sacrifice_done and u["id"].startswith("yi_bing"):
        return sacrifice(br, st, u, log)

    if style == "技能流" and u.get("skills"):                  # 有技能就放
        sk = str(u["skills"][0])
        st2 = open_menu(br, st, u, log)
        if u["id"] == "guanyu" and u.get("charge", 0) < 5:
            sk = ""
        if sk and do_skill(br, st2, u, sk):
            log.append("%s 放技能 %s" % (u["name"], sk))
            return
        st = state(br)

    # 龟缩型：不主动移动 —— 先问游戏"现在能打谁"
    if style == "龟缩型":
        if try_attack_someone(br, st, u, log):
            return
        return do_wait(br, state(br), u, log)

    # 其他风格：先试原地打，打不到就走位，再试一次
    if try_attack_someone(br, st, u, log):
        return
    st = state(br)
    t = pick_target(st, u, style, turn)
    if t is None:
        return do_wait(br, st, u, log)
    st2 = try_move(br, st, u, t["cell"])
    if st2 is None:
        return do_wait(br, st, u, log)
    if try_attack_someone(br, st2, u, log):
        return
    do_wait(br, state(br), u, log)


def breach(br, st, u, log):
    """关羽：先跑动蓄到 10 格，再站到 y=4 那行劈城门"""
    gy = unit(st, "guanyu") or u
    if gy.get("charge", 0) < 10:
        goal = (0, 4) if gy["cell"][0] > 4 else (9, 4)
        st2 = try_move(br, st, gy, goal)
        if st2 is not None:
            me = unit(st2, "guanyu")
            log.append("关羽跑动蓄力 %s/10" % (me.get("charge", 0) if me else "?"))
            return
        return do_wait(br, st, gy, log)
    if gy["cell"][1] != 4:
        if try_move(br, st, gy, (gy["cell"][0], 4)) is not None:
            return
    st2 = open_menu(br, st, gy, log)
    r = menu_button(br, "✨")
    if r is None:
        return do_wait(br, st2, gy, log)
    click_at(br, r["center"][0], r["center"][1])
    st3 = state(br)
    gates = st3.get("gates", [])
    if gates:
        click_cell(br, st3, tuple(gates[0]))
        log.append("关羽劈向城门（蓄力 %s）" % gy.get("charge", 0))
    else:
        log.append("⚠ 找不到城门格")


def sacrifice(br, st, u, log):
    hx = unit(st, "huaxiong")
    if hx is None:
        return do_wait(br, st, u, log)
    if adjacent(u, hx):
        log.append("%s 站在华雄面前挨打（送头）" % u["name"])
        return do_wait(br, st, u, log)
    if try_move(br, st, u, hx["cell"]) is not None:
        log.append("%s 逼近华雄" % u["name"])
        return
    do_wait(br, st, u, log)


# ---------------- 主流程 ----------------

def launch():
    """每个风格都新开一个游戏进程：
    一局打完/打不完都能干净收场，不用依赖"从结算面板点回主菜单"这条脆弱路径。"""
    logf = open(OUT / "mcp_play.log", "a", encoding="utf-8", errors="replace")
    proc = subprocess.Popen([str(EXE), "--path", str(PROJ)],
                            stdout=logf, stderr=subprocess.STDOUT)
    time.sleep(9)
    br = Bridge()
    return proc, br, logf


def main():
    styles = sys.argv[1:] or ALL_STYLES[:4]
    SHOTS.mkdir(parents=True, exist_ok=True)
    (OUT / "mcp_play.log").write_text("", encoding="utf-8")

    results = []
    crashed = 0
    bad = 0
    for style in styles:
        proc, br, logf = launch()
        print("\n---- 玩家风格：%s ----（游戏进程 pid=%d，真实窗口 + 真实输入）" % (style, proc.pid))
        try:
            r = play_style(br, style)
        except Exception as e:
            crashed += 1
            print("  [!] 驱动脚本异常：%s" % e)
            r = {"style": style, "win": False, "turns": 0,
                 "note": "  ← 驱动异常：%s" % e, "must_win": False}
        finally:
            try:
                br.close()
            except Exception:
                pass
            if proc.poll() is None:
                proc.kill()
            logf.close()
        for l in r.get("log", []):
            print("      " + l)
        print("  → %s（%d 回合）%s" % ("通关 ✅" if r["win"] else "未通关 ❌",
                                      r["turns"], r.get("note", "")))
        results.append(r)

    print("\n===== 汇总（有头窗口 + MCP 真实点击）=====")
    for r in results:
        print("  %-6s %s（%d 回合）" % (r["style"], "通关 ✅" if r["win"] else "未通关 ❌", r["turns"]))
        if not r["win"] and r.get("must_win", True):
            bad += 1
    if crashed:
        print("  ⚠ 有 %d 个风格因驱动脚本异常未跑完" % crashed)
    print("  结论：%s" % ("各打法均可通关 ✅" if bad == 0 and crashed == 0
                        else "有 %d 种打法未通关 ❌" % bad))
    return 0 if bad == 0 and crashed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
