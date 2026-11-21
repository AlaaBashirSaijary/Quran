"""Makes the decoder's output layer a weight of its own, so it can be quantised.

Whisper uses the word embedding both to look words up and, transposed, to
score them. The exported graph transposes it at run time, so the 51865 x 512
float matrix stays (106 MB) and the scoring MatMul is not quantised. Here
the transpose is done once, into a second weight, and the Transpose node is
dropped.

    python tools/speech/slim_decoder.py IN.onnx OUT.onnx
"""
import sys

import numpy as np
import onnx
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
    folded = 0
    for node in list(graph.node):
        if node.op_type == "Transpose" and node.input[0] in names:
            perm = [list(a.ints) for a in node.attribute if a.name == "perm"]
            transposed = np.ascontiguousarray(weights.transpose(perm[0] if perm else None))
            graph.initializer.append(numpy_helper.from_array(transposed, name=node.output[0]))
            graph.node.remove(node)
            folded += 1
    print("transposes folded into a weight:", folded)
    if folded == 0:
        print("no Transpose of the embedding found: the graph is not what was expected", file=sys.stderr)
        return 1
    onnx.save(model, dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
