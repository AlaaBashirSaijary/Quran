"""Converts a Hugging Face Whisper checkpoint to the openai-whisper format,
which sherpa-onnx's export script reads.

    python tools/speech/hf_to_openai.py --model tarteel-ai/whisper-base-ar-quran --out quran-base.pt

The layer names differ between the two libraries; the weights are the same.
"""
import argparse
import sys

import torch
from transformers import WhisperForConditionalGeneration

# Replacements in order; each turns a Hugging Face name into openai's.
RENAMES = [
    ("encoder.layers", "encoder.blocks"),
    ("decoder.layers", "decoder.blocks"),
    (".self_attn_layer_norm", ".attn_ln"),
    (".self_attn.k_proj", ".attn.key"),
    (".self_attn.q_proj", ".attn.query"),
    (".self_attn.v_proj", ".attn.value"),
    (".self_attn.out_proj", ".attn.out"),
    (".encoder_attn_layer_norm", ".cross_attn_ln"),
    (".encoder_attn.k_proj", ".cross_attn.key"),
    (".encoder_attn.q_proj", ".cross_attn.query"),
    (".encoder_attn.v_proj", ".cross_attn.value"),
    (".encoder_attn.out_proj", ".cross_attn.out"),
    (".fc1", ".mlp.0"),
    (".fc2", ".mlp.2"),
    (".final_layer_norm", ".mlp_ln"),
    ("encoder.layer_norm", "encoder.ln_post"),
    ("decoder.layer_norm", "decoder.ln"),
    ("encoder.embed_positions.weight", "encoder.positional_embedding"),
    ("decoder.embed_positions.weight", "decoder.positional_embedding"),
    ("decoder.embed_tokens", "decoder.token_embedding"),
]


def rename(key: str) -> str:
    for old, new in RENAMES:
        key = key.replace(old, new)
    return key


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    hf = WhisperForConditionalGeneration.from_pretrained(args.model)
    cfg = hf.config
    print("config:", {k: getattr(cfg, k) for k in (
        "num_mel_bins", "max_source_positions", "d_model", "encoder_attention_heads",
        "encoder_layers", "vocab_size", "max_target_positions",
        "decoder_attention_heads", "decoder_layers")})
    if cfg.vocab_size != 51865:
        print(f"vocab_size is {cfg.vocab_size}, not 51865: the tokenizer would not match", file=sys.stderr)
        return 1

    dims = {
        "n_mels": cfg.num_mel_bins,
        "n_audio_ctx": cfg.max_source_positions,
        "n_audio_state": cfg.d_model,
        "n_audio_head": cfg.encoder_attention_heads,
        "n_audio_layer": cfg.encoder_layers,
        "n_vocab": cfg.vocab_size,
        "n_text_ctx": cfg.max_target_positions,
        "n_text_state": cfg.d_model,
        "n_text_head": cfg.decoder_attention_heads,
        "n_text_layer": cfg.decoder_layers,
    }
    state = {rename(k): v for k, v in hf.model.state_dict().items()}

    # Check the names against what openai-whisper expects before saving.
    import whisper
    from whisper.model import ModelDimensions, Whisper

    reference = Whisper(ModelDimensions(**dims))
    result = reference.load_state_dict(state, strict=False)
    if result.unexpected_keys or result.missing_keys:
        print("missing:", result.missing_keys, file=sys.stderr)
        print("unexpected:", result.unexpected_keys, file=sys.stderr)
        return 1

    torch.save({"dims": dims, "model_state_dict": state}, args.out)
    print("saved", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
