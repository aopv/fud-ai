# Local non-generative matting experiment

Experimental candidates only; no production artwork was overwritten.

## Runtime

- Python: `/tmp/fudai-workout-matting.FCLmtL/venv/bin/python` (3.13.1).
- Packages: rembg 2.0.83, NumPy 2.5.2, SciPy 1.18.1, OpenCV-headless 5.0.0.93, ONNXRuntime 1.29.0, Pillow 12.3.0.
- Model cache: `/tmp/fudai-workout-matting.FCLmtL/models/models/birefnet-general-lite/birefnet-general-lite.onnx` (224 MB, rembg download checksum verified).
- Explicit model: `birefnet-general-lite`. No cloud API or image-upload service was used. Images remain local; only public model weights were downloaded.
- The [official BiRefNet-lite model card](https://huggingface.co/ZhengPeng7/BiRefNet_lite) declares MIT licensing. [rembg documentation](https://github.com/danielgatis/rembg) describes local model sessions and warns that its separate BRIA default needs a commercial agreement. This experiment never selects that default.

## Result

The model's complete predicted mask is unsafe as a replacement alpha channel: it removed 54,894 nonpale pixels from Band Skull Crusher, including much of the bench. A hybrid gate performed much better:

1. Composite existing RGBA on uniform white for inference, so arbitrary RGB under transparent pixels cannot mislead segmentation.
2. Locate existing pale connected components (`minRGB >= 185`, channel spread `<= 18`, source alpha `>= 16`).
3. Treat a component as a removal candidate only if at least 80% of its pixels have predicted foreground alpha below 64.
4. Change alpha only, never RGB. Preserve every nonpale pixel, regardless of neural mask.
5. For mixed connected foreground/background, additionally limit removal to pixels whose predicted alpha is below 128. This guard is conservative and can leave remnants requiring review.

## Visually inspected candidates

| Frame | Warm CPU inference | Result |
| --- | ---: | --- |
| Band Skull Crusher male 2 | 7.353 s | Enclosed checkerboard and circular bench openings cleared; bench, red band strands, and white soles preserved. Full neural mask rejected because it deletes bench. |
| Barbell Ab Rollout male 2 | 6.518 s | White enclosed arm gap cleared; bar, weights, and white shoe soles retained. |
| Kipping Muscle Up female 2 | 7.040 s | Enclosed pale strip between suspension straps cleared; straps, rings, body, and white sole retained. |
| Barbell Full Squat male 2 | 4.624 s | Pale floor patch cleared with white shoe soles intact; a few original 1-pixel light edge specks remain. Guarded and unguarded candidates match here. |
| Band Pull Apart male 0 | 6.131 s | Both tiny loop holes cleared (109 and 113 pixels); red strands and white soles remain intact. Guarded mask leaves 11 uncertain edge pixels. |
| Band Pull Apart female 0 | 6.154 s | Both tiny loop holes cleared (109 and 106 pixels); red strands and white soles remain intact. Guarded mask leaves 8 uncertain edge pixels. |

All six source hashes remained unchanged; candidate RGB changes were zero. This is evidence from six frames, not validation of all 7,000. Connected shoe/floor regions, white equipment, and model mistakes still require rejection guards and visual review. Learned masks must not be used to drop dark equipment or change poses. In particular, a model that mistakenly calls the bench background could also falsely approve a genuine pale bench highlight; hybrid gating is helpful but not a semantic guarantee.

CPU timings use four inference threads and a reused 1024-square model session on the local 10-core machine. Initial package import and model download are extra; measured model load after caching was 0.97 seconds. A blanket 7,000-frame pass would be hours, not minutes. Cheap candidate detection should restrict neural inference to suspicious cases and retain cached masks.

The loaded ONNX model's input was directly verified as `[1, 3, 1024, 1024]`. A 512-square feed is not supported by this fixed graph; no lower-resolution quality or speed claim is made.

A six-thread CPU test took 8.961 seconds for Band Skull Crusher male 2 under current load, slower than the four-thread baseline. Default CoreML/ANE model loading was stopped after about three minutes without a completed inference. A second documented MLProgram / CPUAndGPU configuration with static shapes and caching failed compilation: `atrous_conv/Conv: Required param 'pad' is missing`. Therefore no CoreML acceleration is verified; both experimental processes ended. Provider options were taken from [ONNX Runtime's official CoreML documentation](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html).

## Files

- `prototype_local_matting.py`: reproduction script with explicit local model/provider.
- `local-matting-birefnet-general-lite.json`: first three sample timings and component decisions.
- `local-matting-birefnet-general-lite-squat-test.json`: harder floor/sole example.
- `local-matting-birefnet-general-lite-band-loop-test.json`: tiny band openings.
- `*-comparison.png`: original, unsafe full-neural mask, and hybrid mask on dark background.
- `*-hybrid-candidate.png` / `*-guarded-candidate.png`: experimental RGBA outputs.

Any production implementation and further acceptance review remains with the main task.
