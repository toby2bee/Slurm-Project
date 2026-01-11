#!/bin/bash
#SBATCH --job-name=ten_min_python
#SBATCH --output=output.txt
#SBATCH --error=error.txt
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=0:15:00

echo "Starting 10-minute inline Python job..."
python3 - << 'EOF'
import time, datetime

start = time.time()
duration = 600  # 10 minutes

print(f"[{datetime.datetime.now()}] Job started. Running for 10 minutes...")

while True:
    elapsed = time.time() - start
    if elapsed >= duration:
        break
    print(f"[{datetime.datetime.now()}] Still running... {int(elapsed)} seconds elapsed.")  
    time.sleep(30)

print(f"[{datetime.datetime.now()}] Job completed after {int(elapsed)} seconds.")
EOF
echo "Job finished."
