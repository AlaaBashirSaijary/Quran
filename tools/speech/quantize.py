"""Makes the int8 encoder and decoder from sherpa-onnx's float export.

sherpa-onnx's own script quantises only the MatMul weights, which leaves the
decoder's 51865-word embedding in float32 (about 106 MB for the base model).
Gather is quantised here too.

    python tools/speech/quantize.py PREFIX
reads PREFIX-encoder.onnx and PREFIX-decoder.onnx, writes
PREFIX-encoder.q8.onnx and PREFIX-decoder.q8.onnx (sherpa-onnx's own
.int8.onnx files are left as they are, to compare with).
"""
import os
import sys

from onnxruntime.quantization import QuantType, quantize_dynamic

prefix = sys.argv[1]
for part in ("encoder", "decoder"):
    src = f"{prefix}-{part}.onnx"
    dst = f"{prefix}-{part}.q8.onnx"
    quantize_dynamic(
        model_input=src,
        model_output=dst,
        op_types_to_quantize=["MatMul", "Gather"],
        weight_type=QuantType.QInt8,
    )
    print(part, os.path.getsize(src) // 1024 // 1024, "MB ->", os.path.getsize(dst) // 1024 // 1024, "MB")
