import {concat, Hex, isHex, keccak256, size} from "viem"

// Implementation forked from Open Zeppelin: https://github.com/OpenZeppelin/merkle-tree/blob/master/src/core.ts

export function makeMerkleTree(leaves: Hex[]): Hex[] {
  leaves.forEach(checkValidMerkleNode);

  if (leaves.length === 0) throwError('Expected non-zero number of leaves');

  const tree = new Array<Hex>(2 * leaves.length - 1);

  for (const [i, leaf] of leaves.entries()) {
    tree[tree.length - 1 - i] = leaf;
  }
  for (let i = tree.length - 1 - leaves.length; i >= 0; i--) {
    tree[i] = commutativeKeccak256(tree[leftChildIndex(i)]!, tree[rightChildIndex(i)]!);
  }

  return tree;
}

export function getRoot(tree: Hex[]): Hex {
  if (tree.length === 0) throwError('Tree has no root');
  return tree[0];
}

export function getProof(tree: Hex[], leaf: Hex): Hex[] {
  let index = tree.indexOf(leaf)
  if (index === -1) throwError("Leaf does not exist in tree")

  checkLeafNode(tree, index);

  const proof: Hex[] = [];
  while (index > 0) {
    proof.push(tree[siblingIndex(index)]!);
    index = parentIndex(index);
  }
  return proof;
}

function commutativeKeccak256(a: Hex, b: Hex): Hex {
  return keccak256(concat([a, b].sort(compare)))
}

function compare(a: Hex, b: Hex): number {
    const diff = BigInt(a) - BigInt(b);
    return diff > 0 ? 1 : diff < 0 ? -1 : 0;
}

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


function throwError(message?: string): never {
  throw new Error(message);
}