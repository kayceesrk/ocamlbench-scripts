import subprocess
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter, FormatStrFormatter
import numpy as np

matplotlib.rcParams['ps.fonttype'] = 42
matplotlib.rcParams['pdf.fonttype'] = 42

s = subprocess.check_output(["operf-macro summarize -b csv -t time_real --no-normalize -s 4.07.0+trunk+bench,4.07.0+trunk+branch-after-load-aarch64+bench,4.07.0+trunk+dmb-before-store-aarch64+bench,4.07.0+trunk+sra-aarch64+bench"], shell="True")
data = {}

for line in s.split('\n'):
    fields = line.split(',')
    benchmark = fields[0]
    if benchmark=="time_real" or benchmark=="":
        continue
    baseline = float(fields[1])
    bal = float(fields[3])/baseline
    fbs = float(fields[5])/baseline
    sra = float(fields[7])/baseline
    data[benchmark] = (bal,fbs,sra)

bench_list = ['almabench', 'numal-rnd_access', 'setrip', 'setrip-smallbuf', 'numal-levinson-durbin', 'cpdf-transform',
     'jsontrip-sample', 'minilight', 'cpdf-squeeze', 'cpdf-reformat', 'cpdf-merge', 'numal-simple_access',
     'numal-lu-decomposition', 'frama-c-idct', 'numal-naive-multilayer', 'lexifi-g2pp', 'numal-qr-decomposition',
     'bdd', 'numal-fft', 'menhir-standard', 'frama-c-deflate', 'menhir-fancy', 'menhir-sql', 'kb', 'kb-no-exc',
     'numal-k-means', 'numal-durand-kerner-aberth', 'sequence', 'sequence-cps']

width=0.25
ind = np.arange(len(bench_list))
matplotlib.rcParams['figure.figsize'] = [16.0, 10.0]


bal_list = []
fbs_list = []
sra_list = []

for i in bench_list:
    (bal,fbs,sra) = data[i]
    bal_list.append(bal)
    fbs_list.append(fbs)
    sra_list.append(sra)

bal_plt = plt.bar(ind, bal_list, width, color='g')
fbs_plt = plt.bar(ind+width, fbs_list, width, color='y')
sra_plt = plt.bar(ind+2*width, sra_list, width, color='r')

plt.gcf().subplots_adjust(bottom=0.45)
plt.xlabel("Performance of AArch64")
plt.ylabel("Normalized Time")
plt.xticks(ind+2*width, bench_list, rotation=90)
plt.legend((bal_plt[0], fbs_plt[0], sra_plt[0]),
           ('branch after load', 'fence before store', 'strong release-acquire'))
print "Writing 'fig_7b.pdf'"
plt.savefig("fig_7b.pdf")
plt.close()
