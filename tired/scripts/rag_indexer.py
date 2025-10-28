#!/usr/bin/env python3
"""
RAG Indexer (draft)

Reads text files, chunks to ~800 tokens with 100 overlap, embeds with sentence-transformers
('all-MiniLM-L6-v2' if available), and writes JSONL records for kb_chunks.

Usage:
  python scripts/rag_indexer.py --group-id G123 --source ./docs --version v1 --lang zh

Outputs:
  ./kb_chunks.jsonl (fields: groupId, source, chunk, embedding, version, lang, tags, updatedAt)

Note:
  - This script does not upsert to Firestore. Pipe the JSONL to your ingestion service.
  - If sentence-transformers is not installed, falls back to a fast hashing embedding.
"""
import argparse
import json
import os
import time
from pathlib import Path
from typing import List, Iterable

def read_texts(path: Path) -> Iterable[tuple[str, str]]:
    if path.is_file():
        yield (str(path), path.read_text(encoding='utf-8', errors='ignore'))
        return
    for p in path.rglob("*"):
        if p.suffix.lower() in {".md", ".txt", ".json", ".yaml", ".yml"}:
            try:
                yield (str(p), p.read_text(encoding='utf-8', errors='ignore'))
            except Exception:
                continue

def tokenize(s: str) -> List[str]:
    # naive tokenization by whitespace/punctuation
    import re
    return re.findall(r"\w+|\S", s)

def chunks(tokens: List[str], size: int = 800, overlap: int = 100) -> Iterable[List[str]]:
    if not tokens:
        return
    step = max(1, size - overlap)
    i = 0
    n = len(tokens)
    while i < n:
        yield tokens[i:i+size]
        i += step

def try_load_embedder():
    try:
        from sentence_transformers import SentenceTransformer
        return SentenceTransformer('all-MiniLM-L6-v2')
    except Exception:
        return None

def embed_texts(model, texts: List[str]) -> List[List[float]]:
    if model is None:
        import hashlib
        import math
        def hash_vec(t: str, dim: int = 384) -> List[float]:
            h = hashlib.sha256(t.encode('utf-8')).digest()
            # repeat to fill dim
            vals = list(h) * ((dim // len(h)) + 1)
            vec = [float(v) for v in vals[:dim]]
            # normalize
            norm = math.sqrt(sum(x*x for x in vec)) or 1.0
            return [x / norm for x in vec]
        return [hash_vec(t) for t in texts]
    else:
        return model.encode(texts, normalize_embeddings=True).tolist()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--group-id', required=True)
    ap.add_argument('--source', required=True)
    ap.add_argument('--version', default='v1')
    ap.add_argument('--lang', default='zh')
    ap.add_argument('--tags', nargs='*', default=[])
    ap.add_argument('--out', default='kb_chunks.jsonl')
    args = ap.parse_args()

    src = Path(args.source)
    model = try_load_embedder()
    if model is None:
        print('[warn] sentence-transformers not found; using hashing fallback embeddings')
    now = int(time.time())

    out = Path(args.out)
    count = 0
    with out.open('w', encoding='utf-8') as f:
        for file_path, content in read_texts(src):
            toks = tokenize(content)
            for idx, tok_chunk in enumerate(chunks(toks)):
                text_chunk = ' '.join(tok_chunk)
                emb = embed_texts(model, [text_chunk])[0]
                rec = {
                    'groupId': args.group_id,
                    'source': f"{file_path}#chunk{idx}",
                    'chunk': text_chunk,
                    'embedding': emb,
                    'version': args.version,
                    'lang': args.lang,
                    'tags': args.tags,
                    'updatedAt': now,
                }
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                count += 1
    print(f"wrote {count} chunks to {out}")

if __name__ == '__main__':
    main()

