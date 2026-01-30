#!/usr/bin/env python3
"""
Container Apps Job Demo - Data Processor
A simple job that simulates batch processing with visible output.
"""

import os
import time
import random
from datetime import datetime

def main():
    job_name = os.environ.get('JOB_NAME', 'demo-job')
    execution_id = os.environ.get('CONTAINER_APP_JOB_EXECUTION_NAME', 'local')
    replica_index = os.environ.get('CONTAINER_APP_REPLICA_INDEX', '0')
    
    print("=" * 60)
    print(f"🚀 Container Apps Job Started")
    print("=" * 60)
    print(f"  Job Name:      {job_name}")
    print(f"  Execution ID:  {execution_id}")
    print(f"  Replica Index: {replica_index}")
    print(f"  Start Time:    {datetime.now().isoformat()}")
    print("=" * 60)
    
    # Simulate batch processing
    total_items = random.randint(5, 15)
    print(f"\n📦 Processing {total_items} items...\n")
    
    for i in range(1, total_items + 1):
        # Simulate work
        process_time = random.uniform(0.3, 0.8)
        time.sleep(process_time)
        
        status = "✅" if random.random() > 0.1 else "⚠️"
        print(f"  {status} Item {i}/{total_items} processed in {process_time:.2f}s")
    
    # Summary
    print("\n" + "=" * 60)
    print(f"✅ Job Completed Successfully!")
    print(f"  End Time:      {datetime.now().isoformat()}")
    print(f"  Items Processed: {total_items}")
    print("=" * 60)

if __name__ == "__main__":
    main()
