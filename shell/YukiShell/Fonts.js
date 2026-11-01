.pragma library
function forWeight(weight, family) {
    return (Number(weight) >= 600 && family === "Open Runde") ? "Open Runde Semibold" : family;
}
