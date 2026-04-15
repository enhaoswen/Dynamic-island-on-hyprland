import QtCore
import QtQuick
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string sourcePath: ""
    property int targetWidth: 960
    property int targetHeight: 540
    property int quality: 86
    property int refreshDebounceInterval: 140

    readonly property string normalizedSourcePath: localPath(sourcePath)
    readonly property string imageMagickExecutable: {
        const magick = executablePath("magick");
        return magick !== "" ? magick : executablePath("convert");
    }
    readonly property string cacheDir: localPath(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation))
        + "/quickshell/dynamic_island/workspace-overview"
    readonly property string cacheFileName: "wallpaper-"
        + hashString(normalizedSourcePath + "|" + targetWidth + "x" + targetHeight)
        + ".jpg"
    readonly property string cacheRelativePath: "quickshell/dynamic_island/workspace-overview/" + cacheFileName
    readonly property string cachePath: cacheDir + "/" + cacheFileName
    readonly property string effectiveSource: cacheAvailable
        ? (toFileUrl(cachePath) + "?v=" + cacheRevision)
        : toFileUrl(normalizedSourcePath)

    property bool cacheAvailable: false
    property int cacheRevision: 0
    property bool refreshPending: false
    property string inFlightCachePath: ""
    property string inFlightSourcePath: ""
    readonly property bool busy: refreshPending || refreshDebounceTimer.running || thumbnailProcess.running

    function localPath(value) {
        if (value === undefined || value === null)
            return "";
        if (value.toLocalFile)
            return value.toLocalFile();

        const text = String(value);
        return text.startsWith("file://") ? text.substring(7) : text;
    }

    function toFileUrl(localFile) {
        return localFile === "" ? "" : ("file://" + encodeURI(localFile));
    }

    function executablePath(executableName) {
        return localPath(StandardPaths.findExecutable(executableName));
    }

    function hashString(value) {
        let hash = 2166136261;
        const text = String(value || "");

        for (let index = 0; index < text.length; index++) {
            hash ^= text.charCodeAt(index);
            hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
        }

        return (hash >>> 0).toString(16);
    }

    function hasCacheOnDisk() {
        return localPath(StandardPaths.locate(StandardPaths.GenericCacheLocation, cacheRelativePath)) !== "";
    }

    function scheduleRefresh() {
        refreshPending = true;
        refreshDebounceTimer.restart();
    }

    function refreshNow() {
        refreshPending = true;
        refreshDebounceTimer.stop();
        refreshCache();
    }

    function refreshCache() {
        if (!refreshPending || thumbnailProcess.running)
            return;

        refreshPending = false;

        if (normalizedSourcePath === "" || imageMagickExecutable === "")
            return;

        inFlightCachePath = cachePath;
        inFlightSourcePath = normalizedSourcePath;
        thumbnailProcess.exec([
            "sh",
            "-lc",
            [
                "src=$1",
                "dest=$2",
                "dir=$3",
                "width=$4",
                "height=$5",
                "quality=$7",
                "mkdir -p \"$dir\" || exit 2",
                "[ -f \"$src\" ] || exit 3",
                "if [ -f \"$dest\" ] && [ \"$dest\" -nt \"$src\" ]; then exit 0; fi",
                "tmp=$(mktemp \"$dir/.wallpaper-cache.XXXXXX.jpg\") || exit 4",
                "trap 'rm -f \"$tmp\"' EXIT",
                "\"$6\" \"$src\" -auto-orient -strip -filter Lanczos -thumbnail \"${width}x${height}^\" "
                    + "-gravity center -extent \"${width}x${height}\" "
                    + "-sampling-factor 4:2:0 -interlace Plane -quality \"$quality\" \"$tmp\" || exit 5",
                "mv -f \"$tmp\" \"$dest\""
            ].join("; "),
            "sh",
            normalizedSourcePath,
            cachePath,
            cacheDir,
            String(targetWidth),
            String(targetHeight),
            imageMagickExecutable,
            String(quality)
        ]);
    }

    onCachePathChanged: {
        cacheAvailable = hasCacheOnDisk();
        scheduleRefresh();
    }

    Component.onCompleted: {
        cacheAvailable = hasCacheOnDisk();
        scheduleRefresh();
    }

    Timer {
        id: refreshDebounceTimer

        interval: root.refreshDebounceInterval
        repeat: false

        onTriggered: root.refreshCache()
    }

    FileView {
        id: sourceWatcher

        path: root.normalizedSourcePath
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            root.cacheAvailable = root.hasCacheOnDisk();
            root.scheduleRefresh();
        }
    }

    Process {
        id: thumbnailProcess

        onExited: function(exitCode, exitStatus) {
            const targetStillCurrent = root.inFlightCachePath === root.cachePath
                && root.inFlightSourcePath === root.normalizedSourcePath;

            if (targetStillCurrent) {
                root.cacheAvailable = root.hasCacheOnDisk();
                if (exitCode === 0 && root.cacheAvailable)
                    root.cacheRevision += 1;
            }

            if (root.refreshPending || !targetStillCurrent)
                refreshDebounceTimer.restart();
        }
    }
}
