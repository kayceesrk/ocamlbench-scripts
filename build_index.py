#!/usr/bin/python

import subprocess
import os.path
from sets import Set

compilers = Set()
s = subprocess.check_output(["find . -name '*.hash' -printf '%Ts\t%p\n' | sort -nr | cut -f2"], shell=True)
for line in s.split('\n'):
	if (line == ""):
		continue
	compilers.add(os.path.basename(line).replace(".hash",""))

compilers_list = sorted(list(compilers))

print '<table id="example" class="display" style="width:90%"><thead><tr>'
print '  <th>Date</th>'
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

	compiler = os.path.basename(line).replace(".hash","")
	data[compiler] = (line.replace(".hash","").replace("./",""), open(line, "r").read().replace("\n",""))

print '</table>'
