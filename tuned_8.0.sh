#!/bin/bash

# Create MongoDB custom tuned profile directory
sudo mkdir -p /etc/tuned/mongodb

# Write tuned.conf with updated THP and sysctl settings
sudo tee /etc/tuned/mongodb/tuned.conf << 'EOF'
#
# tuned configuration
#

[main]
summary=Optimize for MongoDB WiredTiger Performance
include=virtual-guest

[cpu]
force_latency=1
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
# MongoDB 8.0 now recommends enabling THP with defer+madvise
transparent_hugepages=always
khugepaged=always

[disk]
# readahead is expressed in sector. 
# 4 sector equals to 8kb, 8 sectors equals to 16kb
readahead=8

[sysctl]
# Minimal preemption granularity for CPU-bound tasks:
kernel.sched_min_granularity_ns=10000000

# Trigger background writeback at these thresholds
vm.dirty_ratio=10
vm.dirty_background_ratio=3

# Minimize swap usage
vm.swappiness=1

# Scheduler migration tuning
kernel.sched_migration_cost_ns=5000000

# TCP Keepalive
net.ipv4.tcp_keepalive_time=120

# Disable NUMA zone reclaim
vm.zone_reclaim_mode=0

# Kernel PID Max
kernel.pid_max=65536

# Max map count should be 2x Max incoming connections
vm.max_map_count=128000

# Apply missing THP sysfs tuning through external script
[script]
script=/etc/tuned/mongodb/thp-fix.sh
EOF

# Write the THP fix script that tuned will run
sudo tee /etc/tuned/mongodb/thp-fix.sh << 'EOF'
#!/bin/bash

# Apply Transparent Huge Pages recommendations for MongoDB 8.0+

# Set defrag to defer+madvise
if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]]; then
  echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag
fi

# Set khugepaged/max_ptes_none to 0
if [[ -f /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none ]]; then
  echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
fi
EOF

# Make the THP fix script executable
sudo chmod +x /etc/tuned/mongodb/thp-fix.sh

# Apply the MongoDB tuned profile
sudo tuned-adm profile mongodb
