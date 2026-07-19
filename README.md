# Reaper-test-grid

Grid adaptativo híbrido do REAPER calibrado para reproduzir os 24 níveis de
zoom do modo **Ruler Marks** do ACID Pro.

Nos níveis `0` a `20`, tudo é desenhado e processado pelo próprio REAPER. Nos
níveis `21` a `23`, o limite nativo de `1/1024` do arrange é insuficiente; o
script reforça todas as subdivisões finas com linhas uniformes de 1 pixel,
compostas diretamente na área do arrange a partir de pequenos bitmaps `1×1`.
Não há janela ReaImGui, régua substituta ou overlay flutuante.

## O que é reproduzido

- 24 estados de zoom: nível inicial `0` mais 23 passos de zoom-in.
- Limite de zoom-out em 40 compassos no projeto 4/4.
- Limite de zoom-in em 45 ticks ACID (`1.1.000` até `1.1.045`).
- Divisão nativa do grid correspondente aos níveis `0` a `20`.
- Subdivisões exatas de `1/2048` e `1/4096` nos níveis `21` a `23`.
- Clique simples corrigido para as subdivisões finas do ACID nos três últimos
  níveis, quando o snap está ligado.
- Loop points, time selection e arrastos continuam nativos e não são
  interceptados pelo desenho híbrido.
- Captura direta da roda sobre o arrange, sem cadastrar `Mousewheel` em
  `Actions` e sem alterar os Mouse Modifiers do REAPER.
- Exibição das subdivisões pequenas com espaçamento visual mínimo de 1 px.
- Snap sempre sincronizado com a divisão visível enquanto o modo está ligado.

## Como funciona o limite nativo

O ReaScript consegue controlar a divisão real do grid com
`GetSetProjectGrid`, mas a API não permite escolher individualmente os textos
e risquinhos desenhados na régua nativa. Além disso, o arrange do REAPER para
em `1/1024`; por isso os níveis `21` a `23` usam o complemento gráfico leve e
o ajuste de clique descritos acima. A quantidade e a formatação dos rótulos
continuam sob controle do REAPER.

O campo nativo de compassos do arrange/transport também mostra frações
decimais do beat, não os 768 ticks PPQ usados pelo ACID. Assim, a posição e o
tempo podem coincidir exatamente, mas um ponto que o ACID escreve como
`1.1.002` pode receber outro texto no campo nativo do REAPER. Reproduzir esse
texto literalmente exigiria novamente um mostrador personalizado; ele não é
usado neste pacote para preservar a interação nativa e evitar overlays.

## Instalação pelo ReaPack

Importe esta URL em `Extensions > ReaPack > Import repositories`:

```text
https://raw.githubusercontent.com/2TDaSerra/Reaper-test-grid/main/index.xml
```

Depois:

1. Abra `Extensions > ReaPack > Browse packages`.
2. Procure por `ACID Pro Native Grid`.
3. Clique com o botão direito no pacote e escolha `Install`.
4. Clique em `Apply`.

O ReaPack instala e registra automaticamente as duas ações na seção `Main`.
Não é necessário usar `New action > Load ReaScript`, nem repetir o processo
quando o pacote for atualizado.

## Uso: um botão, sem configurar o mouse

1. Pare e remova da inicialização o script antigo
   `ACID_Pro_Ruler_And_Cursor_Overlay.lua`.
2. Em `Actions`, procure por
   `ACID Pro hybrid grid - toggle full ACID mode (ReaPack v1.3.1)`.
3. Adicione essa ação ao toolbar.
4. Clique no botão para ligar o modo ACID completo. O botão fica aceso
   enquanto estiver ligado; clique novamente para desligar.
5. Use a roda do mouse sobre a área de arranjo. O serviço captura a roda
   diretamente e percorre os 24 níveis medidos, com limite nas duas pontas.
   Não atribua `Mousewheel` a nenhuma ação deste pacote.
6. Deixe `Snap/Grid` habilitado e marque a opção de snap ao grid.

O clique no toolbar é a única ativação necessária. Ao desligar o botão, o
serviço libera imediatamente a roda e o REAPER volta ao comportamento anterior.
Até o nível `20`, grid, cursor, loop points e time selection são totalmente
nativos. Nos níveis `21` a `23`, apenas as linhas ausentes e o clique simples
com snap recebem o complemento híbrido.
O serviço também restaura o espaçamento mínimo de grid e a preferência
`Grid snap settings follow grid visibility` que estavam ativos antes de ligar.

Se ainda existir uma ação antiga com `(toolbar)` no nome ou cujo caminho
aponte para `Downloads\Acid grid`, remova esse botão antigo. Somente a ação com
`ReaPack v1.3.1` no nome recebe as atualizações automáticas deste repositório.

## Ação antiga de Mousewheel

A ação `ACID Pro native grid - 24-step mousewheel zoom` permanece no pacote
apenas por compatibilidade com instalações anteriores. Na versão atual ela não
precisa de atalho e não deve ser usada junto com o modo do toolbar.

## Arquivos

- `ACID_Pro_Native_Grid_Service.lua`: botão liga/desliga recomendado; captura
  a roda, aplica os 24 níveis, mantém a grade nativa até o nível `20` e
  desenha as subdivisões uniformes de 1 pixel nos níveis `21` a `23`.
- `ACID_Pro_Native_Grid_Mousewheel_Zoom.lua`: ação legada mantida para
  compatibilidade.

## Requisitos

- REAPER 7 ou mais recente.
- `js_ReaScriptAPI: API functions for ReaScripts`, disponível pelo ReaPack.
- SWS, usado para aplicar e restaurar as opções nativas de densidade visual e
  de snap.

## Créditos técnicos

A estratégia de grid nativo segue a mesma ideia usada pelos projetos
[Reaper-Tools](https://github.com/iliaspoulakis/Reaper-Tools/tree/master/Adaptive%20grid)
e
[reaper-reableton-scripts](https://github.com/edkashinsky/reaper-reableton-scripts):
observar o zoom e alterar a divisão real do projeto, deixando o REAPER cuidar
do desenho e da interação.

## Licença

MIT. Consulte `LICENSE`.
