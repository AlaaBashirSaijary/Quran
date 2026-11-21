"""Makes the decoder's output layer a weight of its own, so it can be quantised.

Whisper uses the word embedding both to look words up and, transposed, to
score them. In the exported graph the 51865 x 512 matrix is the left operand
of the scoring MatMul, which dynamic quantisation leaves in float (106 MB).
Here that MatMul is rewritten so the matrix is the right operand, a weight
of its own (transposed once), which can be quantised.

    python tools/speech/slim_decoder.py IN.onnx OUT.onnx
"""
import sys

import numpy as np
import onnx
import onnx.helper
import onnx.shape_inference
from onnx import numpy_helper


def consumers(graph, name):
    return [n for n in graph.node if name in n.input]


def main() -> int:
    src, dst = sys.argv[1:3]
    model = onnx.load(src)
    graph = model.graph
    biggest = max(graph.initializer, key=lambda i: int(np.prod(i.dims)))
    print("embedding:", biggest.name, list(biggest.dims))
    # The matrix can be handed on through Identity nodes before it is used.
    names = {biggest.name}
    changed = True
    while changed:
        changed = False
        for node in graph.node:
            if node.op_type == "Identity" and node.input[0] in names and node.output[0] not in names:
                names.add(node.output[0])
                changed = True
    for name in sorted(names):
        for n in consumers(graph, name):
            print("  ", name, "used by", n.op_type, n.name, list(n.input), "->", list(n.output))

    weights = numpy_helper.to_array(biggest)
    inferred = onnx.shape_inference.infer_shapes(model)
    ranks = {v.name: len(v.type.tensor_type.shape.dim) for v in list(inferred.graph.value_info) + list(inferred.graph.input) if v.type.tensor_type.HasField("shape")}

    # The scores come from MatMul(embedding, hidden^T): the embedding is the
    # left operand, which dynamic quantisation leaves in float. Turn it into
    # (hidden @ embedding^T)^T, so the embedding is the right operand, a
    # weight, in its transposed copy.
    folded = 0
    nodes = list(graph.node)
    rewritten = []
    for node in nodes:
        if node.op_type == "MatMul" and node.input[0] in names:
            right, out = node.input[1], node.output[0]
            rank = ranks.get(right, 3)
            perm = list(range(rank - 2)) + [rank - 1, rank - 2]
            weight = f"{out}_embedding_T"
            graph.initializer.append(numpy_helper.from_array(np.ascontiguousarray(weights.T), name=weight))
            rewritten += [
                onnx.helper.make_node("Transpose", [right], [f"{out}_hidden"], perm=perm, name=f"{out}_hidden_T"),
                onnx.helper.make_node("MatMul", [f"{out}_hidden", weight], [f"{out}_scores"], name=f"{out}_scores_mm"),
                onnx.helper.make_node("Transpose", [f"{out}_scores"], [out], perm=perm, name=f"{out}_scores_T"),
            ]
            folded += 1
        else:
            rewritten.append(node)
    del graph.node[:]
    graph.node.extend(rewritten)
    print("scoring MatMuls rewritten:", folded)

    # The Identity that handed the embedding on is not used any more.
    outputs = {o.name for o in graph.output}
    for _ in range(3):
        used = {i for n in graph.node for i in n.input} | outputs
        keep = [n for n in graph.node if not (n.op_type == "Identity" and n.output[0] not in used)]
        if len(keep) == len(graph.node):
            break
        del graph.node[:]
        graph.node.extend(keep)
    if folded == 0:
        print("no scoring MatMul on the embedding found: the graph is not what was expected", file=sys.stderr)
        return 1
    onnx.save(model, dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
