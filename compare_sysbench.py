import re
import sys

def parse_file(path):
    results = {}
    host_cpu = host_mem = None

    with open(path) as f:
        lines = f.readlines()

    for line in lines:
        if m := re.match(r"\[Host\] CPU events/sec:\s+([\d.]+)", line):
            host_cpu = float(m.group(1))
        elif m := re.match(r"\[Host\] MEM MiB/sec:\s+([\d.]+)", line):
            host_mem = float(m.group(1))
        elif m := re.match(r"(\S+)\s+([\d.]+) / [\d.]+,\s+[\d.]+%\s+([\d.]+) / [\d.]+,\s+[\d.]+%", line):
            disk, cpu_raw, mem_raw = m.groups()
            results[disk] = (float(cpu_raw), float(mem_raw))

    return host_cpu, host_mem, results

def compare(host_a, host_b, machine_a, machine_b):
    print("=== Host Comparison ===")
    cpu_ratio = host_a / host_b if host_b else float('inf')
    mem_ratio = host_a / host_b if host_b else float('inf')
    print(f"{'':<20} {'Host A':>10} {'Host B':>10} {'A/B Ratio':>10}")
    print(f"{'CPU events/sec':<20} {host_a:10.2f} {host_b:10.2f} {cpu_ratio:10.2f}")
    print(f"{'MEM MiB/sec':<20} {host_mem_a:10.2f} {host_mem_b:10.2f} {mem_ratio:10.2f}")
    print()

    print("=== VM Disk Comparison ===")
    keys = sorted(set(machine_a) | set(machine_b))
    print(f"{'VM Disk':<40} {'CPU A':>10} {'CPU B':>10} {'CPU A/B':>10}   {'MEM A':>10} {'MEM B':>10} {'MEM A/B':>10}")
    print("=" * 100)
    for key in keys:
        a_cpu, a_mem = machine_a.get(key, (0.0, 0.0))
        b_cpu, b_mem = machine_b.get(key, (0.0, 0.0))
        cpu_ratio = a_cpu / b_cpu if b_cpu else float('inf')
        mem_ratio = a_mem / b_mem if b_mem else float('inf')
        print(f"{key:<40} {a_cpu:10.2f} {b_cpu:10.2f} {cpu_ratio:10.2f}   {a_mem:10.2f} {b_mem:10.2f} {mem_ratio:10.2f}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python compare_sysbench.py machineA.txt machineB.txt")
        sys.exit(1)

    file_a = sys.argv[1]
    file_b = sys.argv[2]

    host_cpu_a, host_mem_a, machine_a = parse_file(file_a)
    host_cpu_b, host_mem_b, machine_b = parse_file(file_b)

    compare(host_cpu_a, host_cpu_b, machine_a, machine_b)
