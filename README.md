# Reaper-test-grid

Grade adaptativa nativa do REAPER calibrada para reproduzir os 24 níveis de
zoom medidos no modo **Ruler Marks** do ACID Pro.

Tudo é desenhado, clicado e processado pelo próprio REAPER. Não há bitmap,
linha sobreposta, janela ReaImGui, régua substituta nem interceptação de
clique. Nos níveis `21` a `23`, o zoom continua seguindo os vãos medidos no
ACID, mas grade e snap permanecem no limite nativo limpo de `1/1024`.

## O que é reproduzido

- 24 estados de zoom: nível inicial `0` mais 23 passos de zoom-in.
- Limite de zoom-out em 40 compassos no projeto 4/4.
- Limite de zoom-in em 45 ticks ACID (`1.1.000` até `1.1.045`).
- Largura temporal de cada passo copiada dos limites medidos: `80 s`, `58 s`,
  `44 s`, `30 s`, `22 s`, seguindo a tabela até `29,296875 ms`.
- Compensação da barra vertical interna de 18 px, da borda direita exclusiva
  e da margem final de 27 px medida com os dois arranges alinhados.
- Divisão nativa correspondente ao ACID nos níveis `0` a `20`.
- Grade e snap nativos fixados em `1/1024` nos níveis `21` a `23`.
- Clique, cursor, itens, loop points, time selection e arrastos inteiramente
  nativos em todos os níveis.
- Captura direta da roda sobre o arrange, sem cadastrar `Mousewheel` em
  `Actions` e sem alterar os Mouse Modifiers do REAPER.
- Zoom ancorado na posição do mouse, preservando sob o ponteiro o mesmo ponto
  da timeline ao aproximar ou afastar, como no ACID.
- Exibição das subdivisões pequenas com espaçamento visual mínimo de 1 px.
- Snap sempre sincronizado com a divisão visível enquanto o modo está ligado.

## Como funciona o limite nativo

O ReaScript consegue controlar a divisão real da grade com
`GetSetProjectGrid`, mas a API não permite substituir os textos, as linhas ou
os pontos de snap do motor nativo. No arrange, as divisões abaixo de `1/1024`
não se comportam como uma grade nativa utilizável. Por isso esta edição limpa
não tenta desenhar `1/2048` ou `1/4096`: os três últimos passos preservam o
zoom do ACID e mantêm a grade em `1/1024`.

O campo nativo de compassos do arrange/transport também mostra frações
decimais do beat, não os 768 ticks PPQ usados pelo ACID. Assim, a posição e o
tempo podem coincidir exatamente, mas um ponto que o ACID escreve como
`1.1.002` pode receber outro texto no campo nativo do REAPER. Reproduzir esse
texto ou as subdivisões finais literalmente exigiria um sistema gráfico e de
mouse personalizado; ele foi removido para preservar a interação nativa.

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
   `ACID Pro native clean grid - toggle 24-step mode (ReaPack v1.3.6)`.
3. Adicione essa ação ao toolbar.
4. Clique no botão para ligar o modo ACID completo. O botão fica aceso
   enquanto estiver ligado; clique novamente para desligar.
5. Use a roda do mouse sobre a área de arranjo. O serviço captura a roda
   diretamente e percorre os 24 níveis medidos, com limite nas duas pontas.
   Não atribua `Mousewheel` a nenhuma ação deste pacote.
6. Deixe `Snap/Grid` habilitado e marque a opção de snap ao grid.

O clique no toolbar é a única ativação necessária. Ao desligar o botão, o
serviço libera imediatamente a roda e o REAPER volta ao comportamento anterior.
Grade, snap, cursor, itens, loop points e time selection são nativos nos 24
níveis; apenas o tamanho horizontal do zoom é controlado pelo script.
O serviço também restaura o espaçamento mínimo de grid e a preferência
`Grid snap settings follow grid visibility` que estavam ativos antes de ligar.

Se ainda existir uma ação antiga com `(toolbar)` no nome ou cujo caminho
aponte para `Downloads\Acid grid`, remova esse botão antigo. Somente a ação com
`ReaPack v1.3.6` no nome recebe as atualizações automáticas deste repositório.

## Ação antiga de Mousewheel

A ação `ACID Pro native grid - 24-step mousewheel zoom` permanece no pacote
apenas por compatibilidade com instalações anteriores. Na versão atual ela não
precisa de atalho e não deve ser usada junto com o modo do toolbar.

## Arquivos

- `ACID_Pro_Native_Grid_Service.lua`: botão liga/desliga recomendado; captura
  a roda, aplica os 24 níveis e mantém desenho, snap e mouse totalmente
  nativos, limitando a menor divisão a `1/1024`.
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
