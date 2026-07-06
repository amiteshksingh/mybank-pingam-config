/*
  - Data made available by nodes that have already executed are available in the sharedState variable.
  - The script should set outcome to either "true" or "false".
 */


(function () {
    var utils = require('DspUtils');
    var timer = utils.createTimer();
    var NodeLogger = utils.NodeLogger;
    var nodeLog = new NodeLogger(logger, "MyNextGenTestScript", "mobileLogin", timer);
    var userId = nodeState.get("username");
   
    try {
        nodeLog.startLogging("Starting for user: " + userId);
        // 1. Get the identity object first

        var identity = idRepository.getIdentity(userId);
        nodeLog.error("identity : " + identity);
     
        // 2. Fetch the attribute (returns a Set/List)
        var values = identity.getAttributeValues("cn");
      
        // In Next-Gen, this returns a ScriptAttribute or Array
        if (values && values.length > 0) {
            var rawCn = values[0].toString(); 
            nodeLog.error("rawCn : " + rawCn);
        }

        const cleanStatus = utils.cleanAttributes(rawCn);
       

        // 1. Get the outcome from the library
        const result = utils.OUTCOMES.LOCKED;

        // 2. Set shared state for downstream nodes
        nodeState.putShared("Locked", (result === utils.OUTCOMES.LOCKED).toString());

        nodeLog.logMetrics(userId, cleanStatus, result);

        var userAgentValue = utils.getHeaderValue(requestContext, "User-Agent");

    if (userAgent) {
        // 3. Save to sharedState for downstream nodes
        nodeState.putShared("incomingUserAgent", userAgentValue);
    } else {
        sharedState.put("incomingUserAgent", "unknown");

    }
      
        // 3. Drive the Journey Outcome
        // Ensure these outcome names match the "Outcomes" defined in your Node UI
        action.goTo(utils.OUTCOMES.TRUE);
        nodeLog.error("Ending in : " + timer.getDuration());
        nodeLog.endLogging(" for user: " + userId);

    } catch (e) {
        nodeLog.error("Decision failed: " + e.message);
        action.goTo(utils.OUTCOMES.ERROR);
    }
})();
