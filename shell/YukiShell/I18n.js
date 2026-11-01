.pragma library
.import "lang/ru.js" as Ru
.import "lang/zh_CN.js" as ZhCN
.import "lang/zh_TW.js" as ZhTW
.import "lang/ja.js" as Ja
.import "lang/ko.js" as Ko
.import "lang/vi.js" as Vi

var dicts = { ru: Ru.strings, zh_CN: ZhCN.strings, zh_TW: ZhTW.strings, ja: Ja.strings, ko: Ko.strings, vi: Vi.strings };

var languages = [
    { code: "en",    name: "English",    english: "English" },
    { code: "zh_CN", name: "简体中文",    english: "Chinese (Simplified)" },
    { code: "zh_TW", name: "繁體中文",    english: "Chinese (Traditional)" },
    { code: "ja",    name: "日本語",      english: "Japanese" },
    { code: "ko",    name: "한국어",      english: "Korean" },
    { code: "vi",    name: "Tiếng Việt", english: "Vietnamese" },
    { code: "ru",    name: "Русский",    english: "Russian" }
];

function code() {
    var n = String(Qt.uiLanguage !== "" ? Qt.uiLanguage : (Qt.locale().name || "en")).replace("-", "_");
    var lang = n.split("_")[0];
    if (lang === "zh")
        return /Hant|_TW|_HK|_MO/.test(n) ? "zh_TW" : "zh_CN";
    return lang;
}

function tr(text) {
    var d = dicts[code()];
    if (!d || typeof text !== "string")
        return text;
    var t = d[text];
    return t !== undefined ? t : text;
}

function locale() {
    return Qt.uiLanguage !== "" ? Qt.locale(Qt.uiLanguage) : Qt.locale();
}
