"""Makes the int8 encoder and decoder from sherpa-onnx's float export.

sherpa-onnx's own script quantises only the MatMul weights, which leaves the
decoder's 51865-word embedding in float32 (about 106 MB for the base model).
Gather is quantised here too.

    python tools/speech/quantize.py PREFIX
reads PREFIX-encoder.onnx and PREFIX-decoder.onnx, writes
PREFIX-encoder.q8.onnx and PREFIX-decoder.q8.onnx, and PREFIX-decoder.s8.onnx
from PREFIX-decoder.slim.onnx when there is one (sherpa-onnx's own
.int8.onnx files are left as they are, to compare with).
"""
import os
import sys

import onnx

from onnxruntime.quantization import QuantType, quantize_dynamic

def prune(path):
    """Drops weights nothing uses any more (the float copies left behind)."""
    model = onnx.load(path)
    used = set()

    def walk(graph):
        for node in graph.node:
            used.update(node.input)
            for attr in node.attribute:
                if attr.g.node:
                    walk(attr.g)
                for sub in attr.graphs:
                    walk(sub)

    walk(model.graph)
    used.update(o.name for o in model.graph.output)
    kept = [i for i in model.graph.initializer if i.name in used]
    print("  pruned", len(model.graph.initializer) - len(kept), "unused weights")
    del model.graph.initializer[:]
    model.graph.initializer.extend(kept)
    onnx.save(model, path)


def quantise(src, dst, ops):
    quantize_dynamic(model_input=src, model_output=dst, op_types_to_quantize=ops, weight_type=QuantType.QInt8)
    prune(dst)
    print(" ", os.path.basename(src), os.path.getsize(src) // 1024 // 1024, "MB ->", os.path.basename(dst), os.path.getsize(dst) // 1024 // 1024, "MB")


prefix = sys.argv[1]
quantise(f"{prefix}-encoder.onnx", f"{prefix}-encoder.q8.onnx", ["MatMul", "Gather"])
quantise(f"{prefix}-decoder.onnx", f"{prefix}-decoder.q8.onnx", ["MatMul", "Gather"])
# The decoder with its output layer apart from the embedding.
if os.path.exists(f"{prefix}-decoder.slim.onnx"):
    quantise(f"{prefix}-decoder.slim.onnx", f"{prefix}-decoder.s8.onnx", ["MatMul", "Gather"])
