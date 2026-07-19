# Reaper-test-grid

Grid adaptativo nativo do REAPER calibrado para reproduzir os 24 níveis de
zoom do modo **Ruler Marks** do ACID Pro.

Esta versão não desenha overlays, não cria janelas transparentes e não tenta
substituir o cursor do REAPER. As linhas, o snap, a seleção de tempo e os loop
points continuam sendo processados pelo próprio REAPER.

## O que é reproduzido

- 24 estados de zoom: nível inicial `0` mais 23 passos de zoom-in.
- Limite de zoom-out em 40 compassos no projeto 4/4.
- Limite de zoom-in em 45 ticks ACID (`1.1.000` até `1.1.045`).
- Divisão nativa do grid correspondente a cada nível.
- Quatro subdivisões nativas entre cada marca principal equivalente do ACID.
- Snap, loop points e time selection nativos.
- Captura direta da roda sobre o arrange, sem cadastrar `Mousewheel` em
  `Actions` e sem alterar os Mouse Modifiers do REAPER.
- Exibição das subdivisões pequenas com espaçamento visual mínimo de 1 px.
- Snap sempre sincronizado com a divisão visível enquanto o modo está ligado.

## Limitação do REAPER

O ReaScript consegue controlar a divisão real do grid com
`GetSetProjectGrid`, mas a API não permite escolher individualmente os textos
e risquinhos desenhados na régua nativa. Portanto, o espaçamento e o snap podem
ser iguais ao ACID, enquanto a quantidade/formatação dos rótulos continua sob
controle do REAPER.

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
   `ACID Pro native grid - toggle full ACID mode (ReaPack v1.2.2)`.
3. Adicione essa ação ao toolbar.
4. Clique no botão para ligar o modo ACID completo. O botão fica aceso
   enquanto estiver ligado; clique novamente para desligar.
5. Use a roda do mouse sobre a área de arranjo. O serviço captura a roda
   diretamente e percorre os 24 níveis medidos, com limite nas duas pontas.
   Não atribua `Mousewheel` a nenhuma ação deste pacote.
6. Deixe `Snap/Grid` habilitado e marque a opção de snap ao grid.

O clique no toolbar é a única ativação necessária. Ao desligar o botão, o
serviço libera imediatamente a roda e o REAPER volta ao comportamento anterior.
O grid, o cursor, os loop points e a time selection continuam nativos.
O serviço também restaura o espaçamento mínimo de grid e a preferência
`Grid snap settings follow grid visibility` que estavam ativos antes de ligar.

Se ainda existir uma ação antiga com `(toolbar)` no nome ou cujo caminho
aponte para `Downloads\Acid grid`, remova esse botão antigo. Somente a ação com
`ReaPack v1.2.2` no nome recebe as atualizações automáticas deste repositório.

## Ação antiga de Mousewheel

A ação `ACID Pro native grid - 24-step mousewheel zoom` permanece no pacote
apenas por compatibilidade com instalações anteriores. Na versão atual ela não
precisa de atalho e não deve ser usada junto com o modo do toolbar.

## Arquivos

- `ACID_Pro_Native_Grid_Service.lua`: botão liga/desliga recomendado; captura
  a roda no arrange, aplica os 24 níveis e sincroniza o grid nativo.
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
