import subprocess
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter, FormatStrFormatter
import numpy as np
from operator import add

matplotlib.rcParams['ps.fonttype'] = 42
matplotlib.rcParams['pdf.fonttype'] = 42

topics = ['immutable_loads', 'pointer_loads', 'float_loads', 'other_prim_loads', 'mutable_stores', 'init_stores']

d_load_immutable_field = {}
d_initialising_store = {}
d_load_mutable_field = {}
d_assignment = {}

for t in topics:
    s = subprocess.check_output(["operf-macro summarize -b csv -t " + t + " --no-normalize -s 4.07.0+trunk+profile-reads-and-writes+bench"], shell=True)
    for line in s.split('\n'):
        fields = line.split(',')
        if fields[0] == t or fields[0] == "":
            continue
        benchmark = fields[0]
        count = fields[1]
        if t == "immutable_loads":
            d_load_immutable_field[benchmark] = float(count)
        elif t == "pointer_loads":
            d_load_mutable_field[benchmark] = float(count)
        elif t == "float_loads":
            d_load_mutable_field[benchmark] += float(count)
        elif t == "other_prim_loads":
            d_load_mutable_field[benchmark] += float(count)
        elif t == "mutable_stores":
            d_assignment[benchmark] = float(count)
        elif t == "init_stores":
            d_initialising_store[benchmark] = float(count)

bench_list = ['almabench', 'numal-rnd_access', 'setrip', 'setrip-smallbuf', 'numal-levinson-durbin', 'cpdf-transform',
     'jsontrip-sample', 'minilight', 'cpdf-squeeze', 'cpdf-reformat', 'cpdf-merge', 'numal-simple_access',
     'numal-lu-decomposition', 'frama-c-idct', 'numal-naive-multilayer', 'lexifi-g2pp', 'numal-qr-decomposition',
     'bdd', 'numal-fft', 'menhir-standard', 'frama-c-deflate', 'menhir-fancy', 'menhir-sql', 'kb', 'kb-no-exc',
     'numal-k-means', 'numal-durand-kerner-aberth', 'sequence', 'sequence-cps']

load_immutable_field = []
load_mutable_field = []
assignment = []
initialising_store = []

for b in bench_list:
    total = d_load_immutable_field[b] + d_initialising_store[b] + d_load_mutable_field[b] + d_assignment[b]
    load_immutable_field.append(d_load_immutable_field[b]/total)
    load_mutable_field.append(d_load_mutable_field[b]/total)
    initialising_store.append(d_initialising_store[b]/total)
    assignment.append(d_assignment[b]/total)

width = 0.35
ind = np.arange(len(bench_list))
matplotlib.rcParams['figure.figsize'] = [16.0, 10.0]

lif_plt = plt.bar(ind, load_immutable_field, width, color='b')

is_plt = plt.bar(ind, initialising_store, width, color='g',
            bottom=load_immutable_field)

l1 = map(add, load_immutable_field, initialising_store)
lmf_plt = plt.bar(ind, load_mutable_field, width, color='y',
            bottom=l1)

ass_plt = plt.bar(ind, assignment, width, color='r',
            bottom=map(add, l1, load_mutable_field))

plt.gcf().subplots_adjust(bottom=0.45)
plt.xlabel("Benchmark Characteristics")
plt.ylabel("Memory Access Distribution (%)")
plt.xticks(ind, bench_list, rotation=90)
plt.legend((lif_plt[0], is_plt[0], lmf_plt[0], ass_plt[0]),
           ('load immutable field', 'initialising store', 'load mutable field', 'assignment'),
           loc='lower center', bbox_to_anchor=(0.5, 1.05), shadow = True, fancybox=True, ncol=4)
print "Writing 'fig_7a.pdf'"
plt.savefig("fig_7a.pdf")
plt.close()
