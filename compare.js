window.chartColors = [
  'rgb(255, 99, 132)', //red:
  'rgb(54, 162, 235)',//blue:
  'rgb(255, 205, 86)',//yellow:
  'rgb(75, 192, 192)',//green:
  'rgb(255, 159, 64)', //orange:
  'rgb(153, 102, 255)',//purple:
  'rgb(201, 203, 207)'//grey:
];

colorhelper = Chart.helpers.color;

//copypasta: https://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data
function CSVToArray( strData, strDelimiter ){
  strDelimiter = (strDelimiter || ",");
  var objPattern = new RegExp(
    (
      // Delimiters.
      "(\\" + strDelimiter + "|\\r?\\n|\\r|^)" +
      // Quoted fields.
      "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
      // Standard fields.
      "([^\"\\" + strDelimiter + "\\r\\n]*))"
    ), "gi");
  var arrData = [[]];
  var arrMatches = null;
  while (arrMatches = objPattern.exec( strData )){
    var strMatchedDelimiter = arrMatches[ 1 ];
    if (
        strMatchedDelimiter.length &&
        strMatchedDelimiter !== strDelimiter
    ){
      arrData.push( [] );
    }
    var strMatchedValue;
    if (arrMatches[ 2 ]){
      strMatchedValue = arrMatches[ 2 ].replace(
        new RegExp( "\"\"", "g" ), "\"");
    } else {
      strMatchedValue = arrMatches[ 3 ];
    }
    arrData[ arrData.length - 1 ].push( strMatchedValue );
  }
  return( arrData );
}

//table -> directory -> topic -> compiler -> bench -> value
var table = {};
var hashes = {};

window.onload = function () {
  topics = ["time_real", "size", "code_size", "data_size", "minor_words",
            "major_words", "promoted_words", "top_heap_words", "minor_collections",
            "major_collections", "heap_words", "mean_space_overhead"];
  var select = document.getElementById("topic");
  topics.forEach (function(topic) {
    var el = document.createElement("option");
    el.textContent = topic;
    el.value = topic;
    select.appendChild(el);
  });

  var ctx = document.getElementById("chart");
  window.chart = new Chart (ctx, {
    type : 'bar',
    data: {
      labels: [],
      datasets: []
    }
  });
}

function populateTable (directory, compiler, data) {
  topic = "";
  compilers = [];
  table[directory] = {};
  data.forEach (function(a) {
    if (a.length == 1) {
      topic = "";
      return;
    }
    if (topic === "") {
      topic = a[0];
      table[directory][topic] = {};
      compilers = [];
      for (i = 1; i < a.length; i++) {
        if (i % 2 == 1) {
          compiler = a[i].replace("+bench","");
          compilers.push(compiler);
          table[directory][topic][compiler] = {};
        }
      }
    } else {
      bench = a[0];
      for (i = 1; i < a.length; i++) {
        if (i % 2 == 1) {
          table[directory][topic][compilers[(i-1)/2]][bench] = a[i];
        }
      }
    }
  });
}

function gatherData (configs) {
  let normalise = document.getElementById("normalize").checked;
  let t = document.getElementById("topic");
  let topic = t.options[t.selectedIndex].value;

  let benches_set = new Set();
  configs.forEach(function(c) {
    Object.keys(table[c.directory][topic][c.compiler]).forEach(function(b) {
        benches_set.add(b);
    });
  });
  let benches = Array.from(benches_set).sort();

  let data = [];
  let mins = [];
  benches.forEach (function (bench) {
    let r = {};
    let minValue = Number.MAX_VALUE;
    configs.forEach(function(c) {
      let bo = table[c.directory][topic][c.compiler];
      let compiler = c.directory + ":" + c.compiler + ":" + c.hash;
      if (bo.hasOwnProperty(bench)) {
        r[compiler] = Number(bo[bench]);
        if (normalise && r[compiler] < minValue && r[compiler] != 0.0) {
          minValue = r[compiler];
        }
      } else {
        r[compiler] = 0.0;
      }
    });
    if (normalise) {
      for (let compiler in r) {
        if (r.hasOwnProperty(compiler)) {
          r[compiler] = r[compiler] / minValue;
        }
      }
    }
    data.push(r);
    mins.push(minValue);
  });

  let plotData = {};
  configs.forEach (function(c) {
    let compiler = c.directory + ":" + c.compiler + ":" + c.hash;
    let values = [];
    data.forEach(function(d) {
      values.push(d[compiler]);
    });
    plotData[compiler] = values;
  });

  return {benches: benches, data: plotData, mins: mins, topic: topic, normalise: normalise};
}

function redraw(data) {
  let labels=[];
  let divisor = 1.0;
  if (data.normalise) {
    let min = Math.min(...data.mins);
    while (min / divisor > 10.0) {
      divisor = divisor * 10.0;
    }
    divisor = divisor / 10.0;
    for (let i=0; i < data.benches.length; i++) {
      let annot = 0.0;
      if (data.mins[i] != Number.MAX_VALUE) {
        annot = Math.round(data.mins[i]/divisor);
      }
      labels.push (data.benches[i] + " (" + annot + ")");
    }
  } else {
    labels = data.benches;
  }

  var datasets = [];
  var colors = window.chartColors.slice(0);
  for (var compiler in data.data) {
    if (data.data.hasOwnProperty(compiler)) {
      color = colors.shift();
      colors.push(color);
      datasets.push({
        label: compiler,
        borderWidth: 1,
        borderColor: color,
        backgroundColor: colorhelper(color).alpha(0.5).rgbString(),
        data: data.data[compiler]
      });
    }
  }

  let title = "";
  if (data.normalise) {
    title = data.topic + " (min x " + divisor + ")";
  } else {
    title = data.topic;
  }

  window.chart.data.datasets = datasets;
  window.chart.data.labels = labels;
  window.chart.options.scales.xAxes[0].ticks.maxRotation = 90;
  window.chart.options.title.text = title;
  window.chart.options.title.display = true;
  window.chart.update();
}

function plot() {
  var checkedboxes = document.querySelectorAll('input[name=benchrun]:checked');
  var configs = []
  checkedboxes.forEach(function(cb) {
    var a = cb.value.split(":");
    configs.push({directory: a[0], compiler: a[1], hash: a[2], download: !table.hasOwnProperty(a[0])});
  });

  Promise.all(configs.map(function(c) {
    if (c.download) {
      console.log ("Downloading " + c.directory);
      return fetch(c.directory + "/summary.csv").then(function(response) {
        return response.ok ? response.text() : Promise.reject(response.status);
      }).then(function(csvtext) {
        var data = CSVToArray(csvtext);
        populateTable(c.directory, c.compiler, data);
      });
    }})).then(function(ignored) {
      d = gatherData(configs);
      redraw(d);
    });
}
