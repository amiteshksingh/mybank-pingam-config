/**
 * Name: DspUtils
 * Description: Shared utilities with Caching, Performance, and Logging.
 */

// Define outcomes as a constant to prevent typos
var OUTCOMES = {
    LOCKED: "locked",
    ACTIVE: "active",
    ERROR: "error",
    TRUE: "true",
    FALSE: "false"
};

exports.OUTCOMES = OUTCOMES;

// Timer to get start time and duration
exports.createTimer = function() {
    var start = Date.now();
    return {
        start: start,
        getDuration: () => Date.now() - start
    };
};

/**
 * Formats a timestamp into a readable ISO string (YYYY-MM-DDTHH:mm:ss.sssZ)
 */
exports.formatTimestamp = function(ms) {
    if (!ms) return "N/A";
    return new Date(ms).toISOString();
};

/**
 * Formats duration milliseconds into "00m 00s 000ms"
 */
exports.formatDuration = function(ms) {
    var minutes = Math.floor(ms / 60000);
    var seconds = Math.floor((ms % 60000) / 1000);
    var millis = ms % 1000;
    
    return (minutes > 0 ? minutes + "m " : "") + seconds + "s " + millis + "ms";
};

// Utility to clean attribute value
exports.cleanAttributes = (val) => val.toString().replace(/[\[\]]/g, "");

//Logger implementation to log various type of messages and metrices

function NodeLogger(logger, scriptName, treeName, timer) {
  this.logger = logger;
  this.scriptName = scriptName;
  this.treeName = treeName;
  this.logPrefix = " *** JOURNEY: " + treeName + " SCRIPT: " + scriptName + " ";
  this.logSuffix = " *** ";
  this.timer = timer;
}

NodeLogger.prototype.startLogging = function (message) {
  var startLogMessage = message + " Started at " + exports.formatTimestamp(this.timer.start) + this.logSuffix;
  this.logger.error(this.logPrefix.concat(startLogMessage));
};

NodeLogger.prototype.endLogging = function (message) {
  var endtLogMessage = message + " Completed at " + exports.formatDuration(this.timer.getDuration()) + this.logSuffix;
  this.logger.error(this.logPrefix.concat(endtLogMessage)+this.logSuffix);
};

NodeLogger.prototype.debug = function (message) {
  this.logger.debug(this.logPrefix.concat(message));
};

NodeLogger.prototype.warn = function (message) {
  this.logger.warn(this.logPrefix.concat(message));
};

NodeLogger.prototype.error = function (message) {
  this.logger.error(this.logPrefix.concat(message));
};

NodeLogger.prototype.info = function (message) {
  this.logger.error(this.logPrefix.concat(message));
};

NodeLogger.prototype.logMetrics = function(cn, status, result) {
    this.logger.error(
        "Metrics | User: {} | Status: {} | Result: Locked={} | Latency: {}ms",
        cn, status, result, this.timer.getDuration()
    );
};


module.exports.NodeLogger = NodeLogger;

/**
 * Extracts a specific HTTP header from the request context.
 * @param {object} requestContext - The global request context object passed from the node.
 * @param {string} headerName - The name of the header to retrieve (e.g., "User-Agent").
 * @returns {string|null} The header value, or null if not found.
 */
function getHeaderValue(requestContext, headerName) {
    if (!requestContext) {
        return null;
    }

    var requestHeaders = requestContext.get("headers");
    if (requestHeaders && requestHeaders.containsKey(headerName)) {
        var headerList = requestHeaders.get(headerName);
        if (headerList && !headerList.isEmpty()) {
            return headerList.get(0); // Return the primary header string
        }
    }
    return null;
}

// Export the function so it can be called by other scripts
exports.getHeaderValue = getHeaderValue;
