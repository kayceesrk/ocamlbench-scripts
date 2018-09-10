#!/usr/bin/python

import subprocess
import os.path
from sets import Set

benches = []
compilers_set = Set()
s = subprocess.check_output(["find . -name 'summary.csv' -printf '%Ts\t%p\n' | sort -nr | cut -f2"], shell=True)
for line in s.split('\n'):
    if line == "":
        continue
    with open(line) as f:
        line2 = f.readline()
        for c in line2.split(','):
            if (c == "time_real" or c == "" or c == "\n"):
                continue
            compilers_set.add(c)
            benches.append((os.path.dirname(line).replace("./",""), c))

compilers_list = sorted(list(compilers_set))

print '<table id="example" class="display" style="width:90%"><thead><tr>'
print '  <th>Date</th>'
for c in compilers_list:
    print '  <th>' + c + '</th>'
print '</tr></thead><tbody>'

cur_dir = ""
data = {}

for b in benches:
    dir,compiler = b

    if (dir != cur_dir):
        if (len(data) != 0):
            print '  <tr>'
            print '    <td>' + cur_dir + '</td>'
            for c in compilers_list:
                v = data.get(c)
                if (v != None):
                    key,text = v
                    print '    <td><input type="checkbox" name="benchrun" onclick="plot()" value="' + key + '" hash="' + text +'">' + text + '</input></td>'
                else:
                    print '    <td></td>'
            print '  </tr>'
            data = {}
        cur_dir = dir

    hash_file = "./" + dir + "/" + compiler.replace("+bench","") + ".hash"
    if (os.path.exists(hash_file)):
        data[compiler] = (dir + "/" + compiler, open(hash_file, "r").read().replace("\n",""))

print '</table>'
