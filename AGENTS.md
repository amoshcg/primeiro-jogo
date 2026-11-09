# Referência da API do Lupi (firmware 0.6.8)

Documentação completa: https://lupi.api.br/docs/

## Básico
- Tela: 480x270 pixels, 60 quadros por segundo.
- Paleta: até 256 cores por índice (0-255). Cores em BGR555 (`0BBBBBGGGGGRRRRR`).
- `game.lua` é o arquivo principal. O código fora de funções roda uma vez.
- `update(frame)` roda 60 vezes por segundo e recebe o número do quadro.
- A paleta zera a cada quadro: chame `ui.palset` no começo de `update`.
- `require "modulo"` carrega `modulo.lua`; `require "pasta.modulo"` carrega `pasta/modulo.lua`.
- Bibliotecas Lua: base, `table`, `string`, `math`, `utf8`. Não há `io` nem `os`.

## Gerados a partir do repositório
- `require "palette"`: global `Palette` com as cores dos PNGs. `Palette[i]` é a cor do índice `i - 1`.
- `Palette.hex("#rrggbb")` ou `Palette.hex(0xrrggbb)` e `Palette.rgb(r, g, b)`: índice da cor mais parecida.
- `require "sprites"`: global `Sprites` (somente leitura). `Sprites.pasta.arquivo` ou `Sprites.find("arquivo")`.
- Mapa do Tiled: `local mapa = require "maps.fase1"`; cada camada é `mapa.nome_da_camada`.
- Fonte em PNG: `local fonte = ui.register_font(require "font.minha_fonte")`.

## Constantes
- Botões: `LEFT`, `RIGHT`, `UP`, `DOWN`, `BTN_Z`, `BTN_X`, `BTN_F`, `BTN_G`, `BTN_Q`, `BTN_E`, `BTN_SYSTEM`.
- Zoom: `ZOOM_P5`, `ZOOM_P75`, `ZOOM_1X`, `ZOOM_1P25`, `ZOOM_1P5`, `ZOOM_1P75`, `ZOOM_2X`.
- Canais de música: `CH_1` a `CH_16`, `CH_ALL` (combine com `|`).
- Layout: `ALIGN_START`, `ALIGN_CENTER`, `ALIGN_END`, `LEFT_TO_RIGHT`, `TOP_TO_BOTTOM`.

## Tela (ui)
- `ui.cls([cor])`: limpa a tela (padrão: cor 1).
- `ui.palset(indice, cor)`: define uma cor da paleta (índice 0-255, cor BGR555).
- `ui.clip(x, y, w, h)` / `ui.clip()`: limita onde se desenha / volta pra tela toda.
- `ui.camera(x, y)` / `ui.camera()`: desloca tudo que é desenhado / volta pra (0, 0).
- `ui.fillp(b1, ..., b8)` / `ui.fillp()`: padrão 8x8 pras formas / volta pro sólido.

## Formas (ui)
- `ui.rect(x0, y0, x1, y1, cor)` e `ui.rectfill(x0, y0, x1, y1, cor)`.
- `ui.circ(x, y, raio, cor)` e `ui.circfill(x, y, raio, cor)`.
- `ui.line(x0, y0, x1, y1, cor)`.
- `ui.trisfill(x1, y1, x2, y2, x3, y3, cor)`.
- `ui.grid(x, y, largura_celula, altura_celula, linhas)`: `linhas` é uma tabela de linhas com índices de cor.

## Imagens (ui)
- `ui.spr(sprite, x, y, [virar_x], [virar_y])`: desenha o primeiro tile.
- `ui.tile(sprite, id, x, y, [virar_x], [virar_y])`: desenha o tile `id` de um sheet.
- `ui.map(camada, [x], [y])`: desenha uma camada de mapa do Tiled.
- `ui.img(linhas, x, y, [zoom])`: imagem feita de tabelas de índices (até 16 cores, até 511x511).
- `ui.load_lgf("nome")`: carrega `nome.lgf` (vem de `nome.gif`). Campos: `.frames`, `.width`, `.height`, `.loop`, `:delay(quadro)`.
- `ui.lgf(anim, x, y, quadro, [zoom], [coluna], [largura])`: desenha um quadro da animação.

## Texto (ui)
- `ui.print(texto, x, y, cor, [fonte])`.
- `ui.text_width(texto, [fonte])`: largura em pixels.
- `ui.register_font(tabela)`: registra uma fonte e devolve o id (até 2 por jogo).

## Entrada e sistema (ui)
- `ui.btn(botao, [jogador])` e `ui.btnp(botao, [jogador])`: `false` ou a pressão (1-255). Jogador 0-2.
- `ui.mouse()`: x, y, botões (bit 0 esquerdo, bit 1 direito), 0, 0. Mouse USB.
- `ui.peektext()` / `ui.readtext()`: próximo caractere do teclado USB, ou `nil`.
- `ui.stat(0)` memória Lua em bytes, `ui.stat(1)` uso de CPU, `ui.stat(7)` FPS.

## Layout
- `ui.layout(raiz)`: calcula e desenha a árvore.
- Nós: `Box()`, `Text("texto")`, `Image(sprite)`, `Custom(function(x, y, w, h) end)`.
- Nada é encadeado: cada configuração é uma linha, como `box.gap.set(4)`.
- Crie cada nó numa variável antes de `pai.add_child(filho)`.
- Box e Custom: `size.width.set_fixed|set_percentage|set_grow|set_fit`, o mesmo em `size.height`, `padding.set_all(px)`, `padding.set(cima, direita, baixo, esquerda)`, `gap.set(px)`, `set_direction(dir)`, `alignment.horizontal.set(a)`, `alignment.vertical.set(a)`, `color.set(cor)`, `corner.set_radius(px)`, `clip.set_vertical(b)`, `clip.set_horizontal(b)`, `clip.set_child_offset(x, y)`, `add_child(no)`, `remove()`, `set_visible(b)`.
- Cantos: `corner.set_top_left_radius`, `set_top_right_radius`, `set_bottom_left_radius`, `set_bottom_right_radius`, `set_top_radius`, `set_bottom_radius`, `set_left_radius`, `set_right_radius` (0-16 px).
- Text: `color.set`, `font.set_id`, `letter_spacing.set`, `line_height.set`, `set_visible`, `remove`.
- Image: `color.set`, cantos, `remove`.

## Áudio
- `music.play("nome", [fade])` e `music.loop("nome", [fade])`: toca `nome.las` (vem de `nome.fur`).
- `music.stop([fade])`.
- `music.volume(v, [canais], [fade])`: v de 0 a 1, canais como `CH_1 | CH_2`.
- `sfx.volume([v])`: volume geral de 0 a 1 (sem valor: 1).
- `fade` é sempre em segundos, de 0 a 10.

## Util
- `util.clamp(v, a, b)`, `util.sign(v)`, `util.round(v)`, `util.approach(atual, alvo, passo)`.
- `util.lerp(a, b, t)`, `util.wrap(v, min, max)`, `util.flash(frame, hz)`, `util.remap(v, a1, b1, a2, b2)`.
- `util.vec_normalize(v, [saida])`, `util.vec_dist(a, b)`, `util.vec_dist_sq(a, b)`, `util.vec_from_angle(ang, [tam], [saida])`.
- `util.point_in_rect(p, r)`, `util.point_in_circ(p, c)`, `util.rect_overlap(a, b)`, `util.circ_overlap(a, b)`, `util.circ_rect_overlap(c, r)`.
- Vetores, retângulos e círculos são tabelas com `x`, `y`, `w`, `h`, `r`.
