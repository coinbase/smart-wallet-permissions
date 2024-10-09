// forked from Open Zeppelin: https://github.com/OpenZeppelin/merkle-tree/blob/master/src/core.ts

import {concat, Hex, isHex, keccak256, size} from "viem"

const leftChildIndex = (i: number) => 2 * i + 1;
const rightChildIndex = (i: number) => 2 * i + 2;
const parentIndex = (i: number) => (i > 0 ? Math.floor((i - 1) / 2) : throwError('Root has no parent'));
const siblingIndex = (i: number) => (i > 0 ? i - (-1) ** (i % 2) : throwError('Root has no siblings'));

const isTreeNode = (tree: unknown[], i: number) => i >= 0 && i < tree.length;
const isInternalNode = (tree: unknown[], i: number) => isTreeNode(tree, leftChildIndex(i));
const isLeafNode = (tree: unknown[], i: number) => isTreeNode(tree, i) && !isInternalNode(tree, i);
const isValidMerkleNode = (node: Hex) => isHex(node) && size(node) === 32;

const checkLeafNode = (tree: unknown[], i: number) => void (isLeafNode(tree, i) || throwError('Index is not a leaf'));
const checkValidMerkleNode = (node: Hex) =>
  void (isValidMerkleNode(node) || throwError('Merkle tree nodes must be Uint8Array of length 32'));

export function makeMerkleTree(leaves: Hex[]): Hex[] {
  leaves.forEach(checkValidMerkleNode);

  validateArgument(leaves.length !== 0, 'Expected non-zero number of leaves');

  const tree = new Array<Hex>(2 * leaves.length - 1);

  for (const [i, leaf] of leaves.entries()) {
    tree[tree.length - 1 - i] = leaf;
  }
  for (let i = tree.length - 1 - leaves.length; i >= 0; i--) {
    tree[i] = commutativeKeccak256(tree[leftChildIndex(i)]!, tree[rightChildIndex(i)]!);
  }

  return tree;
}

export function getProof(tree: Hex[], index: number): Hex[] {
  checkLeafNode(tree, index);

  const proof: Hex[] = [];
  while (index > 0) {
    proof.push(tree[siblingIndex(index)]!);
    index = parentIndex(index);
  }
  return proof;
}

export function processProof(leaf: Hex, proof: Hex[]): Hex {
  checkValidMerkleNode(leaf);
  proof.forEach(checkValidMerkleNode);

  return proof.reduce(commutativeKeccak256, leaf);
}

export function isValidMerkleTree(tree: Hex[]): boolean {
  for (const [i, node] of tree.entries()) {
    if (!isValidMerkleNode(node)) {
      return false;
    }

    const l = leftChildIndex(i);
    const r = rightChildIndex(i);

    if (r >= tree.length) {
      if (l < tree.length) {
        return false;
      }
    } else if (compare(node, commutativeKeccak256(tree[l]!, tree[r]!))) {
      return false;
    }
  }

  return tree.length > 0;
}

// debug tool to visualize tree
export function renderMerkleTree(tree: Hex[]): string {
  validateArgument(tree.length !== 0, 'Expected non-zero number of nodes');

  const stack: [number, number[]][] = [[0, []]];

  const lines: string[] = [];

  while (stack.length > 0) {
    const [i, path] = stack.pop()!;

    lines.push(
      path
        .slice(0, -1)
        .map(p => ['   ', '│  '][p])
        .join('') +
        path
          .slice(-1)
          .map(p => ['└─ ', '├─ '][p])
          .join('') +
        i +
        ') ' +
        tree[i]!,
    );

    if (rightChildIndex(i) < tree.length) {
      stack.push([rightChildIndex(i), path.concat(0)]);
      stack.push([leftChildIndex(i), path.concat(1)]);
    }
  }

  return lines.join('\n');
}
function compare(a: Hex, b: Hex): number {
    const diff = BigInt(a) - BigInt(b);
    return diff > 0 ? 1 : diff < 0 ? -1 : 0;
}

function commutativeKeccak256(a: Hex, b: Hex): Hex {
    return keccak256(concat([a, b].sort(compare)))
}

function throwError(message?: string): never {
    throw new Error(message);
}
  
class InvalidArgumentError extends Error {
    constructor(message?: string) {
      super(message);
      this.name = 'InvalidArgumentError';
    }
}
  
function validateArgument(condition: unknown, message?: string): asserts condition {
    if (!condition) {
      throw new InvalidArgumentError(message);
    }
}