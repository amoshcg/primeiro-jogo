require "palette"
require "sprites"

-- ===================================================================
-- Trump's Run - corrida 2D pelos EUA
-- O personagem corre sozinho: CIMA/Z pula, BAIXO/X desliza.
-- Colete Green Cards e nao deixe o Trump te alcancar!
-- ===================================================================

local GROUND = 222      -- linha do chao (pes do personagem)
local TILE = 48         -- cada caractere do mapa ocupa 48 px
local PLAYER_X = 170    -- posicao do personagem na tela
local GRAV = 0.5
local JUMP_V = -8.6
local SLIDE_T = 32      -- duracao do deslize em frames
local FONT_W = 6        -- largura aproximada de um caractere

-- Cores (paleta DB32)
local cache = {}
local function C(hex)
    local c = cache[hex]
    if not c then
        c = Palette.hex(hex)
        cache[hex] = c
    end
    return c
end

local flr = math.floor

-- ===================================================================
-- Mapa estatico dos EUA (de leste a oeste)
--   .  vazio
--   b  barreira (pular)
--   h  placa suspensa (deslizar)
--   c  green card no chao
--   a  green card no alto (pular para pegar)
--   B  barreira com green card em cima
-- ===================================================================
local REGIONS = {
    { name = "NEW YORK",      sky = 0x639bff, map = "......c.c.c....b....c.c.c...h....b..a." },
    { name = "WASHINGTON DC", sky = 0x5fcde4, map = "..h...ccc...b...h...B....a.a...h..b.." },
    { name = "TEXAS",         sky = 0xd9a066, map = "..b..b...ccc..h..h...B...b..a..h..cc." },
    { name = "LAS VEGAS",     sky = 0x222034, map = ".h..b..ccc..h..B..h...b..b..a.a..h..." },
    { name = "HOLLYWOOD",     sky = 0xdf7126, map = "..b..h..ccc..B..h..b..h...b..ccc......" },
}

local obstacles = {}
local cards = {}
local FINISH = 0

local function build_map()
    obstacles, cards = {}, {}
    local tile = 0
    for r, reg in ipairs(REGIONS) do
        reg.start = tile * TILE
        for i = 1, #reg.map do
            local ch = reg.map:sub(i, i)
            local x = tile * TILE + 12
            if ch == "b" or ch == "B" then
                obstacles[#obstacles + 1] = { x = x, kind = "b", hit = false }
            elseif ch == "h" then
                obstacles[#obstacles + 1] = { x = x, kind = "h", hit = false }
            end
            if ch == "c" then
                cards[#cards + 1] = { x = x + 8, y = GROUND - 12, got = false }
            elseif ch == "a" then
                cards[#cards + 1] = { x = x + 8, y = GROUND - 72, got = false }
            elseif ch == "B" then
                cards[#cards + 1] = { x = x + 9, y = GROUND - 58, got = false }
            end
            tile = tile + 1
        end
    end
    FINISH = tile * TILE + 120
end

local function region_at(x)
    local cur = 1
    for i, reg in ipairs(REGIONS) do
        if x >= reg.start then cur = i end
    end
    return cur
end

-- ===================================================================
-- Estado do jogo
-- ===================================================================
local state = "title"
local p = {}
local trump = {}
local collected = 0
local endT = 0

local function reset()
    build_map()
    p = { x = 0, y = GROUND, vy = 0, onground = true, slide = 0,
          fastfall = false, stumble = 0, inv = 0 }
    trump = { gap = 1.0, sx = 0 }
    collected = 0
    endT = 0
end

reset()

local function player_box()
    if p.slide > 0 then
        return p.x, p.y - 12, p.x + 22, p.y
    end
    return p.x, p.y - 26, p.x + 12, p.y
end

local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
    return ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0
end

-- ===================================================================
-- Logica
-- ===================================================================
local function update_run()
    local spd = 3 + (p.x / FINISH) * 1.5
    if p.stumble > 0 then
        spd = spd * 0.6
        p.stumble = p.stumble - 1
    end
    p.x = p.x + spd

    local jump = ui.btnp(UP) or ui.btnp(BTN_Z)
    local slide = ui.btnp(DOWN) or ui.btnp(BTN_X)

    if jump and p.onground then
        p.vy = JUMP_V
        p.onground = false
        p.slide = 0
    end
    if slide then
        if p.onground then
            p.slide = SLIDE_T
        else
            -- no ar: desce rapido e desliza ao tocar o chao
            p.vy = math.max(p.vy, 7)
            p.fastfall = true
        end
    end

    if not p.onground then
        p.vy = p.vy + GRAV
        p.y = p.y + p.vy
        if p.y >= GROUND then
            p.y = GROUND
            p.vy = 0
            p.onground = true
            if p.fastfall then p.slide = SLIDE_T end
            p.fastfall = false
        end
    end
    if p.slide > 0 then p.slide = p.slide - 1 end
    if p.inv > 0 then p.inv = p.inv - 1 end

    -- colisao com obstaculos
    local x0, y0, x1, y1 = player_box()
    for _, o in ipairs(obstacles) do
        if not o.hit and o.x < x1 + 30 and o.x > x0 - 40 then
            local hit
            if o.kind == "b" then
                hit = overlap(x0, y0, x1, y1, o.x + 2, GROUND - 22, o.x + 16, GROUND)
            else
                hit = overlap(x0, y0, x1, y1, o.x, 0, o.x + 22, GROUND - 17)
            end
            if hit then
                o.hit = true
                if p.inv == 0 then
                    p.inv = 60
                    p.stumble = 40
                    trump.gap = trump.gap - 0.55
                    if trump.gap <= 0 then
                        state = "caught"
                        endT = 0
                    end
                end
            end
        end
    end

    -- coleta de green cards
    for _, c in ipairs(cards) do
        if not c.got and overlap(x0, y0, x1, y1, c.x - 8, c.y - 7, c.x + 8, c.y + 7) then
            c.got = true
            collected = collected + 1
        end
    end

    -- Trump recupera a distancia aos poucos
    trump.gap = math.min(1, trump.gap + 0.0015)

    if p.x >= FINISH then
        state = "win"
        endT = 0
    end
end

-- ===================================================================
-- Desenho
-- ===================================================================
local function cx(s) return flr(240 - #s * FONT_W / 2) end

local function draw_card(x, y)
    x, y = flr(x), flr(y)
    ui.rectfill(x - 7, y - 5, x + 7, y + 5, C(0x6abe30))
    ui.rect(x - 7, y - 5, x + 7, y + 5, C(0x37946e))
    ui.rectfill(x - 5, y - 3, x - 1, y + 2, C(0xcbdbfc))
    ui.line(x + 1, y - 2, x + 5, y - 2, C(0xffffff))
    ui.line(x + 1, y, x + 5, y, C(0xffffff))
    ui.line(x + 1, y + 2, x + 4, y + 2, C(0x4b692f))
end

local function draw_flag(x, y)
    ui.line(x, y, x, y + 30, C(0x847e87))
    for r = 0, 6 do
        local col = (r % 2 == 0) and C(0xac3232) or C(0xffffff)
        ui.rectfill(x + 1, y + r * 2, x + 20, y + r * 2 + 1, col)
    end
    ui.rectfill(x + 1, y, x + 9, y + 7, C(0x3f3f74))
    ui.print("*", x + 3, y + 1, C(0xffffff))
end

local function draw_landmark(r, x)
    local g = GROUND
    if r == 1 then
        -- Estatua da Liberdade
        ui.rectfill(x - 14, g - 40, x + 14, g, C(0x9badb7))
        ui.rectfill(x - 10, g - 46, x + 10, g - 40, C(0x847e87))
        ui.trisfill(x - 10, g - 46, x + 10, g - 46, x, g - 110, C(0x37946e))
        ui.circfill(x, g - 112, 6, C(0x37946e))
        ui.trisfill(x - 6, g - 116, x + 6, g - 116, x, g - 126, C(0x37946e))
        ui.rectfill(x + 6, g - 138, x + 9, g - 104, C(0x37946e))
        ui.circfill(x + 7, g - 142, 4, C(0xfbf236))
    elseif r == 2 then
        -- Monumento de Washington e Capitolio
        ui.rectfill(x - 6, g - 130, x + 6, g, C(0xcbdbfc))
        ui.trisfill(x - 6, g - 130, x + 6, g - 130, x, g - 145, C(0xcbdbfc))
        ui.rectfill(x + 40, g - 40, x + 120, g, C(0xffffff))
        ui.circfill(x + 80, g - 40, 22, C(0xffffff))
        ui.rectfill(x + 78, g - 72, x + 82, g - 60, C(0xffffff))
        for i = 0, 7 do
            ui.line(x + 46 + i * 10, g - 34, x + 46 + i * 10, g - 2, C(0x9badb7))
        end
    elseif r == 3 then
        -- Cactos e torre de petroleo
        for k = 0, 1 do
            local cxp = x + k * 90
            ui.rectfill(cxp - 4, g - 60, cxp + 4, g, C(0x4b692f))
            ui.rectfill(cxp - 16, g - 44, cxp - 4, g - 38, C(0x4b692f))
            ui.rectfill(cxp - 16, g - 58, cxp - 10, g - 38, C(0x4b692f))
            ui.rectfill(cxp + 4, g - 36, cxp + 14, g - 30, C(0x4b692f))
            ui.rectfill(cxp + 10, g - 50, cxp + 16, g - 30, C(0x4b692f))
        end
        ui.line(x + 150, g, x + 170, g - 90, C(0x222034))
        ui.line(x + 190, g, x + 170, g - 90, C(0x222034))
        ui.line(x + 156, g - 30, x + 184, g - 30, C(0x222034))
        ui.line(x + 162, g - 60, x + 178, g - 60, C(0x222034))
    elseif r == 4 then
        -- Cassinos de Las Vegas
        ui.rectfill(x - 20, g - 120, x + 20, g, C(0x76428a))
        ui.rectfill(x + 30, g - 80, x + 80, g, C(0x3f3f74))
        for yy = g - 112, g - 10, 12 do
            for xx = x - 14, x + 10, 8 do
                if flr((xx + yy) / 4) % 3 ~= 0 then
                    ui.rectfill(xx, yy, xx + 3, yy + 5, C(0xfbf236))
                end
            end
        end
        ui.rectfill(x + 34, g - 72, x + 76, g - 58, C(0xd77bba))
        ui.print("CASINO", x + 37, g - 69, C(0xffffff))
    else
        -- Colina com letreiro de Hollywood e palmeiras
        ui.circfill(x + 60, g + 40, 100, C(0x8f563b))
        ui.print("HOLLYWOOD", x + 32, g - 46, C(0xffffff))
        for k = 0, 1 do
            local px = x - 40 + k * 230
            ui.rectfill(px, g - 70, px + 3, g, C(0x8a6f30))
            ui.circfill(px - 8, g - 70, 8, C(0x4b692f))
            ui.circfill(px + 10, g - 70, 8, C(0x4b692f))
            ui.circfill(px + 1, g - 76, 7, C(0x6abe30))
        end
    end
end

local function draw_world(cam)
    local reg = region_at(cam + PLAYER_X)
    local sky = REGIONS[reg].sky
    ui.cls(C(sky))

    -- sol ou lua
    if reg == 4 then
        ui.circfill(420, 40, 14, C(0xcbdbfc))
        for i = 0, 25 do
            ui.rectfill((i * 97) % 480, (i * 53) % 150, (i * 97) % 480, (i * 53) % 150, C(0xffffff))
        end
    else
        ui.circfill(420, 40, 18, C(0xfbf236))
    end

    -- nuvens (parallax 0.2)
    if reg ~= 4 then
        local off = flr(cam * 0.2) % 600
        for i = 0, 3 do
            local x = i * 160 - off
            if x < -60 then x = x + 600 end
            local y = 30 + (i * 23) % 40
            ui.circfill(x, y, 10, C(0xffffff))
            ui.circfill(x + 12, y - 4, 12, C(0xffffff))
            ui.circfill(x + 26, y, 9, C(0xffffff))
        end
    end

    -- predios ao fundo (parallax 0.3)
    local bcam = cam * 0.3
    local k0 = flr(bcam / 40)
    local bcol = (reg == 4) and C(0x3f3f74) or C(0x9badb7)
    for k = k0, k0 + 13 do
        local h = 30 + (k * 37) % 60
        local x = flr(k * 40 - bcam)
        ui.rectfill(x, GROUND - h, x + 34, GROUND, bcol)
        for wy = GROUND - h + 6, GROUND - 10, 10 do
            ui.rectfill(x + 6, wy, x + 10, wy + 4, C(0xcbdbfc))
            ui.rectfill(x + 22, wy, x + 26, wy + 4, C(0xcbdbfc))
        end
    end

    -- pontos turisticos de cada estado (parallax 0.6)
    for r, rg in ipairs(REGIONS) do
        for _, off in ipairs({ 220, 760 }) do
            local x = flr(rg.start * 0.6 + off - cam * 0.6)
            if x > -260 and x < 740 then draw_landmark(r, x) end
        end
    end

    -- chao / estrada
    ui.rectfill(0, GROUND, 480, 270, C(0x595652))
    ui.rectfill(0, GROUND, 480, GROUND + 3, C(0x847e87))
    local d = flr(cam) % 40
    for i = 0, 13 do
        local x = i * 40 - d
        ui.rectfill(x, GROUND + 22, x + 20, GROUND + 24, C(0xffffff))
    end

    -- bandeirinhas na calcada
    local f0 = flr(cam / 400)
    for k = f0, f0 + 2 do
        local x = flr(k * 400 + 300 - cam)
        draw_flag(x, GROUND - 31)
    end

    -- placas com o nome do estado
    for _, rg in ipairs(REGIONS) do
        local x = flr(rg.start + 40 - cam)
        if x > -150 and x < 500 then
            local w = #rg.name * FONT_W + 10
            ui.rectfill(x + 2, GROUND - 40, x + 4, GROUND, C(0x847e87))
            ui.rectfill(x + w - 4, GROUND - 40, x + w - 2, GROUND, C(0x847e87))
            ui.rectfill(x, GROUND - 58, x + w, GROUND - 40, C(0x37946e))
            ui.rect(x, GROUND - 58, x + w, GROUND - 40, C(0xffffff))
            ui.print(rg.name, x + 5, GROUND - 53, C(0xffffff))
        end
    end

    -- linha de chegada
    local fx = flr(FINISH - cam)
    if fx > -40 and fx < 520 then
        for i = 0, 9 do
            for j = 0, 1 do
                local col = ((i + j) % 2 == 0) and C(0x000000) or C(0xffffff)
                ui.rectfill(fx + j * 6, GROUND - 100 + i * 10, fx + j * 6 + 5, GROUND - 91 + i * 10, col)
            end
        end
        ui.rectfill(fx - 30, GROUND - 120, fx + 42, GROUND - 102, C(0xac3232))
        ui.print("CHEGADA", fx - 15, GROUND - 115, C(0xffffff))
    end

    -- obstaculos
    for _, o in ipairs(obstacles) do
        local x = flr(o.x - cam)
        if x > -30 and x < 500 then
            if o.kind == "b" then
                -- barreira listrada
                ui.rectfill(x + 2, GROUND - 22, x + 4, GROUND, C(0x696a6a))
                ui.rectfill(x + 14, GROUND - 22, x + 16, GROUND, C(0x696a6a))
                for s = 0, 3 do
                    local col = (s % 2 == 0) and C(0xac3232) or C(0xffffff)
                    ui.rectfill(x + s * 4 + 1, GROUND - 22, x + s * 4 + 4, GROUND - 16, col)
                end
                ui.rectfill(x + 17, GROUND - 22, x + 18, GROUND - 16, C(0xac3232))
            else
                -- placa suspensa (passar deslizando)
                ui.rectfill(x + 9, 0, x + 12, GROUND - 60, C(0x696a6a))
                ui.rectfill(x - 2, GROUND - 60, x + 24, GROUND - 17, C(0x306082))
                ui.rect(x - 2, GROUND - 60, x + 24, GROUND - 17, C(0xffffff))
                ui.print("USA", x + 2, GROUND - 46, C(0xffffff))
                ui.rectfill(x + 2, GROUND - 32, x + 20, GROUND - 30, C(0xac3232))
            end
        end
    end

    -- green cards
    for i, c in ipairs(cards) do
        if not c.got then
            local x = c.x - cam
            if x > -20 and x < 500 then
                local bob = math.sin((Frame_now + i * 7) * 0.12) * 2
                draw_card(x, c.y + bob)
            end
        end
    end
end

local function draw_player(frame)
    if p.inv > 0 and flr((p.inv) / 4) % 2 == 0 then return end
    local x = PLAYER_X
    local y = flr(p.y)
    if p.slide > 0 then
        ui.rectfill(x, y - 10, x + 22, y, C(0x306082))
        ui.rectfill(x + 16, y - 12, x + 24, y - 4, C(0xeec39a))
        ui.rectfill(x + 16, y - 13, x + 24, y - 10, C(0x663931))
    else
        local leg = (p.onground and flr((frame) / 6) % 2 == 0) and 2 or 0
        ui.rectfill(x + 1, y - 8, x + 4, y - leg, C(0x306082))
        ui.rectfill(x + 7, y - 8, x + 10, y - 2 + leg, C(0x306082))
        ui.rectfill(x, y - 20, x + 11, y - 8, C(0x99e550))
        ui.rectfill(x + 2, y - 26, x + 11, y - 20, C(0xeec39a))
        ui.rectfill(x + 1, y - 28, x + 11, y - 25, C(0x663931))
        ui.rectfill(x + 8, y - 24, x + 9, y - 23, C(0x000000))
    end
end

local function draw_trump(frame)
    local target = PLAYER_X - 28 - trump.gap * 110
    if state == "caught" then target = PLAYER_X - 12 end
    trump.sx = trump.sx + (target - trump.sx) * 0.1
    local x = flr(trump.sx)
    local y = GROUND - flr(math.abs(math.sin(frame * 0.3)) * 3)
    -- corpo: retangulo de terno
    ui.rectfill(x, y - 30, x + 16, y, C(0x3f3f74))
    ui.rectfill(x + 7, y - 22, x + 9, y - 10, C(0xac3232))
    -- rosto
    ui.rectfill(x + 2, y - 40, x + 16, y - 30, C(0xd9a066))
    ui.rectfill(x + 12, y - 37, x + 13, y - 36, C(0x000000))
    -- topete amarelo
    ui.rectfill(x, y - 46, x + 14, y - 40, C(0xfbf236))
    ui.trisfill(x + 10, y - 46, x + 21, y - 43, x + 10, y - 40, C(0xfbf236))
end

local function draw_hud()
    -- green cards
    draw_card(16, 14)
    ui.print("x " .. collected, 28, 10, C(0xffffff))

    -- barra de progresso
    local bx0, bx1 = 140, 460
    ui.rectfill(bx0, 10, bx1, 13, C(0x222034))
    local prog = ui.mid(0, p.x / FINISH, 1)
    ui.rectfill(bx0, 10, bx0 + flr((bx1 - bx0) * prog), 13, C(0x6abe30))
    ui.rectfill(bx1 - 2, 4, bx1, 16, C(0xffffff))

    -- distancia do Trump
    ui.print("TRUMP", 140, 20, C(0xffffff))
    local w = flr(80 * trump.gap)
    ui.rectfill(178, 21, 258, 25, C(0x222034))
    local col = trump.gap < 0.5 and C(0xac3232) or C(0xfbf236)
    ui.rectfill(178, 21, 178 + w, 25, col)
end

local function panel(lines)
    ui.rectfill(90, 60, 390, 190, C(0x222034))
    ui.rect(90, 60, 390, 190, C(0xffffff))
    for i, ln in ipairs(lines) do
        ui.print(ln[1], cx(ln[1]), 72 + (i - 1) * 16, C(ln[2]))
    end
end

-- ===================================================================
-- Loop principal
-- ===================================================================
Frame_now = 0

function loop(frame)
    Frame_now = frame

    for i = 1, #Palette do
        local color = Palette[i]
        ui.palset(i - 1, color)
    end

    ui.clip(0, 0, 480, 270)
    ui.camera(0, 0)

    if state == "title" then
        if ui.btnp(BTN_Z) or ui.btnp(UP) then
            reset()
            state = "run"
        end
    elseif state == "run" then
        update_run()
    else
        endT = endT + 1
        if endT > 30 and ui.btnp(BTN_Z) then
            reset()
            state = "run"
        end
    end

    local cam = p.x - PLAYER_X
    draw_world(cam)
    if state ~= "title" then
        draw_trump(frame)
        draw_player(frame)
        draw_hud()
    else
        trump.sx = PLAYER_X - 140
    end

    if state == "title" then
        local blink = flr((frame) / 30) % 2 == 0
        panel({
            { "TRUMP'S RUN", 0xfbf236 },
            { "CORRA PELOS EUA E FUJA DO TRUMP!", 0xffffff },
            { "", 0xffffff },
            { "CIMA / Z : PULAR", 0xcbdbfc },
            { "BAIXO / X : DESLIZAR", 0xcbdbfc },
            { "COLETE OS GREEN CARDS", 0x6abe30 },
            { blink and "APERTE Z PARA COMECAR" or "", 0xffffff },
        })
    elseif state == "win" then
        panel({
            { "VOCE CHEGOU NA CALIFORNIA!", 0x6abe30 },
            { "", 0xffffff },
            { "GREEN CARDS: " .. collected .. " / " .. #cards, 0xfbf236 },
            { "PONTUACAO: " .. collected * 100, 0xffffff },
            { "", 0xffffff },
            { "APERTE Z PARA JOGAR DE NOVO", 0xcbdbfc },
        })
    elseif state == "caught" and endT > 40 then
        panel({
            { "O TRUMP TE PEGOU!", 0xac3232 },
            { "", 0xffffff },
            { "ESTADO: " .. REGIONS[region_at(p.x)].name, 0xffffff },
            { "GREEN CARDS: " .. collected .. " / " .. #cards, 0xfbf236 },
            { "", 0xffffff },
            { "APERTE Z PARA TENTAR DE NOVO", 0xcbdbfc },
        })
    end
end
