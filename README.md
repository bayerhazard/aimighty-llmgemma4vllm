# Gemma 4 26B A4B Vision – vLLM + NVFP4 Deployment

**Multimodales LLM-Deployment (Text + Image) mit Speculative-Decoding-bereitem Stack**

## Architektur

```
Gemma 4 26B A4B (MoE, 25.2B total / 3.8B aktiv)
├── Quantisierung: NVFP4 (W4A4, ~15 GB)
├── Runtime: vLLM + Marlin MoE Backend
├── Speculative Decoding: EAGLE-3 (0.9B Drafter) - optional
├── Vision: ✅ Text + Image (256K Context)
└── GPU: RTX 5090 Laptop (24 GB VRAM)
```

## Spezifikationen

| Parameter | Wert |
|---|---|
| **Modell** | `bg-digitalservices/Gemma-4-26B-A4B-it-NVFP4` |
| **Quantisierung** | NVFP4 (NVIDIA 4-bit Weights + Activations) |
| **Qualität vs. BF16** | 97.6% Retention (gemessen: GSM8K, IFEval) |
| **Context** | 256K tokens |
| **Vision** | ✅ Text + Image (Multimodal) |
| **Runtime** | vLLM V1 + Marlin MoE Backend |
| **KV-Cache** | fp8_e4m3 |
| **GPU VRAM** | ~22.6 GB belegt, ~1.8 GB frei |
| **Speculators** | EAGLE-3 (optional, nicht bei Multimodal) |

## Performance

| Test | Ohne SpecDec | Mit EAGLE-3 |
|------|:-----------:|:-----------:|
| Short (100 tok) | 40 tok/s | ~55 tok/s* |
| Medium (500 tok) | 103 tok/s | ~129 tok/s* |
| Long (2000 tok) | 126 tok/s | ~148 tok/s* |
| Vision (200 tok) | 129 tok/s | ❌ nicht kompatibel |

\* Geschätzt anhand RedHatAI-Messungen. EAGLE-3 ist bei aktiviertem Multimodal derzeit nicht verfügbar.

## Deployment

### Voraussetzungen
- Olares-Server mit SSH-Zugang
- Kubernetes mit NVIDIA GPU-Runtime
- Internetzugriff auf HuggingFace

### Installieren
```bash
git clone https://github.com/bayerhazard/aimighty-llmgemma4vllm.git
cd aimighty-llmgemma4vllm
./deploy.sh olares@172.20.0.4
```

Der initContainer lädt das Modell (15 GB) automatisch von HuggingFace. Startup dauert ~15 Minuten.

### Deinstallieren
```bash
./cleanup.sh olares@172.20.0.4
```

## Patches

Das bg-digital NVFP4 Modell benötigt zwei Patches für vLLM:

| Patch | Datei | Zweck |
|-------|-------|-------|
| `gemma4.py` | `kubernetes/patches/gemma4.py` | NVFP4 MoE Scale-Key-Mapping (von bg-digital bereitgestellt) |
| `fused_moe_layer.py` | `kubernetes/patches/fused_moe_layer.py` | `reduce_results` Parameter für FusedMoE-Kompatibilität |

Beide werden als ConfigMaps gemountet und überschreiben die vLLM-Originale.

## API

```bash
# Text
curl -X POST http://<host>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-26b-a4b-nvfp4-vision",
    "messages": [{"role": "user", "content": "Hallo!"}],
    "max_tokens": 200
  }'

# Vision
curl -X POST http://<host>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-26b-a4b-nvfp4-vision",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "Beschreibe das Bild."},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<base64>"}}
      ]
    }],
    "max_tokens": 200
  }'
```

## Repo-Struktur

```
aimighty-llmgemma4vllm/
├── README.md
├── deploy.sh                  # Deployment-Skript
├── cleanup.sh                 # Cleanup-Skript
├── kubernetes/
│   ├── configmap.yaml         # vllm-env Konfiguration
│   ├── deployment.yaml        # vLLM Container + Patches
│   └── patches/
│       ├── gemma4.py           # NVFP4 Scale-Key-Patch
│       └── fused_moe_layer.py  # FusedMoE Kompatibilität
├── models/
│   └── download-models.sh     # Manuelles Download (Fallback)
```

## Stack-Komponenten

| Komponente | Version/Ort |
|---|---|
| **vLLM Image** | `vllm/vllm-openai:gemma4-0505-cu130` |
| **Base Model** | `google/gemma-4-26B-A4B-it` |
| **Quantisiert** | `bg-digitalservices/Gemma-4-26B-A4B-it-NVFP4` |
| **Speculator** | `RedHatAI/gemma-4-26B-A4B-it-speculator.eagle3` |
| **CUDA** | 13.1 (RTX 5090 Blackwell SM12.0) |

## Troubleshooting

| Symptom | Ursache | Lösung |
|---------|---------|--------|
| `FusedMoE.__init__() got unexpected keyword argument reduce_results` | Fehlender Patch | ConfigMap `fused-moe-patched` prüfen |
| `ModelOpt NVFP4 checkpoint` + Crash | Fehlender gemma4-Patch | ConfigMap `gemma4-patched` prüfen |
| Modell lädt nicht (Download-timeout) | Große Datei (15 GB) | Session aktiv halten, länger warten |
| Vision nicht verfügbar | `--limit-mm-per-prompt` gesetzt | Deployment-Args prüfen |
