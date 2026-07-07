var userId = nodeState.get("username");
var userIdentity = idRepository.getIdentity(userId);
var userAgent = requestHeaders.get("User-Agent");
//var requestHeaders = requestContext.get("headers");
logger.error("AuditLoggingFailure.js - userId found: " + userId);
logger.error("AuditLoggingFailure.js - User-Agent found: " + userAgent);

var isIdentityValid = false;

if (userIdentity) {
    try {
        // This triggers the internal null pointer check safely
        userIdentity.getAttributes(); 
        isIdentityValid = true;
    } catch (e) {
        // Catches the Java NullPointerException if the identity wrapper is dead
        isIdentityValid = false;
    }
}

if (isIdentityValid){
    var emailValues = userIdentity.getAttributeValues("mail");
    var email = (emailValues && emailValues.length > 0) ? emailValues[0] : "not-found";
    var status = userIdentity.getAttributeValues("inetUserStatus");
    
    logger.error("User email found: " + email);
  logger.error("User status found: " + status);
}

    // Simply assign to the variable (do not use withAuditEntryDetail)
    auditEntryDetail = {
        "eventNameNormalized": "LOGIN_FAILURE",
  "successFlag": true,
  "outcomeStatus": "FAILURE",
  "authMethod": "SMS_OTP",
  "browserTrustStatus": "TRUSTED",
  "customerRef": "12345",
  "serviceId": "RETAIL_BANKING",
  "segmentCode": "PREM",
  "segmentName": "PREMIUM",
  "nationalityCode": "SA",
  "nationalityName": "Saudi",
  "idType": "NATIONAL_ID",
  "idTypeDesc": "National ID",
  "journeyStage": "FINAL_AUTH",
  "loginStartTsUtc": "2026-06-03T09:12:00Z",
  "loginSuccessTsUtc": "2026-06-03T09:12:08Z",
  "timeToLoginMs": 8000,
      "userStatus": status,
      "userAgent": userAgent

    };

// ALWAYS define an outcome in Next-Gen scripts
outcome = "true";
