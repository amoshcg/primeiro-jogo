require "palette"
require "sprites"

-- ===================================================================
-- Trump's Run - corrida 2D pelo mundo
-- O personagem corre sozinho. Controle (Y esquerda, X cima, A direita,
-- B baixo): X/CIMA pula, B/BAIXO desliza, Y/ESQUERDA reflete os tiros
-- e A/DIREITA solta o kamehameha (so na batalha final).
-- Cada fase e um pais, com um presidente correndo atras e atirando.
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
-- Coletaveis
-- ===================================================================
local function draw_green_card(x, y)
    x, y = flr(x), flr(y)
    ui.rectfill(x - 7, y - 5, x + 7, y + 5, C(0x6abe30))
    ui.rect(x - 7, y - 5, x + 7, y + 5, C(0x37946e))
    ui.rectfill(x - 5, y - 3, x - 1, y + 2, C(0xcbdbfc))
    ui.line(x + 1, y - 2, x + 5, y - 2, C(0xffffff))
    ui.line(x + 1, y, x + 5, y, C(0xffffff))
    ui.line(x + 1, y + 2, x + 4, y + 2, C(0x4b692f))
end

-- fonte minuscula 3x5 (o ui.print nao permite mudar o tamanho)
local TINY = {
    B = { "110", "101", "110", "101", "110" },
    O = { "111", "101", "101", "101", "111" },
    L = { "100", "100", "100", "100", "111" },
    S = { "111", "100", "111", "001", "111" },
    A = { "010", "101", "111", "101", "101" },
    ["+"] = { "000", "010", "111", "010", "000" },
    ["1"] = { "010", "110", "010", "010", "111" },
    ["0"] = { "111", "101", "101", "101", "111" },
    V = { "101", "101", "101", "101", "010" },
    I = { "111", "010", "010", "010", "111" },
}

local function draw_tiny(text, x, y, col)
    for i = 1, #text do
        local glyph = TINY[text:sub(i, i)]
        if glyph then
            for r = 1, 5 do
                for c = 1, 3 do
                    if glyph[r]:sub(c, c) == "1" then
                        local px, py = x + (i - 1) * 4 + c - 1, y + r - 1
                        ui.rectfill(px, py, px, py, col)
                    end
                end
            end
        end
    end
end

local function draw_credit_card(x, y)
    -- cartao vermelho do social credit score: estrela amarela e +100
    x, y = flr(x), flr(y)
    ui.rectfill(x - 13, y - 6, x + 13, y + 6, C(0xac3232))
    ui.rect(x - 13, y - 6, x + 13, y + 6, C(0x000000))
    ui.trisfill(x - 11, y - 1, x - 3, y - 1, x - 7, y - 5, C(0xfbf236))
    ui.trisfill(x - 11, y - 1, x - 3, y - 1, x - 7, y + 3, C(0xfbf236))
    draw_tiny("+100", x - 1, y - 2, C(0xffffff))
end

local function draw_bolsa_card(x, y)
    -- cartao azul com faixas verde/amarela e a palavra BOLSA
    x, y = flr(x), flr(y)
    ui.rectfill(x - 13, y - 6, x + 13, y + 6, C(0x5b6ee1))
    ui.rectfill(x - 13, y + 4, x + 13, y + 4, C(0x6abe30))
    ui.rectfill(x - 13, y + 5, x + 13, y + 6, C(0xfbf236))
    ui.rect(x - 13, y - 6, x + 13, y + 6, C(0x3f3f74))
    draw_tiny("BOLSA", x - 9, y - 4, C(0xffffff))
end

-- ===================================================================
-- Perseguidores (bem simples: retangulos)
-- ===================================================================
local function draw_trump(x, y, frame)
    -- terno, gravata, rosto e topete amarelo
    ui.rectfill(x, y - 30, x + 16, y, C(0x3f3f74))
    ui.rectfill(x + 7, y - 22, x + 9, y - 10, C(0xac3232))
    ui.rectfill(x + 2, y - 40, x + 16, y - 30, C(0xd9a066))
    ui.rectfill(x + 12, y - 37, x + 13, y - 36, C(0x000000))
    -- topete balanca para cima e para baixo enquanto corre
    local h = flr(math.sin(frame * 0.4) * 3)
    ui.rectfill(x, y - 46 + h, x + 14, y - 40, C(0xfbf236))
    ui.trisfill(x + 10, y - 46 + h, x + 21, y - 43 + h, x + 10, y - 40, C(0xfbf236))
end

local function draw_xi(x, y, frame)
    -- terno azul, gravata vermelha (balancando), rosto e cabelo preto penteado
    ui.rectfill(x, y - 30, x + 16, y, C(0x306082))
    ui.rectfill(x + 6, y - 30, x + 10, y - 26, C(0xffffff))
    local t = flr(math.sin(frame * 0.4) * 4)
    ui.rectfill(x + 7, y - 27, x + 9, y - 25, C(0xac3232))
    ui.trisfill(x + 7, y - 25, x + 9, y - 25, x + 9 + t, y - 11, C(0xac3232))
    ui.trisfill(x + 7, y - 25, x + 7 + t, y - 11, x + 9 + t, y - 11, C(0xac3232))
    ui.rectfill(x + 2, y - 41, x + 16, y - 30, C(0xeec39a))
    ui.rectfill(x + 12, y - 37, x + 13, y - 36, C(0x000000))
    ui.rectfill(x + 1, y - 45, x + 16, y - 40, C(0x000000))
    ui.rectfill(x + 1, y - 40, x + 3, y - 35, C(0x000000))
end

local function draw_lula(x, y, frame)
    -- camiseta vermelha, rosto, barba branca (mexendo) e chapeu
    ui.rectfill(x, y - 30, x + 16, y, C(0xac3232))
    ui.rectfill(x + 2, y - 42, x + 16, y - 30, C(0xeec39a))
    local b = flr(math.abs(math.sin(frame * 0.35)) * 3)
    ui.rectfill(x + 2, y - 35, x + 17, y - 28 + b, C(0xffffff))
    ui.rectfill(x + 6, y - 28 + b, x + 15, y - 26 + b, C(0xffffff))
    ui.rectfill(x + 12, y - 39, x + 13, y - 38, C(0x000000))
    ui.rectfill(x - 2, y - 44, x + 20, y - 42, C(0x8a6f30))
    ui.rectfill(x + 2, y - 50, x + 15, y - 44, C(0x8a6f30))
    ui.rectfill(x + 2, y - 46, x + 15, y - 45, C(0x000000))
end

-- ===================================================================
-- Pontos turisticos (desenhados no fundo com parallax)
-- ===================================================================
local g = GROUND

local function lm_liberty(x)
    ui.rectfill(x - 14, g - 40, x + 14, g, C(0x9badb7))
    ui.rectfill(x - 10, g - 46, x + 10, g - 40, C(0x847e87))
    ui.trisfill(x - 10, g - 46, x + 10, g - 46, x, g - 110, C(0x37946e))
    ui.circfill(x, g - 112, 6, C(0x37946e))
    ui.trisfill(x - 6, g - 116, x + 6, g - 116, x, g - 126, C(0x37946e))
    ui.rectfill(x + 6, g - 138, x + 9, g - 104, C(0x37946e))
    ui.circfill(x + 7, g - 142, 4, C(0xfbf236))
end

local function lm_washington(x)
    ui.rectfill(x - 6, g - 130, x + 6, g, C(0xcbdbfc))
    ui.trisfill(x - 6, g - 130, x + 6, g - 130, x, g - 145, C(0xcbdbfc))
    ui.rectfill(x + 40, g - 40, x + 120, g, C(0xffffff))
    ui.circfill(x + 80, g - 40, 22, C(0xffffff))
    ui.rectfill(x + 78, g - 72, x + 82, g - 60, C(0xffffff))
    for i = 0, 7 do
        ui.line(x + 46 + i * 10, g - 34, x + 46 + i * 10, g - 2, C(0x9badb7))
    end
end

local function lm_texas(x)
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
end

local function lm_vegas(x)
    ui.rectfill(x - 20, g - 120, x + 20, g, C(0x76428a))
    ui.rectfill(x + 30, g - 80, x + 80, g, C(0x3f3f74))
    for yy = g - 112, g - 10, 12 do
        for xx = x - 14, x + 10, 8 do
            if flr((xx + yy) / 4) % 3 ~= 0 then
                ui.rectfill(xx, yy, xx + 3, yy + 5, C(0xd77bba))
            end
        end
    end
    ui.rectfill(x + 34, g - 72, x + 76, g - 58, C(0xd77bba))
    ui.print("CASINO", x + 37, g - 69, C(0xffffff))
end

local function palm(px)
    ui.rectfill(px, g - 70, px + 3, g, C(0x8a6f30))
    ui.circfill(px - 8, g - 70, 8, C(0x4b692f))
    ui.circfill(px + 10, g - 70, 8, C(0x4b692f))
    ui.circfill(px + 1, g - 76, 7, C(0x6abe30))
end

local function lm_hollywood(x)
    ui.trisfill(x - 40, g, x + 160, g, x + 60, g - 60, C(0x8f563b))
    ui.print("HOLLYWOOD", x + 32, g - 46, C(0xffffff))
    palm(x - 40)
    palm(x + 190)
end

local function lm_saopaulo(x)
    -- MASP: caixa vermelha sobre pilares
    ui.rectfill(x, g - 50, x + 6, g, C(0xac3232))
    ui.rectfill(x + 94, g - 50, x + 100, g, C(0xac3232))
    ui.rectfill(x - 4, g - 50, x + 104, g - 34, C(0x696a6a))
    ui.rectfill(x - 4, g - 56, x + 104, g - 50, C(0xac3232))
    ui.rectfill(x + 130, g - 140, x + 160, g, C(0x847e87))
    ui.rectfill(x + 170, g - 110, x + 200, g, C(0x696a6a))
end

local function lm_rio(x)
    -- Pao de Acucar e Cristo Redentor
    ui.trisfill(x - 30, g, x + 70, g, x + 20, g - 50, C(0x4b692f))
    ui.trisfill(x + 110, g, x + 190, g, x + 150, g - 40, C(0x37946e))
    ui.rectfill(x + 18, g - 76, x + 22, g - 48, C(0xffffff))
    ui.rectfill(x + 6, g - 70, x + 34, g - 66, C(0xffffff))
    ui.circfill(x + 20, g - 79, 3, C(0xffffff))
    palm(x + 210)
end

local function lm_brasilia(x)
    -- Congresso Nacional: duas torres e duas cupulas
    ui.rectfill(x + 50, g - 110, x + 60, g - 30, C(0xcbdbfc))
    ui.rectfill(x + 64, g - 110, x + 74, g - 30, C(0xcbdbfc))
    ui.rectfill(x - 10, g - 30, x + 140, g, C(0xffffff))
    ui.circfill(x + 20, g - 30, 14, C(0xffffff))
    ui.rectfill(x + 6, g - 44, x + 34, g - 31, C(REGION_SKY or 0x5fcde4))
    ui.circfill(x + 110, g - 30, 14, C(0xffffff))
end

local function lm_amazonia(x)
    for k = 0, 4 do
        local tx = x + k * 50
        local th = 50 + (k * 23) % 30
        ui.rectfill(tx - 3, g - th, tx + 3, g, C(0x663931))
        ui.rectfill(tx - 20, g - th - 10, tx + 20, g - th + 8, C(0x37946e))
        ui.rectfill(tx - 12, g - th - 18, tx + 12, g - th - 10, C(0x6abe30))
    end
end

local function lm_pequim(x)
    -- Cidade Proibida: predio vermelho com telhados dourados
    ui.rectfill(x - 10, g - 20, x + 130, g, C(0x8f563b))
    ui.rectfill(x + 10, g - 50, x + 110, g - 20, C(0xac3232))
    ui.trisfill(x - 4, g - 50, x + 124, g - 50, x + 60, g - 70, C(0xd9a066))
    ui.rectfill(x + 30, g - 82, x + 90, g - 70, C(0xac3232))
    ui.trisfill(x + 20, g - 82, x + 100, g - 82, x + 60, g - 96, C(0xd9a066))
    ui.rectfill(x + 52, g - 40, x + 68, g - 20, C(0x222034))
end

local function lm_muralha(x)
    -- Grande Muralha sobre os morros
    ui.trisfill(x - 60, g, x + 180, g, x + 60, g - 50, C(0x4b692f))
    ui.rectfill(x - 40, g - 34, x + 160, g - 24, C(0x847e87))
    for k = 0, 24 do
        if k % 2 == 0 then
            ui.rectfill(x - 40 + k * 8, g - 38, x - 34 + k * 8, g - 34, C(0x847e87))
        end
    end
    for _, tx in ipairs({ -20, 60, 140 }) do
        ui.rectfill(x + tx, g - 56, x + tx + 18, g - 24, C(0x9badb7))
        ui.rectfill(x + tx + 6, g - 48, x + tx + 11, g - 40, C(0x222034))
    end
end

local function lm_xangai(x)
    -- Torre Oriental Pearl e arranha-ceus
    ui.rectfill(x - 3, g - 150, x + 3, g, C(0x3f3f74))
    ui.circfill(x, g - 40, 15, C(0x222034))
    ui.circfill(x, g - 40, 13, C(0xd95763))
    ui.circfill(x, g - 100, 11, C(0x222034))
    ui.circfill(x, g - 100, 9, C(0xd95763))
    ui.circfill(x, g - 130, 5, C(0xd95763))
    ui.rectfill(x + 50, g - 140, x + 74, g, C(0x5b6ee1))
    ui.trisfill(x + 50, g - 140, x + 74, g - 140, x + 74, g - 160, C(0x5b6ee1))
    ui.rectfill(x + 90, g - 110, x + 110, g, C(0x847e87))
end

local function lm_hongkong(x)
    -- predios iluminados a noite
    for k = 0, 3 do
        local bx = x + k * 50
        local h = 80 + (k * 37) % 60
        ui.rectfill(bx, g - h, bx + 34, g, C(0x3f3f74))
        for yy = g - h + 8, g - 12, 10 do
            ui.rectfill(bx + 5, yy, bx + 29, yy + 3, C(0x5fcde4))
        end
    end
    ui.trisfill(x + 200, g, x + 240, g, x + 230, g - 150, C(0x9badb7))
end

local function lm_pyongyang(x)
    -- Hotel Ryugyong (piramide) e Torre Juche
    ui.trisfill(x - 50, g, x + 50, g, x, g - 150, C(0x847e87))
    ui.rectfill(x - 2, g - 162, x + 2, g - 148, C(0x847e87))
    ui.rectfill(x + 90, g - 120, x + 98, g, C(0xffffff))
    ui.trisfill(x + 88, g - 120, x + 100, g - 120, x + 94, g - 134, C(0xac3232))
end

local function lm_dmz(x)
    -- cerca da zona desmilitarizada e torre de vigia
    for k = 0, 10 do
        ui.rectfill(x + k * 20, g - 30, x + k * 20 + 2, g, C(0x696a6a))
    end
    for k = 0, 2 do
        ui.line(x, g - 28 + k * 9, x + 202, g - 28 + k * 9, C(0x595652))
    end
    ui.rectfill(x + 230, g - 70, x + 254, g, C(0x8a6f30))
    ui.rectfill(x + 226, g - 80, x + 258, g - 70, C(0x663931))
end

local function lm_misseis(x)
    -- misseis na plataforma de lancamento
    for k = 0, 2 do
        local mx = x + k * 60
        local top = g - 90 + k * 10
        ui.rectfill(mx - 12, g - 10, mx + 12, g, C(0x595652))
        ui.rectfill(mx - 5, top, mx + 5, g - 10, C(0xcbdbfc))
        ui.trisfill(mx - 5, top, mx + 5, top, mx, top - 14, C(0xac3232))
        ui.trisfill(mx - 5, g - 26, mx - 5, g - 10, mx - 11, g - 10, C(0x696a6a))
        ui.trisfill(mx + 5, g - 26, mx + 5, g - 10, mx + 11, g - 10, C(0x696a6a))
    end
end

-- ===================================================================
-- Mais coletaveis e chefes
-- ===================================================================
local function draw_visa_card(x, y)
    -- cartao com as cores da Coreia do Norte e a palavra VISA
    x, y = flr(x), flr(y)
    ui.rectfill(x - 13, y - 6, x + 13, y + 6, C(0x306082))
    ui.rectfill(x - 13, y - 3, x + 13, y + 3, C(0xffffff))
    ui.rectfill(x - 13, y - 2, x + 13, y + 2, C(0xac3232))
    ui.rect(x - 13, y - 6, x + 13, y + 6, C(0x000000))
    draw_tiny("VISA", x - 7, y - 2, C(0xffffff))
end

local function draw_kim(x, y, frame)
    -- gordinho de terno escuro, cabelo meia-lua e oculos pulando
    ui.rectfill(x - 3, y - 30, x + 21, y, C(0x323c39))
    ui.rectfill(x - 5, y - 24, x + 23, y - 8, C(0x323c39))
    ui.rectfill(x + 9, y - 26, x + 10, y - 25, C(0x847e87))
    ui.rectfill(x + 9, y - 18, x + 10, y - 17, C(0x847e87))
    ui.circfill(x + 9, y - 42, 10, C(0x000000))
    ui.rectfill(x - 1, y - 42, x + 19, y - 29, C(0xeec39a))
    local gy = y - 39 - flr(math.abs(math.sin(frame * 0.5)) * 3)
    ui.rect(x + 7, gy, x + 11, gy + 3, C(0x000000))
    ui.rect(x + 14, gy, x + 18, gy + 3, C(0x000000))
    ui.line(x + 11, gy + 1, x + 14, gy + 1, C(0x000000))
    ui.rectfill(x + 12, y - 32, x + 16, y - 31, C(0x8f563b))
end

-- desenha retangulo aceitando coordenadas em qualquer ordem (para espelhar)
local function rf(x0, y0, x1, y1, col)
    if x0 > x1 then x0, x1 = x1, x0 end
    ui.rectfill(x0, y0, x1, y1, col)
end

local function flame(x, y, d)
    local f = (flr(Frame_now / 3) % 2 == 0) and C(0xdf7126) or C(0xfbf236)
    rf(x, y - 1, x - 4 * d, y + 1, f)
end

-- d = 1 indo para a direita (ataque), d = -1 voltando (refletido)
local function draw_tomahawk(x, y, d)
    x, y = flr(x), flr(y)
    rf(x - 10 * d, y - 2, x + 8 * d, y + 1, C(0xcbdbfc))
    ui.trisfill(x + 8 * d, y - 2, x + 8 * d, y + 1, x + 13 * d, y, C(0x847e87))
    rf(x - 4 * d, y - 4, x - 2 * d, y + 3, C(0x696a6a))
    rf(x - 10 * d, y - 2, x - 8 * d, y + 1, C(0x306082))
    flame(x - 11 * d, y, d)
end

local function draw_picanha(x, y, d)
    x, y = flr(x), flr(y)
    ui.rectfill(x - 8, y - 2, x + 8, y + 4, C(0xac3232))
    ui.rectfill(x - 8, y - 4, x + 8, y - 2, C(0xffffff))
    ui.line(x - 4, y - 1, x - 6, y + 3, C(0x663931))
    ui.line(x + 2, y - 1, x, y + 3, C(0x663931))
end

local function draw_gpu(x, y, d)
    x, y = flr(x), flr(y)
    ui.rectfill(x - 10, y - 5, x + 10, y + 4, C(0x222034))
    ui.circfill(x - 5, y, 3, C(0x696a6a))
    ui.circfill(x + 5, y, 3, C(0x696a6a))
    ui.rectfill(x - 5, y, x - 5, y, C(0x000000))
    ui.rectfill(x + 5, y, x + 5, y, C(0x000000))
    ui.rectfill(x - 10, y + 4, x + 10, y + 5, C(0x37946e))
    ui.rectfill(x - 7, y + 6, x + 7, y + 7, C(0xd9a066))
end

local function draw_nuke(x, y, d)
    x, y = flr(x), flr(y)
    rf(x - 12 * d, y - 4, x + 8 * d, y + 3, C(0x4b692f))
    ui.trisfill(x + 8 * d, y - 4, x + 8 * d, y + 3, x + 15 * d, y, C(0xac3232))
    rf(x - 2 * d, y - 4, x + 1 * d, y + 3, C(0xfbf236))
    ui.trisfill(x - 12 * d, y - 4, x - 7 * d, y - 4, x - 12 * d, y - 8, C(0x222034))
    ui.trisfill(x - 12 * d, y + 3, x - 7 * d, y + 3, x - 12 * d, y + 7, C(0x222034))
    flame(x - 13 * d, y, d)
end

local BOSS_DEFS = {
    trump = { name = "TRUMP",       draw = draw_trump, shot = draw_tomahawk, w = 16 },
    lula  = { name = "LULA",        draw = draw_lula,  shot = draw_picanha,  w = 18 },
    xi    = { name = "XI JINPING",  draw = draw_xi,    shot = draw_gpu,      w = 16 },
    kim   = { name = "KIM JONG UN", draw = draw_kim,   shot = draw_nuke,     w = 22 },
}

-- ===================================================================
-- Obstaculos e jogador (gy = linha do chao onde desenhar)
-- ===================================================================
local function draw_barrier(x, gy)
    local K, Y, R = C(0x000000), C(0xfbf236), C(0xac3232)
    ui.rectfill(x - 1, gy + 1, x + 19, gy + 3, K)
    ui.rectfill(x + 1, gy - 23, x + 5, gy, K)
    ui.rectfill(x + 13, gy - 23, x + 17, gy, K)
    ui.rectfill(x + 2, gy - 22, x + 4, gy, R)
    ui.rectfill(x + 14, gy - 22, x + 16, gy, R)
    ui.rectfill(x - 1, gy - 24, x + 19, gy - 14, K)
    for s = 0, 4 do
        local col = (s % 2 == 0) and Y or K
        ui.rectfill(x + s * 4, gy - 23, x + s * 4 + 3, gy - 15, col)
    end
    ui.trisfill(x + 4, gy - 30, x + 14, gy - 30, x + 9, gy - 36, Y)
end

local function draw_hsign(x, gy, tag)
    local K, Y, R = C(0x000000), C(0xfbf236), C(0xac3232)
    ui.rectfill(x + 8, 0, x + 13, gy - 60, K)
    ui.rectfill(x + 9, 0, x + 12, gy - 60, R)
    ui.rectfill(x - 4, gy - 62, x + 26, gy - 15, K)
    ui.rectfill(x - 2, gy - 60, x + 24, gy - 17, Y)
    ui.rectfill(x + 1, gy - 57, x + 21, gy - 20, R)
    ui.print(tag, x + 3, gy - 52, C(0xffffff))
    ui.trisfill(x + 4, gy - 38, x + 18, gy - 38, x + 11, gy - 26, C(0xffffff))
end

local function draw_runner(x, y, slide, frame)
    y = flr(y)
    if slide then
        ui.rectfill(x, y - 10, x + 22, y, C(0x306082))
        ui.rectfill(x + 16, y - 12, x + 24, y - 4, C(0xeec39a))
        ui.rectfill(x + 16, y - 13, x + 24, y - 10, C(0x663931))
    else
        local leg = (flr(frame / 6) % 2 == 0) and 2 or 0
        ui.rectfill(x + 1, y - 8, x + 4, y - leg, C(0x306082))
        ui.rectfill(x + 7, y - 8, x + 10, y - 2 + leg, C(0x306082))
        ui.rectfill(x, y - 20, x + 11, y - 8, C(0x99e550))
        ui.rectfill(x + 2, y - 26, x + 11, y - 20, C(0xeec39a))
        ui.rectfill(x + 1, y - 28, x + 11, y - 25, C(0x663931))
        ui.rectfill(x + 8, y - 24, x + 9, y - 23, C(0x000000))
    end
end

local function draw_shield(x, y, slide)
    local top = slide and y - 16 or y - 32
    ui.rectfill(x - 9, top - 1, x - 3, y + 1, C(0xffffff))
    ui.rectfill(x - 8, top, x - 4, y, C(0x5fcde4))
end

local function draw_beam(x0, x1, cy, frame)
    local r = (frame % 4 < 2) and 6 or 5
    ui.rectfill(x0, cy - r, x1, cy + r, C(0x5fcde4))
    ui.rectfill(x0, cy - 2, x1, cy + 2, C(0xffffff))
    ui.circfill(x1, cy, r + 3, C(0x5fcde4))
    ui.circfill(x1, cy, r - 1, C(0xffffff))
end

-- triangulo de seta dentro de uma caixa 8x8 (dir: up, down, left, right)
local function draw_arrow(x, y, dir, col)
    if dir == "up" then
        ui.trisfill(x, y + 7, x + 8, y + 7, x + 4, y, col)
    elseif dir == "down" then
        ui.trisfill(x, y, x + 8, y, x + 4, y + 7, col)
    elseif dir == "left" then
        ui.trisfill(x + 7, y, x + 7, y + 8, x, y + 4, col)
    else
        ui.trisfill(x, y, x, y + 8, x + 7, y + 4, col)
    end
end

-- ===================================================================
-- Botoes do controle (Y esquerda, X cima, A direita, B baixo)
-- Mapeamento conferido no controle SNES da PlayGames (tela TESTAR CONTROLE):
--   A = BTN_G, B = BTN_Z, X = BTN_X, Y = BTN_F, L = BTN_Q, R = BTN_E
-- Teclado: A = H, B = K, X = J, Y = G
-- ===================================================================
local PAD_A, PAD_B, PAD_X, PAD_Y = BTN_G, BTN_Z, BTN_X, BTN_F
local PAD_L, PAD_R = BTN_Q, BTN_E

local function bp(b) return b ~= nil and ui.btnp(b) end

local function pressed_jump() return bp(UP) or bp(PAD_X) end
local function pressed_slide() return bp(DOWN) or bp(PAD_B) end
local function pressed_reflect() return bp(LEFT) or bp(PAD_Y) end
local function pressed_kame() return bp(RIGHT) or bp(PAD_A) end
local function pressed_ok() return bp(PAD_B) end      -- confirmar no B
local function pressed_back() return bp(PAD_A) end    -- voltar no A

-- Start/Select nao tem constante no Lupi: usamos o numero do botao no
-- raylib (GAMEPAD_BUTTON_MIDDLE_RIGHT = 15, MIDDLE_LEFT = 13)
local PAD_START = START or 15
local PAD_SELECT = SELECT or 13
local function pressed_start() return bp(PAD_START) end
local function holding_slide()
    return ui.btn(DOWN) or (PAD_B ~= nil and ui.btn(PAD_B))
end

-- desenha os 4 botoes do controle em losango, destacando um deles
local function draw_pad(x, y, active)
    local btns = { { "X", 0, -11 }, { "Y", -11, 0 }, { "A", 11, 0 }, { "B", 0, 11 } }
    for _, b in ipairs(btns) do
        local on = b[1] == active
        local bx, by = x + b[2], y + b[3]
        ui.circfill(bx, by, 6, on and C(0xfbf236) or C(0x595652))
        ui.print(b[1], bx - 2, by - 3, on and C(0x000000) or C(0xcbdbfc))
    end
end

-- ===================================================================
-- Mapas estaticos de cada pais:
--   .  vazio
--   b  barreira (pular)
--   h  placa suspensa (deslizar)
--   c  cartao no chao
--   a  cartao no alto (pular para pegar)
--   B  barreira com cartao em cima
-- Cada regiao comeca com 4 espacos vazios (para a placa com o nome).
-- ===================================================================
local MAP_EUA = {
    { name = "NEW YORK",      sky = 0x639bff, lm = lm_liberty,    map = "......c.c.c....b....c.c.c...h....b..a." },
    { name = "WASHINGTON DC", sky = 0x5fcde4, lm = lm_washington, map = "....h.ccc...b...h...B....a.a...h..b.." },
    { name = "TEXAS",         sky = 0xd9a066, lm = lm_texas,      map = "....b..b..ccc..h..h...B...b..a..h..cc." },
    { name = "LAS VEGAS",     sky = 0x222034, lm = lm_vegas,      map = "....h..b..ccc..h..B..h...b..b..a.a..h...", night = true },
    { name = "HOLLYWOOD",     sky = 0xdf7126, lm = lm_hollywood,  map = "....b..h.ccc..B..h..b..h...b..ccc......" },
}

local MAP_BRASIL = {
    { name = "SAO PAULO",      sky = 0x9badb7, lm = lm_saopaulo, map = "......c.c.c...b...h...ccc..b..a..h..B.." },
    { name = "RIO DE JANEIRO", sky = 0x639bff, lm = lm_rio,      map = "....b..h.ccc..b..b..a.a..h..h..B...cc.." },
    { name = "BRASILIA",       sky = 0x5fcde4, lm = lm_brasilia, map = "....h..b..ccc..B..h..b..h..a..b..b..ccc." },
    { name = "AMAZONIA",       sky = 0x99e550, lm = lm_amazonia, map = "....h..b..ccc..h..B..b..h..a.a..b..ccc......", forest = true },
}

local MAP_CHINA = {
    { name = "PEQUIM",         sky = 0xcbdbfc, lm = lm_pequim,   map = "......c.c.c...h..b..ccc..B..h..b..a.a..h.." },
    { name = "GRANDE MURALHA", sky = 0x639bff, lm = lm_muralha,  map = "....b..b..ccc..h..h..B..b..a..h..b..cc." },
    { name = "XANGAI",         sky = 0x5fcde4, lm = lm_xangai,   map = "....h..b..ccc..h..B..b..h..a.a..b..h..ccc." },
    { name = "HONG KONG",      sky = 0x222034, lm = lm_hongkong, map = "....b..h..ccc..B..h..b..b..a..h..b..ccc......", night = true },
}

local MAP_COREIA = {
    { name = "PYONGYANG",            sky = 0x9badb7, lm = lm_pyongyang, map = "......c.c.c...h...b..ccc...B...h..a.a...b...h.." },
    { name = "ZONA DESMILITARIZADA", sky = 0xcbdbfc, lm = lm_dmz,       map = "....b...b..ccc...h...B...b...h..a...b..cc.." },
    { name = "BASE DE MISSEIS",      sky = 0xdf7126, lm = lm_misseis,   map = "....h...b..ccc...B...h...b..a.a...h...b..ccc......" },
}

-- ===================================================================
-- Fases
--   1-3: so corrida ate a chegada
--   4-6: combate contra um presidente (refletir tiros); o mapa repete
--   7:   batalha final na Coreia do Norte, todos + Kim (com kamehameha)
-- intro = paginas de "como jogar" mostradas antes da fase
-- ===================================================================
local PHASES = {
    { country = "EUA", card = "GREEN CARDS", tag = "USA", draw_card = draw_green_card,
      speed = 3.0, regions = MAP_EUA, bosses = { { id = "trump" } },
      intro = { "jump", "slide", "goal_run" } },
    { country = "BRASIL", card = "BOLSAS", tag = "BR", draw_card = draw_bolsa_card,
      speed = 3.3, regions = MAP_BRASIL, bosses = { { id = "lula" } } },
    { country = "CHINA", card = "SOCIAL CREDIT", tag = "CN", draw_card = draw_credit_card,
      speed = 3.6, regions = MAP_CHINA, bosses = { { id = "xi" } } },

    { country = "EUA", card = "GREEN CARDS", tag = "USA", draw_card = draw_green_card,
      combat = true, speed = 3.0, shot_speed = 2.8, regions = MAP_EUA,
      bosses = { { id = "trump", hp = 5, fire = 180 } },
      intro = { "reflect", "dodge", "goal_combat" } },
    { country = "BRASIL", card = "BOLSAS", tag = "BR", draw_card = draw_bolsa_card,
      combat = true, speed = 3.2, shot_speed = 3.0, regions = MAP_BRASIL,
      bosses = { { id = "lula", hp = 5, fire = 170 } } },
    { country = "CHINA", card = "SOCIAL CREDIT", tag = "CN", draw_card = draw_credit_card,
      combat = true, speed = 3.4, shot_speed = 3.2, regions = MAP_CHINA,
      bosses = { { id = "xi", hp = 6, fire = 160 } } },

    { country = "COREIA DO NORTE", card = "VISTOS", tag = "NK", draw_card = draw_visa_card,
      combat = true, final = true, kame = true, rotate = true, speed = 3.4, shot_speed = 3.2, regions = MAP_COREIA,
      -- Kim e o chefe mais forte: mais vida e atira mais vezes
      bosses = {
          { id = "trump", hp = 3,  fire = 200 },
          { id = "lula",  hp = 3,  fire = 200 },
          { id = "xi",    hp = 3,  fire = 190 },
          { id = "kim",   hp = 10, fire = 160 },
      },
      intro = { "kame", "goal_final" } },
}

local ENERGY_MAX = 10   -- cartoes para carregar o kamehameha

local phase = 1
local P = PHASES[1]
local REGIONS = P.regions

local obstacles = {}
local cards = {}
local LOOP = 1          -- comprimento do mapa
local FINISH = 1        -- linha de chegada (fases sem combate)
local LOOPING = false   -- o mapa se repete (combate e telas de menu)

local function build_map()
    obstacles, cards = {}, {}
    local tile = 0
    for _, reg in ipairs(REGIONS) do
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
                cards[#cards + 1] = { x = x + 8, y = GROUND - 46, got = false }
            elseif ch == "B" then
                -- no alto do pulo por cima da barreira
                cards[#cards + 1] = { x = x + 9, y = GROUND - 78, got = false }
            end
            tile = tile + 1
        end
    end
    LOOP = tile * TILE
    FINISH = LOOP + 120
end

local function region_at(x)
    if LOOPING then x = x % LOOP end
    local cur = 1
    for i, reg in ipairs(REGIONS) do
        if x >= reg.start then cur = i end
    end
    return cur
end

-- posicao na tela de algo do mapa (repetindo quando o mapa esta em loop)
local function wrap(sx, period)
    if not LOOPING then return sx end
    if sx < -period / 2 then return sx + period end
    if sx > period / 2 then return sx - period end
    return sx
end

-- ===================================================================
-- Estado do jogo
-- ===================================================================
local state = "title"   -- title | howto | run | caught | clear | win
local menu_sel = 1
local unlocked = false  -- fases liberadas depois de zerar o jogo
local single = false    -- jogando apenas uma fase escolhida no menu
local howto_list = {}   -- paginas do "como jogar" mostradas agora
local howto_page = 1
local howto_then = "menu"  -- "menu" ou o numero da fase a iniciar
local p = {}
local bosses = {}
local shots = {}
local gap = 1           -- distancia dos presidentes (0 = te pegaram)
local energy = 0
local collected = 0
local scores = {}
local endT = 0
local runT = 0
local turn = 1          -- batalha final: presidente da vez
local turnT = 0         -- tempo do presidente da vez
local turn_msg = 0      -- tempo mostrando "VEZ DO ..."
local TURN_TIME = 600   -- cada presidente fica 10 segundos e reveza

local function start_phase(n)
    phase = n
    P = PHASES[n]
    REGIONS = P.regions
    LOOPING = P.combat or false
    build_map()
    p = { x = 0, dist = 0, y = GROUND, vy = 0, onground = true, slide = 0,
          fastfall = false, stumble = 0, inv = 0, shield = 0, shieldCD = 0,
          beam = 0, won = false, winT = 0 }
    bosses = {}
    for i, bd in ipairs(P.bosses) do
        local fire = bd.fire or 0
        bosses[i] = { def = BOSS_DEFS[bd.id], hp = bd.hp or 1, maxhp = bd.hp or 1,
                      fire = fire, timer = fire + (i - 1) * 50,
                      sx = -60 - i * 30, flash = 0, dead = false }
    end
    shots = {}
    gap = 1
    energy = 0
    collected = 0
    endT = 0
    runT = 0
    turn, turnT, turn_msg = 1, 0, 0
    state = "run"
end

local function show_howto(list, after)
    howto_list = list
    howto_page = 1
    howto_then = after
    state = "howto"
end

-- entra numa fase, mostrando antes o "como jogar" dela (se tiver)
local function begin_phase(n)
    start_phase(n)
    if PHASES[n].intro then
        LOOPING = true   -- o cenario fica rodando atras da explicacao
        show_howto(PHASES[n].intro, n)
    end
end

local function go_title()
    start_phase(1)
    LOOPING = true
    state = "title"
    menu_sel = 1
end

local function boss_names()
    if #bosses > 1 then return "TODOS OS PRESIDENTES" end
    return bosses[1].def.name
end

local function phase_name(n)
    local ph = PHASES[n]
    if ph.final then return "BATALHA FINAL: " .. ph.country end
    if ph.combat then return "FASE " .. n .. ": COMBATE - " .. ph.country end
    return "FASE " .. n .. ": " .. ph.country
end

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
local function hurt(amount)
    if p.inv > 0 or p.won then return end
    p.inv = 60
    p.stumble = 40
    gap = gap - amount
    if gap <= 0 then
        state = "caught"
        endT = 0
    end
end

local function damage(b, n)
    if b.dead then return end
    b.hp = b.hp - n
    b.flash = 16
    gap = math.min(1, gap + 0.12)
    if b.hp <= 0 then
        b.hp = 0
        b.dead = true
        local all = true
        for _, o in ipairs(bosses) do
            if not o.dead then all = false end
        end
        if all then
            p.won = true
            shots = {}
        end
    end
end

local function finish_phase()
    scores[phase] = { cards = collected, bosses = P.combat and #bosses or 0 }
    if single or phase == #PHASES then
        state = "win"
        if not single then unlocked = true end
    else
        state = "clear"
    end
    endT = 0
end

local function boss_active(i)
    return not P.rotate or i == turn
end

local function boss_target(i)
    if not boss_active(i) then return -90 end   -- esperando a vez fora da tela
    return PLAYER_X - 28 - gap * 110
end

-- passa a vez para o proximo presidente vivo
local function next_turn()
    for k = 1, #bosses do
        local i = (turn + k - 1) % #bosses + 1
        if not bosses[i].dead then
            if i ~= turn then
                turn = i
                turn_msg = 90
                shots = {}             -- tiros do anterior somem na troca
                bosses[i].timer = 70   -- tempo para chegar antes de atirar
            end
            break
        end
    end
    turnT = 0
end

local function update_combat()
    -- refletir (todas as fases de combate)
    if pressed_reflect() and p.shieldCD == 0 then
        p.shield = 22
        p.shieldCD = 20
    end
    -- kamehameha (so na batalha final)
    if P.kame and pressed_kame() and energy >= ENERGY_MAX and p.beam == 0 and not p.won then
        p.beam = 36
        energy = 0
        shots = {}
        for i, b in ipairs(bosses) do
            if boss_active(i) then damage(b, 3) end
        end
        gap = math.min(1, gap + 0.3)
    end
    if p.shield > 0 then p.shield = p.shield - 1 end
    if p.shieldCD > 0 then p.shieldCD = p.shieldCD - 1 end
    if p.beam > 0 then p.beam = p.beam - 1 end

    -- revezamento na batalha final
    if P.rotate and not p.won then
        turnT = turnT + 1
        if turnT >= TURN_TIME or bosses[turn].dead then next_turn() end
    end
    if turn_msg > 0 then turn_msg = turn_msg - 1 end

    -- presidentes atiram para frente
    for i, b in ipairs(bosses) do
        if not b.dead and boss_active(i) then
            b.timer = b.timer - 1
            if b.timer <= 0 then
                b.timer = b.fire
                shots[#shots + 1] = { x = b.sx + b.def.w + 6, y = GROUND - 20, dir = 1, owner = i }
            end
        end
    end

    -- tiros (em coordenadas de tela)
    local x0, y0, x1, y1 = player_box()
    local sx0 = PLAYER_X
    local sx1 = sx0 + (x1 - x0)
    for i = #shots, 1, -1 do
        local s = shots[i]
        local remove = false
        if s.dir == 1 then
            s.x = s.x + P.shot_speed
            if p.shield > 0 and s.x + 12 >= PLAYER_X - 40 and s.x - 12 <= sx1 then
                s.dir = -1   -- refletido!
            elseif overlap(sx0, y0, sx1, y1, s.x - 8, s.y - 3, s.x + 8, s.y + 3) then
                hurt(0.3)
                remove = true
            elseif s.x > 500 then
                remove = true
            end
        else
            s.x = s.x - 6
            local b = bosses[s.owner]
            if not b.dead and s.x <= b.sx + b.def.w then
                damage(b, 1)
                remove = true
            elseif s.x < -30 then
                remove = true
            end
        end
        if remove then table.remove(shots, i) end
    end

    if p.won then
        p.winT = p.winT + 1
        if p.winT >= 120 then finish_phase() end
    end
end

local function update_run()
    runT = runT + 1
    local spd = P.speed
    if not LOOPING then spd = spd + (p.x / FINISH) * 1.2 end
    if p.stumble > 0 then
        spd = spd * 0.6
        p.stumble = p.stumble - 1
    end
    p.x = p.x + spd
    p.dist = p.dist + spd

    -- no combate o mapa repete: volta ao inicio e os itens reaparecem
    if LOOPING and p.x >= LOOP then
        p.x = p.x - LOOP
        for _, o in ipairs(obstacles) do o.hit = false end
        for _, c in ipairs(cards) do c.got = false end
    end

    -- pular e deslizar
    if pressed_jump() and p.onground then
        p.vy = JUMP_V
        p.onground = false
        p.slide = 0
    end
    if pressed_slide() then
        if p.onground then
            p.slide = SLIDE_T
        else
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
    if p.slide > 0 then
        -- segurando B/BAIXO o deslize continua (ajuda a desviar dos tiros)
        if p.slide <= 2 and p.onground and holding_slide() then
            p.slide = 2
        else
            p.slide = p.slide - 1
        end
    end
    if p.inv > 0 then p.inv = p.inv - 1 end

    -- obstaculos
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
                hurt(0.55)
            end
        end
    end
    if state ~= "run" then return end

    -- cartoes: pontos (e energia do kamehameha na batalha final)
    for _, c in ipairs(cards) do
        if not c.got and c.x > x0 - 30 and c.x < x1 + 30
            and overlap(x0, y0, x1, y1, c.x - 12, c.y - 7, c.x + 12, c.y + 7) then
            c.got = true
            collected = collected + 1
            energy = math.min(ENERGY_MAX, energy + 1)
        end
    end

    -- presidentes correndo atras
    for i, b in ipairs(bosses) do
        if b.flash > 0 then b.flash = b.flash - 1 end
        if b.dead then
            b.sx = b.sx - 2
        else
            b.sx = b.sx + (boss_target(i) - b.sx) * 0.1
        end
    end

    gap = math.min(1, gap + 0.0015)

    if P.combat then
        update_combat()
    elseif p.x >= FINISH then
        finish_phase()
    end
end

-- ===================================================================
-- Desenho
-- ===================================================================
local function cx(s) return flr(240 - #s * FONT_W / 2) end

local function draw_world(cam, dist, scenery)
    local reg = REGIONS[region_at(cam + PLAYER_X)]
    REGION_SKY = reg.sky
    ui.cls(C(reg.sky))

    -- sol ou lua
    if reg.night then
        ui.circfill(420, 40, 14, C(0xcbdbfc))
        for i = 0, 25 do
            ui.rectfill((i * 97) % 480, (i * 53) % 150, (i * 97) % 480, (i * 53) % 150, C(0xffffff))
        end
    else
        ui.circfill(420, 40, 18, C(0xfbf236))
        local off = flr(dist * 0.2) % 600
        for i = 0, 3 do
            local x = i * 160 - off
            if x < -60 then x = x + 600 end
            local y = 30 + (i * 23) % 40
            ui.circfill(x, y, 10, C(0xffffff))
            ui.circfill(x + 12, y - 4, 12, C(0xffffff))
            ui.circfill(x + 26, y, 9, C(0xffffff))
        end
    end

    -- predios ao fundo (parallax 0.3); na floresta, arvores
    local bcam = dist * 0.3
    local k0 = flr(bcam / 40)
    for k = k0, k0 + 13 do
        local h = 30 + (k * 37) % 60
        local x = flr(k * 40 - bcam)
        if reg.forest then
            ui.rectfill(x + 15, GROUND - h + 10, x + 19, GROUND, C(0x663931))
            ui.rectfill(x + 2, GROUND - h, x + 32, GROUND - h + 16, C(0x4b692f))
        else
            local bcol = reg.night and C(0x3f3f74) or C(0x9badb7)
            ui.rectfill(x, GROUND - h, x + 34, GROUND, bcol)
            for wy = GROUND - h + 6, GROUND - 10, 10 do
                ui.rectfill(x + 6, wy, x + 10, wy + 4, C(0xcbdbfc))
                ui.rectfill(x + 22, wy, x + 26, wy + 4, C(0xcbdbfc))
            end
        end
    end

    -- pontos turisticos (parallax 0.6)
    local period = LOOP * 0.6
    for _, rg in ipairs(REGIONS) do
        for _, off in ipairs({ 220, 760 }) do
            local x = flr(wrap(rg.start * 0.6 + off - cam * 0.6, period))
            if x > -260 and x < 740 then rg.lm(x) end
        end
    end

    -- estrada
    ui.rectfill(0, GROUND, 480, 270, C(0x595652))
    ui.rectfill(0, GROUND, 480, GROUND + 3, C(0x847e87))
    local d = flr(dist) % 40
    for i = 0, 13 do
        local x = i * 40 - d
        ui.rectfill(x, GROUND + 22, x + 20, GROUND + 24, C(0xffffff))
    end

    if scenery then return end

    -- placas com o nome da regiao
    for _, rg in ipairs(REGIONS) do
        local x = flr(wrap(rg.start + 40 - cam, LOOP))
        if x > -150 and x < 500 then
            local w = #rg.name * FONT_W + 10
            ui.rectfill(x + 2, GROUND - 40, x + 4, GROUND, C(0x847e87))
            ui.rectfill(x + w - 4, GROUND - 40, x + w - 2, GROUND, C(0x847e87))
            ui.rectfill(x, GROUND - 58, x + w, GROUND - 40, C(0x37946e))
            ui.rect(x, GROUND - 58, x + w, GROUND - 40, C(0xffffff))
            ui.print(rg.name, x + 5, GROUND - 53, C(0xffffff))
        end
    end

    -- linha de chegada (fases sem combate)
    if not LOOPING then
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
    end

    -- obstaculos
    for _, o in ipairs(obstacles) do
        local x = flr(wrap(o.x - cam, LOOP))
        if x > -30 and x < 500 then
            if o.kind == "b" then
                draw_barrier(x, GROUND)
            else
                draw_hsign(x, GROUND, P.tag)
            end
        end
    end

    -- cartoes
    for i, c in ipairs(cards) do
        if not c.got then
            local x = wrap(c.x - cam, LOOP)
            if x > -30 and x < 510 then
                local bob = math.sin((Frame_now + i * 7) * 0.12) * 2
                P.draw_card(x, c.y + bob)
            end
        end
    end
end

local function draw_player(frame)
    local y = flr(p.y)
    local slide = p.slide > 0
    if p.beam > 0 then
        local cy = slide and y - 7 or y - 16
        draw_beam(0, PLAYER_X - 4, cy, frame)
    end
    if not (p.inv > 0 and flr(p.inv / 4) % 2 == 0) then
        draw_runner(PLAYER_X, y, slide, p.onground and frame or 0)
    end
    if p.shield > 0 then draw_shield(PLAYER_X, y, slide) end
end

local function draw_bosses(frame)
    for i, b in ipairs(bosses) do
        local x = flr(b.sx)
        if x > -40 then
            local y = GROUND - flr(math.abs(math.sin(frame * 0.3 + i)) * 3)
            if not (b.flash > 0 and flr(b.flash / 2) % 2 == 0) then
                b.def.draw(x, y, frame)
            end
            if b.dead then
                ui.print("KO", x + 2, GROUND - 64, C(0xffffff))
            elseif P.combat and b.timer <= 40 and state == "run" and flr(frame / 4) % 2 == 0 then
                ui.print("!", x + 7, GROUND - 64, C(0xac3232))
            end
        end
    end
    for _, s in ipairs(shots) do
        bosses[s.owner].def.shot(s.x, s.y, s.dir)
    end
end

local function bar(x, y, w, frac, fg, h)
    h = h or 4
    ui.rectfill(x, y, x + w, y + h, C(0x222034))
    if frac > 0 then ui.rectfill(x, y, x + flr(w * frac), y + h, fg) end
end

local function draw_hud(frame)
    -- cartoes coletados
    P.draw_card(22, 12)
    ui.print("x " .. collected, 40, 8, C(0xffffff))

    -- distancia dos presidentes
    ui.print("FUGA", 8, 24, C(0xffffff))
    bar(40, 25, 80, gap, gap < 0.5 and C(0xac3232) or C(0xfbf236))

    if P.kame then
        -- energia do kamehameha
        ui.print("KAME", 8, 36, C(0xffffff))
        local full = energy >= ENERGY_MAX
        local ecol = (full and flr(frame / 8) % 2 == 0) and C(0xffffff) or C(0x5fcde4)
        bar(40, 37, 80, energy / ENERGY_MAX, ecol)
        if full then
            ui.print("A /", 126, 36, C(0x5fcde4))
            draw_arrow(146, 36, "right", C(0x5fcde4))
        end
    end

    if P.combat then
        -- vida dos presidentes
        -- nome em cima e barra embaixo, todas do mesmo tamanho
        -- (a do Kim, o chefe mais forte, e um pouco maior)
        local multi = #bosses > 1
        for i, b in ipairs(bosses) do
            local x, y = 340, 6
            if multi then
                x = 190 + ((i - 1) % 2) * 150
                y = 6 + flr((i - 1) / 2) * 20
            end
            local big = b.def == BOSS_DEFS.kim
            local ncol = C(0xffffff)
            if b.dead then
                ncol = C(0x847e87)
            elseif multi and boss_active(i) then
                ncol = C(0xfbf236)   -- presidente da vez em amarelo
            end
            ui.print(b.def.name, x, y, ncol)
            bar(x, y + 9, big and 130 or 100, b.hp / b.maxhp, C(0xac3232), big and 5 or 4)
        end
    else
        -- progresso ate a chegada
        local bx0, bx1 = 200, 460
        ui.print("CHEGADA", bx0, 8, C(0xffffff))
        local px = bx0 + 48
        bar(px, 9, bx1 - px, ui.mid(0, p.x / FINISH, 1), C(0x6abe30))
    end

    -- aviso de troca no revezamento
    if turn_msg > 0 and runT >= 150 and not p.won then
        local s = "VEZ DO " .. bosses[turn].def.name .. "!"
        ui.rectfill(cx(s) - 8, 54, 480 - cx(s) + 8, 70, C(0x222034))
        ui.print(s, cx(s), 59, C(0xfbf236))
    end

    -- aviso de inicio de fase
    if runT < 150 then
        local s = phase_name(phase)
        local s2 = (P.combat and "DERROTE " or "FUJA DO ") .. boss_names() .. "!"
        local bx = math.min(cx(s), cx(s2)) - 8
        ui.rectfill(bx, 54, 480 - bx, 84, C(0x222034))
        ui.print(s, cx(s), 59, C(0xfbf236))
        ui.print(s2, cx(s2), 73, C(0xffffff))
    end
    if p.won and flr(frame / 10) % 2 == 0 then
        local s = #bosses > 1 and "PRESIDENTES DERROTADOS!" or "PRESIDENTE DERROTADO!"
        ui.print(s, cx(s), 96, C(0xfbf236))
    end
end

local function panel(lines, y0)
    y0 = y0 or 50
    local y1 = y0 + #lines * 14 + 12
    ui.rectfill(70, y0, 410, y1, C(0x222034))
    ui.rect(70, y0, 410, y1, C(0xffffff))
    for i, ln in ipairs(lines) do
        ui.print(ln[1], cx(ln[1]), y0 + 8 + (i - 1) * 14, C(ln[2]))
    end
end

-- ===================================================================
-- Como jogar: uma pagina por botao (botao do controle + seta)
-- ===================================================================
local HOWTO = {
    jump = { title = "PULAR", pad = "X", arrow = "up", demo = "jump",
             text = { "PULE AS BARREIRAS AMARELAS", "E PEGUE OS CARTOES NO ALTO." } },
    slide = { title = "DESLIZAR", pad = "B", arrow = "down", demo = "slide",
              text = { "DESLIZE POR BAIXO DAS PLACAS.", "SEGURE PARA CONTINUAR DESLIZANDO." } },
    dodge = { title = "DESVIAR", pad = "B", arrow = "down", demo = "dodge",
              text = { "O TIRO PASSA POR CIMA SE VOCE DESLIZAR", "E POR BAIXO SE VOCE PULAR (X)." } },
    reflect = { title = "REFLETIR", pad = "Y", arrow = "left", demo = "reflect",
                text = { "AGORA O PRESIDENTE ATIRA EM VOCE!", "QUANDO O TIRO CHEGAR, APERTE PARA DEVOLVER." } },
    kame = { title = "KAMEHAMEHA", pad = "A", arrow = "right", demo = "kame",
             text = { "JUNTE 10 CARTOES PARA CARREGAR.", "O RAIO CAUSA 3X MAIS DANO NO PRESIDENTE!" } },
    goal_run = { title = "OBJETIVO", demo = "goal_run",
                 text = { "FUJA DO PRESIDENTE ATE A CHEGADA.", "PEGUE CARTOES PARA FAZER PONTOS.", "SE ELE TE ALCANCAR, VOCE PERDE!" } },
    goal_combat = { title = "COMBATE", demo = "reflect",
                    text = { "REFLITA OS TIROS ATE A VIDA DELE ACABAR.", "SE NAO DER, DESVIE PULANDO OU DESLIZANDO.", "SE ELE TE ALCANCAR, VOCE PERDE!" } },
    goal_final = { title = "BATALHA FINAL", demo = "goal_final",
                   text = { "OS PRESIDENTES SE REVEZAM ATRAS DE VOCE:", "TRUMP, LULA, XI E O KIM JONG UN,", "O MAIS FORTE DE TODOS!" } },
}

local ALL_HOWTO = { "jump", "slide", "reflect", "dodge", "kame", "goal_run" }

local function draw_demo(kind, frame)
    local bx0, by0, bx1, by1 = 100, 128, 380, 206
    local gy = by1 - 8
    ui.clip(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1)
    ui.rectfill(bx0, by0, bx1, by1, C(0x639bff))
    ui.rectfill(bx0, gy, bx1, by1, C(0x595652))

    if kind == "jump" then
        local t = frame % 100
        local ox = 390 - t * 3
        local u = (ox - 203) / 34
        local h = math.max(0, 1 - u * u) * 44
        draw_barrier(ox, gy)
        draw_runner(200, gy - h, false, h > 0 and 0 or frame)
    elseif kind == "slide" then
        local t = frame % 100
        local ox = 390 - t * 3
        draw_hsign(ox, gy, "USA")
        draw_runner(200, gy, ox > 165 and ox < 225, frame)
    elseif kind == "reflect" then
        local t = frame % 90
        draw_trump(130, gy, frame)
        if t < 40 then
            draw_tomahawk(150 + t * 2.6, gy - 20, 1)
        elseif t < 70 then
            draw_tomahawk(254 - (t - 40) * 4, gy - 20, -1)
        end
        draw_runner(262, gy, false, frame)
        if t >= 34 and t < 48 then
            draw_shield(262, gy, false)
            ui.print("Y!", 258, by0 + 6, C(0xffffff))
        end
        if t >= 66 and t < 80 then ui.print("-1", 132, by0 + 6, C(0xac3232)) end
    elseif kind == "dodge" then
        -- primeiro desliza por baixo do missil, depois pula por cima
        local t = frame % 120
        local sx = 110 + (t % 60) * 4.5
        if t < 60 then
            draw_runner(230, gy, sx > 185 and sx < 265, frame)
            ui.print("B", 232, by0 + 6, C(0xffffff))
        else
            local u = (sx - 236) / 50
            local h = math.max(0, 1 - u * u) * 40
            draw_runner(230, gy - h, false, h > 0 and 0 or frame)
            ui.print("X", 232, by0 + 6, C(0xffffff))
        end
        draw_nuke(sx, gy - 20, 1)
    elseif kind == "kame" then
        local t = frame % 120
        draw_kim(130, gy, frame)
        draw_runner(280, gy, false, frame)
        if t < 50 then
            bar(262, by0 + 8, 40, t / 50, C(0x5fcde4))
            draw_visa_card(240 + (t % 25) * 2, gy - 40)
        elseif t < 86 then
            draw_beam(100, 276, gy - 16, frame)
            ui.print("A!", 276, by0 + 6, C(0xffffff))
            ui.print("-3", 132, by0 + 6, C(0xac3232))
        end
    elseif kind == "goal_run" then
        draw_trump(150, gy, frame)
        draw_runner(250, gy, false, frame)
        draw_green_card(290, gy - 12)
        local fx = 340
        for i = 0, 6 do
            local col = (i % 2 == 0) and C(0x000000) or C(0xffffff)
            ui.rectfill(fx, gy - 70 + i * 10, fx + 5, gy - 61 + i * 10, col)
        end
    else
        draw_trump(110, gy, frame)
        draw_lula(140, gy, frame)
        draw_xi(170, gy, frame)
        draw_kim(200, gy, frame)
        draw_runner(290, gy, false, frame)
        draw_visa_card(330, gy - 12)
    end
    ui.clip(0, 0, 480, 270)
    ui.rect(bx0, by0, bx1, by1, C(0xffffff))
end

local function draw_howto(frame)
    local pg = HOWTO[howto_list[howto_page]]
    ui.rectfill(40, 16, 440, 240, C(0x222034))
    ui.rect(40, 16, 440, 240, C(0xfbf236))
    local s = "COMO JOGAR  " .. howto_page .. "/" .. #howto_list
    ui.print(s, cx(s), 22, C(0x847e87))
    ui.print(pg.title, cx(pg.title), 34, C(0xfbf236))

    -- botao do controle (losango Y X A B) ou a seta
    if pg.pad then
        draw_pad(200, 64, pg.pad)
        ui.print("OU", 232, 61, C(0x847e87))
        ui.rectfill(256, 54, 276, 72, C(0xffffff))
        ui.rectfill(257, 70, 275, 72, C(0x9badb7))
        draw_arrow(262, 58, pg.arrow, C(0x000000))
    end

    local ty = pg.pad and 86 or 56
    for i, ln in ipairs(pg.text) do
        ui.print(ln, cx(ln), ty + (i - 1) * 12, C(0xffffff))
    end

    draw_demo(pg.demo, frame)

    local last = howto_page == #howto_list
    local foot = last and (howto_then == "menu" and "B: MENU   A: VOLTAR" or "B: JOGAR!   A: VOLTAR")
        or "B: PROXIMO   A: VOLTAR"
    if flr(frame / 30) % 2 == 0 or not last then
        ui.print(foot, cx(foot), 222, C(0xcbdbfc))
    end
end

local function update_howto()
    if pressed_ok() then
        if howto_page < #howto_list then
            howto_page = howto_page + 1
        elseif howto_then == "menu" then
            go_title()
        else
            start_phase(howto_then)
        end
    elseif pressed_back() then
        if howto_page > 1 then
            howto_page = howto_page - 1
        else
            go_title()
        end
    end
end

-- ===================================================================
-- Menu inicial
-- ===================================================================
local function menu_items()
    local items = {
        { label = "JOGAR", action = "play" },
        { label = "COMO JOGAR", action = "howto" },
        { label = "TESTAR CONTROLE", action = "pad" },
    }
    for n, ph in ipairs(PHASES) do
        local label
        if ph.final then
            label = "BATALHA FINAL - COREIA"
        elseif ph.combat then
            label = "FASE " .. n .. " - COMBATE " .. ph.country
        else
            label = "FASE " .. n .. " - " .. ph.country
        end
        items[#items + 1] = { label = label, phase = n, locked = not unlocked }
    end
    return items
end

local unlock_msg = 0    -- tempo mostrando o aviso de fases liberadas

local function update_title()
    if unlock_msg > 0 then unlock_msg = unlock_msg - 1 end

    -- truque: pular + deslizar ao mesmo tempo libera todas as fases
    local jump_held = ui.btn(UP) or (PAD_X ~= nil and ui.btn(PAD_X))
    if jump_held and holding_slide() and (pressed_jump() or pressed_slide()) then
        if not unlocked then
            unlocked = true
            unlock_msg = 150
        end
        return
    end

    local items = menu_items()
    local count = unlocked and #items or 3
    if bp(DOWN) then menu_sel = menu_sel % count + 1 end
    if bp(UP) then menu_sel = (menu_sel - 2) % count + 1 end
    if pressed_ok() then
        local it = items[menu_sel]
        scores = {}
        if it.phase then
            single = true
            begin_phase(it.phase)
        elseif it.action == "play" then
            single = false
            begin_phase(1)
        elseif it.action == "pad" then
            state = "padtest"
        else
            show_howto(ALL_HOWTO, "menu")
        end
    end
end

local function draw_title(frame)
    local K = C(0x222034)
    ui.rectfill(110, 8, 370, 44, K)
    ui.rect(110, 8, 370, 44, C(0xfbf236))
    local t = "TRUMP'S RUN"
    ui.print(t, cx(t), 16, C(0xfbf236))
    t = "FUJA DOS PRESIDENTES PELO MUNDO"
    ui.print(t, cx(t), 30, C(0xffffff))

    local items = menu_items()
    local y0 = 50
    local y1 = y0 + #items * 14 + (unlocked and 8 or 22)
    ui.rectfill(120, y0, 350, y1, K)
    ui.rect(120, y0, 350, y1, C(0xffffff))
    for i, it in ipairs(items) do
        local y = y0 + 8 + (i - 1) * 14
        local col = C(0xffffff)
        if it.locked then
            col = C(0x847e87)
        elseif i == menu_sel then
            col = C(0xfbf236)
            if flr(frame / 15) % 2 == 0 then ui.print(">", 128, y, col) end
        end
        ui.print(it.label, cx(it.label), y, col)
    end
    if not unlocked then
        t = "ZERE O JOGO PARA ESCOLHER A FASE"
        ui.print(t, cx(t), y1 - 14, C(0xd77bba))
    elseif unlock_msg > 0 and flr(frame / 8) % 2 == 0 then
        t = "TODAS AS FASES LIBERADAS!"
        ui.rectfill(cx(t) - 6, y1 + 3, 480 - cx(t) + 6, y1 + 15, C(0x222034))
        ui.print(t, cx(t), y1 + 6, C(0xfbf236))
    end

    draw_trump(362, GROUND, frame)
    draw_lula(390, GROUND, frame)
    draw_xi(418, GROUND, frame)
    draw_kim(450, GROUND, frame)

    -- controles: setas para escolher, A para confirmar
    t = ": ESCOLHER   B: CONFIRMAR"
    local x = flr(240 - (20 + #t * FONT_W) / 2)
    draw_arrow(x, GROUND + 8, "up", C(0xffffff))
    draw_arrow(x + 10, GROUND + 8, "down", C(0xffffff))
    ui.print(t, x + 20, GROUND + 8, C(0xffffff))
end

-- ===================================================================
-- Teste do controle: mostra qual botao o jogo esta recebendo
-- ===================================================================
local function held(b) return b ~= nil and ui.btn(b) end

local function update_padtest()
    -- sai com START ou com L + R juntos
    if pressed_start() or (held(PAD_L) and held(PAD_R)) then go_title() end
end

local function draw_padtest(frame)
    local on, off = C(0xffffff), C(0x222034)
    ui.rectfill(30, 10, 450, 256, C(0x222034))
    ui.rect(30, 10, 450, 256, C(0xfbf236))
    local t = "TESTE DO CONTROLE"
    ui.print(t, cx(t), 18, C(0xfbf236))
    t = "APERTE CADA BOTAO: ELE DEVE ACENDER NO DESENHO"
    ui.print(t, cx(t), 32, C(0xffffff))

    -- ombros L e R
    ui.rectfill(100, 50, 170, 62, held(PAD_L) and on or C(0x847e87))
    ui.print("L", 132, 53, C(0x000000))
    ui.rectfill(310, 50, 380, 62, held(PAD_R) and on or C(0x847e87))
    ui.print("R", 342, 53, C(0x000000))

    -- corpo do controle estilo SNES
    ui.circfill(150, 105, 44, C(0xcbdbfc))
    ui.circfill(330, 105, 44, C(0xcbdbfc))
    ui.rectfill(150, 61, 330, 149, C(0xcbdbfc))

    -- select e start
    ui.rectfill(212, 112, 232, 118, held(PAD_SELECT) and on or C(0x595652))
    ui.rectfill(248, 112, 268, 118, held(PAD_START) and on or C(0x595652))
    ui.print("SEL", 213, 122, C(0x595652))
    ui.print("START", 244, 122, C(0x595652))

    -- direcional
    ui.rectfill(142, 83, 158, 127, C(0x595652))
    ui.rectfill(128, 97, 172, 113, C(0x595652))
    ui.rectfill(144, 85, 156, 96, held(UP) and on or off)
    ui.rectfill(144, 114, 156, 125, held(DOWN) and on or off)
    ui.rectfill(130, 99, 141, 111, held(LEFT) and on or off)
    ui.rectfill(159, 99, 170, 111, held(RIGHT) and on or off)

    -- botoes Y X A B (cores do Super Famicom)
    local face = {
        { "X", PAD_X, 330, 85, 0x5b6ee1 },
        { "Y", PAD_Y, 310, 105, 0x6abe30 },
        { "A", PAD_A, 350, 105, 0xac3232 },
        { "B", PAD_B, 330, 125, 0xfbf236 },
    }
    for _, f in ipairs(face) do
        local pressed = held(f[2])
        ui.circfill(f[3], f[4], 9, pressed and on or C(f[5]))
        ui.print(f[1], f[3] - 2, f[4] - 3, C(0x000000))
    end

    -- o que cada botao faz no jogo
    local rows = {
        { "X /", "PULAR", PAD_X, UP, "up" },
        { "B /", "DESLIZAR / CONFIRMAR", PAD_B, DOWN, "down" },
        { "Y /", "REFLETIR", PAD_Y, LEFT, "left" },
        { "A /", "KAMEHAMEHA / VOLTAR", PAD_A, RIGHT, "right" },
        { "L / R", "SEM USO", PAD_L, PAD_R },
    }
    for i, r in ipairs(rows) do
        local y = 154 + (i - 1) * 12
        local lit = held(r[3]) or held(r[4])
        local col = lit and C(0xfbf236) or C(0x9badb7)
        ui.print(r[1], 110, y, col)
        if r[5] then draw_arrow(132, y, r[5], col) end
        ui.print(r[2], 170, y, col)
    end
    t = "TECLADO: W A S D = DIRECIONAL   H=A  K=B  J=X  G=Y"
    ui.print(t, cx(t), 229, C(0x847e87))

    -- numeros brutos dos botoes apertados (ajuda a descobrir o Start)
    local ids = {}
    for id = 0, 20 do
        if ui.btn(id) then ids[#ids + 1] = tostring(id) end
    end
    t = "BOTOES (NUMERO): " .. (#ids > 0 and table.concat(ids, " ") or "-")
    ui.print(t, cx(t), 216, C(0x5fcde4))

    t = "START OU L+R: VOLTAR AO MENU"
    ui.print(t, cx(t), 242, C(0xcbdbfc))
end

-- ===================================================================
-- Cenario final (depois de vencer todos)
-- ===================================================================
local function draw_lying(x, body, hair, skin)
    ui.rectfill(x, GROUND - 8, x + 24, GROUND, body)
    ui.rectfill(x + 24, GROUND - 10, x + 34, GROUND, skin)
    ui.rectfill(x + 34, GROUND - 10, x + 38, GROUND, hair)
end

local function draw_ending(frame)
    REGION_SKY = 0x222034
    ui.cls(C(0x222034))
    for i = 0, 25 do
        ui.rectfill((i * 97) % 480, (i * 53) % 150, (i * 97) % 480, (i * 53) % 150, C(0xffffff))
    end

    -- fogos de artificio
    local cols = { 0xfbf236, 0xd77bba, 0x5fcde4, 0x6abe30, 0xdf7126 }
    for i = 0, 4 do
        local t = (frame + i * 23) % 70
        local fx = 50 + i * 95
        local fy = 170 - (i * 29) % 50 - 100
        if t < 40 then
            ui.circ(fx, fy, t, C(cols[i + 1]))
            ui.circ(fx, fy, flr(t / 2), C(cols[(i + 2) % 5 + 1]))
        end
    end

    -- todos os cenarios juntos
    lm_liberty(40)
    lm_rio(140)
    lm_pequim(300)
    lm_pyongyang(440)

    ui.rectfill(0, GROUND, 480, 270, C(0x595652))
    ui.rectfill(0, GROUND, 480, GROUND + 3, C(0x847e87))

    -- podio com o heroi
    ui.rectfill(222, GROUND - 22, 262, GROUND, C(0xd9a066))
    ui.print("1", 239, GROUND - 16, C(0x000000))
    draw_runner(236, GROUND - 22, false, 0)
    ui.rectfill(238, GROUND - 46, 246, GROUND - 38, C(0xfbf236))
    ui.rectfill(241, GROUND - 38, 243, GROUND - 33, C(0xfbf236))

    -- presidentes nocauteados
    draw_lying(40, C(0x3f3f74), C(0xfbf236), C(0xd9a066))
    draw_lying(110, C(0xac3232), C(0x8a6f30), C(0xeec39a))
    draw_lying(300, C(0x306082), C(0x000000), C(0xeec39a))
    draw_lying(370, C(0x323c39), C(0x000000), C(0xeec39a))
    for _, x in ipairs({ 40, 110, 300, 370 }) do
        local a = frame * 0.15
        ui.print("*", x + 30 + flr(math.cos(a) * 8), GROUND - 22 + flr(math.sin(a) * 3), C(0xfbf236))
    end
end

-- ===================================================================
-- Loop principal
-- ===================================================================
Frame_now = 0
go_title()

function loop(frame)
    Frame_now = frame

    for i = 1, #Palette do
        local color = Palette[i]
        ui.palset(i - 1, color)
    end

    ui.clip(0, 0, 480, 270)
    ui.camera(0, 0)

    if state == "title" then
        update_title()
    elseif state == "howto" then
        update_howto()
    elseif state == "padtest" then
        update_padtest()
    elseif state == "run" then
        if pressed_start() then
            state = "pause"
        else
            update_run()
        end
    elseif state == "pause" then
        if pressed_start() or pressed_ok() then
            state = "run"
        elseif pressed_back() then
            go_title()
        end
    else
        endT = endT + 1
        if state == "caught" then
            for i, b in ipairs(bosses) do
                if not b.dead then
                    b.sx = b.sx + ((boss_active(i) and PLAYER_X - 12 or -90) - b.sx) * 0.1
                end
            end
        end
        if endT > 30 then
            if pressed_ok() then
                if state == "clear" then
                    begin_phase(phase + 1)
                elseif state == "win" then
                    go_title()
                else
                    start_phase(phase)
                end
            elseif pressed_back() and state == "caught" then
                go_title()
            end
        end
    end

    local blink = flr(frame / 30) % 2 == 0
    local ending = state == "win" and not single

    if state == "title" or state == "howto" or state == "padtest" then
        local cam = frame * 1.5
        draw_world(cam, cam, true)
    elseif ending then
        draw_ending(frame)
    else
        draw_world(p.x - PLAYER_X, p.dist, false)
        draw_bosses(frame)
        draw_player(frame)
        draw_hud(frame)
    end

    if state == "title" then
        draw_title(frame)
    elseif state == "howto" then
        draw_howto(frame)
    elseif state == "padtest" then
        draw_padtest(frame)
    elseif state == "pause" then
        panel({
            { "PAUSA", 0xfbf236 },
            { "", 0xffffff },
            { phase_name(phase), 0xffffff },
            { "", 0xffffff },
            { "START OU B: CONTINUAR", 0xcbdbfc },
            { "A: VOLTAR AO MENU", 0xcbdbfc },
        }, 70)
    elseif state == "clear" then
        local nxt = PHASES[phase + 1]
        local who
        if nxt.final then
            who = "TODOS OS PRESIDENTES + KIM JONG UN!"
        elseif nxt.combat then
            who = "AGORA O " .. BOSS_DEFS[nxt.bosses[1].id].name .. " VAI ATIRAR!"
        else
            who = "CUIDADO COM O " .. BOSS_DEFS[nxt.bosses[1].id].name .. "!"
        end
        local msg = P.combat and ("VOCE DERROTOU O " .. boss_names() .. "!") or ("VOCE ESCAPOU DO " .. boss_names() .. "!")
        local pts = collected * 100 + (P.combat and #bosses * 1000 or 0)
        panel({
            { msg, 0x6abe30 },
            { "", 0xffffff },
            { P.card .. ": " .. collected, 0xfbf236 },
            { "PONTUACAO: " .. pts, 0xffffff },
            { "", 0xffffff },
            { "PROXIMA: " .. phase_name(phase + 1), 0xffffff },
            { who, 0xac3232 },
            { "", 0xffffff },
            { blink and "APERTE B PARA CONTINUAR" or "", 0xcbdbfc },
        })
    elseif state == "win" and single then
        local msg
        if P.final then
            msg = "VOCE DERROTOU TODOS OS PRESIDENTES!"
        elseif P.combat then
            msg = "VOCE DERROTOU O " .. boss_names() .. "!"
        else
            msg = "VOCE ESCAPOU DO " .. boss_names() .. "!"
        end
        local pts = collected * 100 + (P.combat and #bosses * 1000 or 0)
        panel({
            { msg, 0x6abe30 },
            { "", 0xffffff },
            { P.card .. ": " .. collected, 0xfbf236 },
            { "PONTUACAO: " .. pts, 0xffffff },
            { "", 0xffffff },
            { blink and "APERTE B PARA VOLTAR AO MENU" or "", 0xcbdbfc },
        })
    elseif state == "win" then
        local lines = { { "VOCE DERROTOU TODOS OS PRESIDENTES!", 0x6abe30 } }
        local total = 0
        for i, ph in ipairs(PHASES) do
            local s = scores[i]
            if s then
                total = total + s.cards * 100 + s.bosses * 1000
                local name = ph.final and "FINAL" or ((ph.combat and "COMBATE " or "") .. ph.country)
                lines[#lines + 1] = { name .. ": " .. s.cards .. " CARTOES", 0xfbf236 }
            end
        end
        lines[#lines + 1] = { "PONTUACAO TOTAL: " .. total, 0xffffff }
        lines[#lines + 1] = { blink and "APERTE B PARA VOLTAR AO MENU" or "FASES LIBERADAS NO MENU!", 0xcbdbfc }
        panel(lines, 4)
    elseif state == "caught" and endT > 40 then
        local who = "O " .. bosses[P.rotate and turn or 1].def.name .. " TE PEGOU!"
        panel({
            { who, 0xac3232 },
            { "", 0xffffff },
            { "LOCAL: " .. REGIONS[region_at(p.x)].name, 0xffffff },
            { P.card .. ": " .. collected, 0xfbf236 },
            { "", 0xffffff },
            { blink and "B: TENTAR DE NOVO" or "", 0xcbdbfc },
            { "A: VOLTAR AO MENU", 0xcbdbfc },
        })
    end
end
