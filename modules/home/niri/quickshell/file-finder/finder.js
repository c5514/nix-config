.pragma library

// Pure logic for the file finder (no QML types, no I/O): building the `fd`
// invocation, ranking results, and deciding what a file is and what Enter
// should do with it. Kept separate from FileFinder.qml so the widget file
// only deals with UI and process plumbing.

// ── Search ──────────────────────────────────────────────────────────────────

// Hidden paths are already skipped by fd. These are the common cache/build
// directories on top of that. Entries are fd --exclude globs, so a bare name
// matches that directory at any depth.
var EXCLUDES = ["node_modules", "__pycache__", "target", "build", "dist", "_build", "venv", "site-packages", "result", "result-*", "*.egg-info", "go/pkg", "Trash"];

// "ttp" -> "t.*t.*p": every typed character must appear, in order, in the
// file name. Whitespace is dropped (so "my thesis" still finds my_thesis.tex)
// and every character is escaped, so the query can never inject regex syntax.
function fuzzyPattern(query) {
    const chars = Array.from(query.replace(/\s+/g, "")).slice(0, 48);
    return chars.map(c => c.replace(/[\\.+*?()|\[\]{}^$#&\-~]/g, "\\$&")).join(".*");
}

// Full argv for fd (never a shell string). Lists files and directories under
// `home`, ignoring .gitignore (so a repo's ignored PDFs still show up) but
// applying our own excludes. An empty query lists just the top level.
function fdCommand(o) {
    const q = o.query.trim();
    const args = [o.fd, "--type", "f", "--type", "d", "--no-ignore", "--absolute-path", "--color", "never", "--ignore-case", "--max-results", String(o.limit)];
    if (q === "")
        args.push("--max-depth", "1");
    for (const e of o.excludes)
        args.push("--exclude", e);
    // "--" so a query starting with "-" is a pattern, not an option.
    args.push("--", fuzzyPattern(q), o.home);
    return args;
}

// ── Ranking ─────────────────────────────────────────────────────────────────

function isBoundary(s, i) {
    return i === 0 || " _-./".indexOf(s.charAt(i - 1)) >= 0;
}

// Score `q` (lowercase, no spaces) against a lowercase file name.
// Higher is better; -1 means "not a match".
function nameScore(q, n) {
    if (n === q)
        return 1000;
    const stem = n.replace(/\.[^.]*$/, "");
    if (stem === q)
        return 950;
    if (n.startsWith(q))
        return 800 - (n.length - q.length);

    const at = n.indexOf(q);
    if (at >= 0)
        return (isBoundary(n, at) ? 700 : 600) - at - (n.length - q.length) * 0.5;

    // Scattered match: reward runs of consecutive characters and matches at
    // word starts, penalise gaps and long names.
    let score = 100, qi = 0, last = -1, run = 0;
    for (let i = 0; i < n.length && qi < q.length; i++) {
        if (n.charAt(i) !== q.charAt(qi))
            continue;
        if (last >= 0 && i === last + 1) {
            run++;
            score += 12 * run;
        } else {
            run = 0;
            if (last >= 0)
                score -= Math.min(i - last - 1, 10);
        }
        if (isBoundary(n, i))
            score += 15;
        last = i;
        qi++;
    }
    return qi < q.length ? -1 : score - n.length * 0.3;
}

// Path shown under the name: relative to $HOME, directories with a trailing "/".
function displayPath(path, home, isDir) {
    const rel = path.startsWith(home + "/") ? path.slice(home.length + 1) : path;
    return isDir ? rel + "/" : rel;
}

// Turn raw fd output lines into ranked, display-ready items.
// Directories arrive with a trailing "/" (fd >= 8.4) - that is how they are
// told apart from files without a second query.
function rank(lines, query, home, limit) {
    const q = query.replace(/\s+/g, "").toLowerCase();
    const seen = {};
    const items = [];

    for (let i = 0; i < lines.length; i++) {
        const raw = lines[i];
        // Every real result is an absolute path; anything else is the tail of
        // a file name that contained a newline. Skip those, and the head they
        // belong to (it looks like a path but isn't one), rather than show or
        // act on a path that doesn't exist.
        if (raw.charAt(0) !== "/")
            continue;
        if (i + 1 < lines.length && lines[i + 1].charAt(0) !== "/")
            continue;
        const isDir = raw.length > 1 && raw.endsWith("/");
        const path = isDir ? raw.replace(/\/+$/, "") : raw;
        if (path === "" || seen[path])
            continue;
        seen[path] = true;

        const slash = path.lastIndexOf("/");
        const name = path.slice(slash + 1);
        const rel = displayPath(path, home, isDir);

        let score = 0;
        if (q !== "") {
            score = nameScore(q, name.toLowerCase());
            if (score < 0)
                continue;
            // Prefer shallower paths and, slightly, folders.
            score -= (rel.match(/\//g) || []).length * 3;
            if (isDir)
                score += 4;
        }

        items.push(Object.assign({
            path: path,
            name: name,
            parent: slash > 0 ? path.slice(0, slash) : "/",
            rel: rel,
            isDir: isDir,
            score: score
        }, classify(name, isDir)));
    }

    if (q === "")
        items.sort((a, b) => (b.isDir - a.isDir) || a.name.localeCompare(b.name));
    else
        items.sort((a, b) => (b.score - a.score) || a.rel.localeCompare(b.rel));

    return items.slice(0, limit);
}

// ── File types and what Enter does ──────────────────────────────────────────
//
// route:
//   "open"          xdg-open the file
//   "browse-self"   Yazi in the item itself (directories)
//   "browse-parent" Yazi in the item's parent (source/text, and anything that
//                   could be executed: it is shown, never run or opened)
//
// colorKey is mapped to a theme colour by the widget.

var OPEN = "open";
var BROWSE_SELF = "browse-self";
var BROWSE_PARENT = "browse-parent";

// Glyphs are Font Awesome codepoints from the Nerd Font the shell already uses.
var ICON = {
    folder: "\uf07b",
    pdf: "\uf1c1",
    image: "\uf1c5",
    audio: "\uf1c7",
    video: "\uf1c8",
    archive: "\uf1c6",
    word: "\uf1c2",
    sheet: "\uf1c3",
    slides: "\uf1c4",
    book: "\uf02d",
    web: "\uf0ac",
    code: "\uf1c9",
    text: "\uf0f6",
    shell: "\uf120",
    exec: "\uf013",
    file: "\uf016"
};

// ext -> [label, icon, colorKey, route]
var TYPES = {};

function define(exts, label, icon, colorKey, route) {
    for (const e of exts.split(" "))
        TYPES[e] = [label, icon, colorKey, route];
}

// Ordinary files: opened with the default application.
define("pdf", "PDF", "pdf", "pdf", OPEN);
define("png jpg jpeg gif webp bmp tif tiff avif heic ico svg", null, "image", "image", OPEN);
define("mp3 flac ogg opus wav m4a aac wma", null, "audio", "media", OPEN);
define("mp4 mkv webm avi mov wmv flv m4v", null, "video", "media", OPEN);
define("zip tar gz tgz xz bz2 zst 7z rar", null, "archive", "plain", OPEN);
define("doc docx odt rtf", null, "word", "plain", OPEN);
define("xls xlsx ods csv tsv", null, "sheet", "plain", OPEN);
define("ppt pptx odp", null, "slides", "plain", OPEN);
define("epub djvu mobi", null, "book", "plain", OPEN);
define("html htm", "HTML", "web", "code", OPEN);

// Source and text: shown in Yazi (parent directory), never opened or run.
define("tex sty cls", "LATEX", "text", "code", BROWSE_PARENT);
define("bib", "BIBTEX", "text", "code", BROWSE_PARENT);
define("typ", "TYPST", "text", "code", BROWSE_PARENT);
define("md markdown", "MARKDOWN", "text", "code", BROWSE_PARENT);
define("txt", "TEXT", "text", "plain", BROWSE_PARENT);
define("rst org adoc log diff patch", null, "text", "plain", BROWSE_PARENT);
define("sh bash zsh fish", "SHELL", "shell", "code", BROWSE_PARENT);
define("css scss sass less", null, "code", "code", BROWSE_PARENT);
define("lua", "LUA", "code", "code", BROWSE_PARENT);
define("nix", "NIX", "code", "code", BROWSE_PARENT);
define("py", "PYTHON", "code", "code", BROWSE_PARENT);
define("js mjs cjs", "JAVASCRIPT", "code", "code", BROWSE_PARENT);
define("ts tsx jsx", "TYPESCRIPT", "code", "code", BROWSE_PARENT);
define("c h cpp cc hpp rs go java kt rb php pl hs ml el lisp clj jl r sql cs swift zig", null, "code", "code", BROWSE_PARENT);
define("json yaml yml toml ini conf cfg xml kdl lock env mk cmake gradle vim", null, "code", "code", BROWSE_PARENT);

// Things a desktop would run if "opened": show them, never launch them.
define("desktop appimage run bin exe msi bat cmd com jar apk", null, "exec", "plain", BROWSE_PARENT);

function classify(name, isDir) {
    if (isDir)
        return {
            label: "FOLDER",
            icon: ICON.folder,
            colorKey: "folder",
            route: BROWSE_SELF
        };

    const dot = name.lastIndexOf(".");
    const ext = dot > 0 && dot < name.length - 1 ? name.slice(dot + 1).toLowerCase() : "";
    const t = ext !== "" ? TYPES[ext] : undefined;

    if (t)
        return {
            label: t[0] ?? ext.toUpperCase(),
            icon: ICON[t[1]],
            colorKey: t[2],
            route: t[3]
        };

    // Unknown extension: open it. No extension (Makefile, LICENSE, a script
    // with a shebang...): could be anything, so only ever browse to it.
    if (ext === "")
        return {
            label: "FILE",
            icon: ICON.file,
            colorKey: "plain",
            route: BROWSE_PARENT
        };
    return {
        label: ext.toUpperCase(),
        icon: ICON.file,
        colorKey: "plain",
        route: OPEN
    };
}
