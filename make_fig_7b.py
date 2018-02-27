import subprocess
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter, FormatStrFormatter

matplotlib.rcParams['ps.fonttype'] = 42
matplotlib.rcParams['pdf.fonttype'] = 42

s = subprocess.check_output(["operf-macro summarize -b csv -t time_real --no-normalize -s 4.07.0+trunk+bench,4.07.0+trunk+branch-after-load-aarch64+bench,4.07.0+trunk+dmb-before-store-aarch64+bench,4.07.0+trunk+sra-aarch64+bench"], shell="True")
data = {}

for line in s.split('\n'):
    fields = line.split(',')
    print fields
    benchmark = fields[0]
    if benchmark=="time_real":
        continue
    baseline = float(fields[1])
    bal = float(fields[3])/baseline
    fbs = float(fields[5])/baseline
    sra = float(fields[7])/baseline
    data[benchmark] = (bal,fbs,sra)

print data
