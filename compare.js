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

var table = {};
var compilers = [];

function populateTable (data, compiler) {
  data.forEach (function(row) {
    if (row[0] === "time_real" || row[0] === "") return;
    table[row[0]] = table[row[0]] || {};
    table[row[0]][compiler] = row[1];
  });
}

function normaliseTable () {
  var minTimes = {};
  var benches = Object.keys(table).sort();
  benches.forEach (function (bench) {
    if (table.hasOwnProperty(bench)) {
      var minValue = Number.MAX_VALUE;

      for (var compiler in table[bench]) {
        if (table[bench].hasOwnProperty(compiler)) {
          if (Number(table[bench][compiler]) < minValue) {
            minValue = Number(table[bench][compiler]);
          }
        }
      }

      minTimes[bench] = minValue;

      for (var compiler in table[bench]) {
        if (table[bench].hasOwnProperty(compiler)) {
          table[bench][compiler] = Number(table[bench][compiler]) / minValue;
        }
      }
    }
  });

  return minTimes;
}

function redraw(minTimes) {
  var timings = {};
  compilers.forEach (function(c) {
    timings[c] = [];
  });
  var labels = [];
  var benches = Object.keys(table).sort();
  benches.forEach (function (bench) {
    labels.push(bench + " (" + Math.round(minTimes[bench]/1000000.0) + ")");
    compilers.forEach(function (c) {
      timings[c].push(table[bench][c] || 0.0);
    });
  });

  var datasets = [];
  var colors = window.chartColors.slice(0);
  compilers.forEach(function (c) {
    color = colors.shift();
    colors.push(color);
    datasets.push({
      label: c,
      borderWidth: 1,
      borderColor: color,
      backgroundColor: colorhelper(color).alpha(0.5).rgbString(),
      data: timings[c]}
    );
  });

  window.chart.data.datasets = datasets;
  window.chart.data.labels = labels;
  window.chart.options.scales.xAxes[0].ticks.maxRotation = 90;
  window.chart.update();
}

window.onload = function () {
  var ctx = document.getElementById("chart");
  window.chart = new Chart (ctx, {
    type : 'bar',
    data: {
      labels: [],
      datasets: []
    }
  });
}

function plot() {
  table = {};
  compilers = [];
  var urls = [];
  var fileSuffix = "+bench-time_real.csv";

  var checkedBoxes = document.querySelectorAll('input[name=benchrun]:checked');
  checkedBoxes.forEach(function(checkBox) {
    urls.push(checkBox.value + fileSuffix);
  });

  Promise.all(urls.map(function(url) {
    return fetch(url).then(function(response) {
      return response.ok ? response.text() : Promise.reject(response.status);
    }).then(function(csvtext) {
      return fetch(url.replace(fileSuffix,".hash")).then(function(response) {
        return response.ok ? response.text() : Promise.reject(response.status);
      }).then(function(hash) {
        var data = CSVToArray(csvtext); //drops the first element
        var compiler = url.replace("/", ":").replace(fileSuffix,":") + hash;
        if (!compilers.includes(compiler))
          compilers.push(compiler);
        populateTable (data, compiler);
    })});
  })).then(function(ignored) {
    minTimes = normaliseTable();
    redraw(minTimes);
  });
}
