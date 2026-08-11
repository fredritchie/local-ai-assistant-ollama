# Model lifecycle

## Locking models

An Ollama tag is convenient but can move. The production bootstrap accepts a
model only when the API-reported SHA-256 digest matches the reviewed manifest.

Pull and inspect models on a controlled Ollama host, then generate a lock:

```bash
ollama pull llama3.2:3b
python scripts/lock_model_manifest.py \
  --model llama3.2:3b:2.0:4.0:true \
  > models/model-manifest.json
```

The final four values are estimated disk GiB, estimated VRAM GiB, and whether
to preload. Review and commit the locked manifest. Never deploy the all-zero
digest in `model-manifest.example.json`.

Validate the generated JSON before committing it:

```bash
jq -e 'type == "array" and length > 0 and
  all(.[]; (.name | type == "string") and
             (.digest | test("^sha256:[0-9a-f]{64}$")) and
             (.size_gib > 0) and (.vram_gib > 0))' \
  models/model-manifest.json
```

## Cache strategy

Every GPU instance receives a dedicated encrypted EBS model volume mounted at
`/var/lib/ollama-models`. If `model_snapshot_id` is omitted, bootstrap downloads
and verifies the configured models. For faster replacement:

1. Populate and verify one development GPU volume.
2. Quiesce Ollama and create an encrypted EBS snapshot.
3. Record the snapshot ID with the matching model manifest revision.
4. Set `model_snapshot_id` and ensure `model_volume_size` is not smaller than
   the snapshot source.
5. Deploy and verify both GPU targets before production promotion.

Leave headroom beyond the manifest's total `size_gib` for the Ollama runtime,
temporary downloads, the operating system, and snapshot growth. Likewise, do
not set concurrent preload workloads whose combined `vram_gib` approaches the
GPU's usable VRAM. The manifest estimates are planning inputs, not runtime
capacity guarantees.

EBS snapshots are incremental after the first snapshot. See [how EBS snapshots
work](https://docs.aws.amazon.com/ebs/latest/userguide/how_snapshots_work.html).

## Rollback

Model rollback is independent from application rollback:

1. Restore the prior manifest.
2. Restore its matching EBS snapshot ID.
3. Run Terraform plan.
4. Apply an ASG instance refresh.
5. Wait for both internal targets to become healthy.

Never reuse a cache snapshot with a different manifest without verifying every
digest.

Use the controlled deployment workflow for normal model rollout and rollback:
deploy the reviewed manifest to `dev`, verify GPU target health and bootstrap
logs, then promote the same reviewed change to `prod`. Direct Terraform applies
are an operator recovery path and should use the same committed manifest and
snapshot pair.

To confirm verification on a GPU instance, open the bootstrap log or use
Session Manager and check it directly:

```bash
sudo grep -E 'Digest verification failed|bootstrap-complete' \
  /var/log/local-ai-bootstrap.log
```

Any `Digest verification failed` entry means the GPU target must not be
promoted; correct the manifest or model source and replace the instance.

## GPU capacity

`g4dn.xlarge` provides one NVIDIA T4 GPU with 16 GiB VRAM, 4 vCPUs, and 16 GiB
system memory. Quantized 3B and many 7B models fit, but model size is not the
only constraint. Context length, parallel requests, and multiple loaded models
increase memory consumption.

The bootstrap defaults to one loaded model and one parallel request per GPU.
Load-test before increasing either value. Ollama documents the relationship
between parallelism, context, and memory in its [GPU and concurrency FAQ](https://docs.ollama.com/faq).
