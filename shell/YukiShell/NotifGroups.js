.pragma library
// Notification Center groups notifications by app. `model` is the history (a ListModel, newest first, records with nid and app).

// a new notification just went in at the top: bring the older ones of its app right under it, oldest last
function gather(model) {
    var app = model.get(0).app, to = 1;
    for (var i = 1; i < model.count; i++)
        if (model.get(i).app === app) { if (i !== to) model.move(i, to, 1); to++; }
}

// nid -> { head: first of its app's run, n: notifications in the run }
function runs(model) {
    var g = {}, i = 0, n = model.count;
    while (i < n) {
        var a = model.get(i).app, j = i;
        while (j < n && model.get(j).app === a) j++;
        for (var k = i; k < j; k++) g[model.get(k).nid] = { head: k === i, n: j - i };
        i = j;
    }
    return g;
}
