/* Pre-bound API variables available natively:
   logger, environment, advice, responseAttributes, authorized 
*/

// 1. Extract context attributes passed in by the PEP payload
var contextMap = environment.get("attributes"); 
var txAmount = contextMap ? contextMap.get("transactionAmount") : 0;

logger.info("Evaluating dynamic transaction policy for amount: " + txAmount);

// 2. Set conditional boundaries to fork decisions dynamically
if (txAmount > 5000) {
    // Fail authorization and pass custom Advice back to PEP
    authorized = false;
    advice.put("RequiredAuthMethod", ["Passkey-Preferred"]);
} else {
    // Pass transaction immediately
    authorized = true; 
}
