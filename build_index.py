#!/usr/bin/python

import subprocess
import os.path
from sets import Set

compilers = Set()
s = subprocess.check_output(["find . -name '*time_real.csv' -printf '%Ts\t%p\n' | sort -nr | cut -f2"], shell=True)
for line in s.split('\n'):
	if (line == ""):
		continue
	compilers.add(os.path.basename(line).replace("+bench-time_real.csv",""))

compilers_list = sorted(list(compilers))

print '<table id="example" class="display" style="width:100%"><thead><tr>'
for c in compilers_list:
	print '  <th>' + c + '</th>'
print '</tr></thead><tbody>'

cur_dir = ""
data = {}

for line in s.split('\n'):
	if (line == ""):
		continue
	dir = os.path.dirname(line).replace("./","")

	if (dir != cur_dir):
		cur_dir = dir
		if (len(data) != 0):
			print '  <tr>'
			for c in compilers_list:
				v = data.get(c)
				if (v != None):
					key,text = v
					print '    <td><input type="checkbox" name="benchrun" value="' + key + '">' + text + '</input></td>'
				else:
					print '    <td></td>'
			print '  </tr>'
			data = {}

	compiler = os.path.basename(line).replace("+bench-time_real.csv","")
	hash_file = line.replace("+bench-time_real.csv","") + ".hash"
	data[compiler] = (hash_file.replace(".hash","").replace("./",""), open(hash_file, "r").read().replace("\n",""))

print '</table>'
