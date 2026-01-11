## Run Your First Job

### Check Cluster Status

```bash
# List cluster information
sacctmgr show/list cluster

# List associations
sacctmgr show association

# View node information
sinfo
scontrol show nodes
```

Expected output:
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      1   idle node1
compute      up 1-00:00:00      1   idle node2
```

### Access the Controller

```bash
# Via Docker
docker exec -it slurm-controller bash

# Via SSH (alternative)
ssh -p2201 wunmi@localhost
```

### Resume Nodes (if needed)

If nodes show as down or drain:

```bash
scontrol update NodeName=node1 State=RESUME
scontrol update NodeName=node2 State=RESUME
```

### Submit and Monitor Jobs

```bash
# Test basic job submission
srun -N1 hostname

# Submit a batch job to debug partition
sbatch /shared/test2.slurm

# Check job queue
squeue

# Submit a batch job to compute partition
sbatch -p compute /shared/test2.slurm

# View updated queue
squeue
```