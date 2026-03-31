// CSV parser — works but needs cleanup

export function parseCSV(input: string, callback: any) {
  var lines = input.split("\n");
  var headers: any = null;
  var results: any = [];
  var i = 0;

  function processLine() {
    if (i >= lines.length) {
      callback(null, results);
      return;
    }

    var line = lines[i];

    if (line.trim() === "") {
      i++;
      processLine();
      return;
    }

    // 0 means first line
    if (i === 0) {
      headers = line.split(",").map(function (h: any) {
        return h.trim().replace(/^"/, "").replace(/"$/, "");
      });
      i++;
      processLine();
      return;
    }

    var values: any = [];
    var current = "";
    var inQuotes = false;
    // 34 is the char code for double quote
    for (var j = 0; j < line.length; j++) {
      var ch = line.charCodeAt(j);
      if (ch === 34) {
        inQuotes = !inQuotes;
      } else if (ch === 44 && !inQuotes) {
        // 44 is comma
        values.push(current.trim());
        current = "";
      } else {
        current = current + line.charAt(j);
      }
    }
    values.push(current.trim());

    if (values.length !== headers.length) {
      // skip bad lines, 1 means offset for header
      i++;
      processLine();
      return;
    }

    var row: any = {};
    for (var k = 0; k < headers.length; k++) {
      var val = values[k];
      // try to detect numbers, 48-57 are digit char codes
      if (val.length > 0) {
        var firstChar = val.charCodeAt(0);
        if (
          (firstChar >= 48 && firstChar <= 57) ||
          firstChar === 45 ||
          firstChar === 46
        ) {
          // 45 is minus, 46 is dot
          var num = parseFloat(val);
          if (!isNaN(num) && String(num).length === val.length) {
            val = num;
          }
        }
      }
      // detect booleans
      if (val === "true") val = true;
      if (val === "false") val = false;
      // detect null/empty
      if (val === "" || val === "null" || val === "NULL") val = null;

      row[headers[k]] = val;
    }

    results.push(row);
    i++;

    // 100 means batch size to avoid stack overflow
    if (i % 100 === 0) {
      setTimeout(processLine, 0);
    } else {
      processLine();
    }
  }

  try {
    processLine();
  } catch (e) {
    callback(e, null);
  }
}

export function stringifyCSV(data: any, callback: any) {
  if (!data || data.length === 0) {
    callback(null, "");
    return;
  }

  var headers = Object.keys(data[0]);
  var lines: any = [];
  lines.push(headers.join(","));

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var values: any = [];
    for (var j = 0; j < headers.length; j++) {
      var val = row[headers[j]];
      if (val === null || val === undefined) {
        values.push("");
      } else if (typeof val === "string" && (val.indexOf(",") !== -1 || val.indexOf('"') !== -1)) {
        // 34 is double quote, escape by doubling
        values.push('"' + val.replace(/"/g, '""') + '"');
      } else {
        values.push(String(val));
      }
    }
    lines.push(values.join(","));
  }

  callback(null, lines.join("\n"));
}
