# Avaliação do `supervision` para o VIGIA

Este repositório contém uma cópia integral do [roboflow/supervision](https://github.com/roboflow/supervision)
(licença MIT, © 2022 Roboflow — ver `LICENSE.md`), importada em 2026-10-24.

- Commit de origem: `88c28fd0acab1622be496a9c67d7546bef4443aa`
- Versão do pacote: `0.32.0.dev`
- Python suportado: 3.10 a 3.13

## O que é

Biblioteca Python de utilitários para visão computacional. Ela **não treina nem roda modelos**:
recebe as saídas de detectores (YOLO/Ultralytics, Roboflow Inference, Transformers, SAM, VLMs etc.)
e oferece ferramentas em volta delas:

| Módulo (`src/supervision/`) | Para que serve |
|---|---|
| `detection/` | Classe `sv.Detections` (formato único para qualquer modelo), `LineZone` (contagem por cruzamento de linha), `PolygonZone` (presença em área), `InferenceSlicer` (SAHI, objetos pequenos), smoothing, NMS |
| `annotators/` | Desenho de caixas, rótulos, máscaras, trilhas, heatmap, desfoque/pixelização |
| `utils/video.py` | Leitura/escrita de vídeo e iteração por frames (via PyAV) |
| `dataset/` | Carregar/converter datasets YOLO, COCO, Pascal VOC |
| `metrics/` | mAP, precisão, recall, F1, matriz de confusão |
| `key_points/`, `depth/`, `classification/` | Pose, mapas de profundidade, classificação |
| `_cv2/` | Backend em NumPy puro: funciona **sem OpenCV instalado** |

Tamanho: ~49 mil linhas de código em `src/` e ~67 mil linhas de testes em `tests/`.

## Resultados dos testes (executados nesta cópia)

| Verificação | Resultado |
|---|---|
| `pytest` (suíte completa, sem OpenCV) | **6024 passaram, 0 falharam**, 132 pulados (todos exigem OpenCV como referência) — ~90 s |
| `ruff check` | sem erros |
| `ruff format --check` | 217 arquivos já formatados |
| Teste rápido: `LineZone` + `PolygonZone` + `BoxAnnotator`/`LabelAnnotator` | funciona; objeto atravessando a linha contado corretamente (`in=1`) |

Para reproduzir:

```bash
uv sync --frozen --group dev --extra metrics
uv run pytest -q
```

## Pontos fortes para o VIGIA

- **Contagem e zonas prontas**: `LineZone` e `PolygonZone` resolvem diretamente casos de vigilância
  (pessoas entrando/saindo, invasão de área, ocupação).
- **Independente do modelo**: dá para trocar o detector sem reescrever o resto do pipeline.
- **Privacidade**: `BlurAnnotator` e `PixelateAnnotator` permitem anonimizar rostos/placas.
- **Qualidade alta**: suíte de testes grande, tipagem, lint e CI multiplataforma (Linux/Windows/macOS).
- **Licença MIT**: permite uso comercial e modificação, desde que o aviso de copyright seja mantido.
- **Dependências leves**: numpy, scipy, pillow, av, matplotlib — OpenCV é opcional.

## Pontos de atenção

- **Rastreamento (tracking) saiu da biblioteca.** `sv.ByteTrack` foi removido na 0.31
  (confirmado: `sv.ByteTrack` não existe nesta versão). `LineZone` precisa de `tracker_id`,
  então para contar pessoas/veículos é preciso instalar o pacote `trackers` da Roboflow
  (`ByteTrackTracker`) ou outro rastreador.
- **Não inclui detector.** É preciso adicionar um modelo (ex.: `ultralytics` ou `inference`).
- **Versão de desenvolvimento** (`0.32.0.dev`): a API muda entre versões (há remoções programadas
  em `docs/deprecated.md`). Para produção, prefira fixar uma versão do PyPI.
- **Peso do repositório**: ~51 MB, a maior parte em notebooks de exemplo (`docs/notebooks/`, `demo.ipynb`).
- **Sem OpenCV** a biblioteca usa o fallback NumPy e emite um aviso; pode ser mais lenta. Para
  vídeo em tempo real, instale `opencv-python`.
- **Workflows do GitHub** (`.github/workflows/`) vieram junto. Os de publicação
  (`publish-*.yml`) dependem de segredos da Roboflow e vão falhar se forem disparados aqui;
  os de testes (`ci-tests.yml`) rodam em push/PR para `main`/`develop`.

## Recomendação

O `supervision` é uma base sólida para a camada de **análise e visualização** do VIGIA
(zonas, contagem, anotação, anonimização, vídeo). Para um sistema de vigilância completo, ele
deve ser combinado com:

1. um **detector** (ex.: YOLO via `ultralytics`);
2. um **rastreador** (pacote `trackers`);
3. a lógica própria do VIGIA (alertas, armazenamento, interface).

Em vez de manter uma cópia do código-fonte, considere usar `pip install supervision` como
dependência e deixar no VIGIA só o código próprio — assim as correções do projeto original
chegam por atualização de versão. Manter a cópia faz sentido apenas se você pretende modificar
a biblioteca internamente.
