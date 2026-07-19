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
- Snap, loop points e time selection nativos, sem interceptação do mouse.

## Limitação do REAPER

O ReaScript consegue controlar a divisão real do grid com
`GetSetProjectGrid`, mas a API não permite escolher individualmente os textos
e risquinhos desenhados na régua nativa. Portanto, o espaçamento e o snap podem
ser iguais ao ACID, enquanto a quantidade/formatação dos rótulos continua sob
controle do REAPER.

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

## Uso recomendado: sem configurar o mouse

1. Pare e remova da inicialização o script antigo
   `ACID_Pro_Ruler_And_Cursor_Overlay.lua`.
2. Em `Actions`, procure por
   `ACID Pro native grid - toggle adaptive grid (toolbar)`.
3. Adicione essa ação ao toolbar.
4. Clique no botão para ligar o grid adaptativo ACID. O botão fica aceso
   enquanto estiver ligado; clique novamente para desligar.
5. Continue usando o zoom normal do REAPER. Não é necessário configurar o
   mousewheel, atalhos de zoom ou mouse modifiers.
6. Deixe `Snap/Grid` habilitado e marque a opção de snap ao grid.

Nesse modo, o REAPER mantém seu zoom contínuo normal e o serviço escolhe
automaticamente a divisão ACID mais próxima. O grid, o cursor, os loop points
e a time selection continuam totalmente nativos.

## Modo opcional: 24 passos e limites rígidos

Use `ACID Pro native grid - 24-step mousewheel zoom` somente se também quiser
que o zoom fique limitado exatamente aos 24 estados medidos no ACID Pro. Esse
modo exige atribuir o `Mousewheel` à ação. Ele não é necessário para usar o
grid adaptativo nativo pelo toolbar.

## Arquivos

- `ACID_Pro_Native_Grid_Mousewheel_Zoom.lua`: zoom rígido e mudança imediata
  do grid nativo.
- `ACID_Pro_Native_Grid_Service.lua`: botão liga/desliga recomendado; observa
  qualquer zoom nativo e sincroniza a divisão do grid.

## Requisitos

- REAPER 7 ou mais recente.
- Nenhuma extensão é necessária para o funcionamento principal.
- SWS é necessário somente se o serviço for iniciado automaticamente pelo
  recurso Startup Action.

## Créditos técnicos

A estratégia de grid nativo segue a mesma ideia usada pelos projetos
[Reaper-Tools](https://github.com/iliaspoulakis/Reaper-Tools/tree/master/Adaptive%20grid)
e
[reaper-reableton-scripts](https://github.com/edkashinsky/reaper-reableton-scripts):
observar o zoom e alterar a divisão real do projeto, deixando o REAPER cuidar
do desenho e da interação.

## Licença

MIT. Consulte `LICENSE`.
