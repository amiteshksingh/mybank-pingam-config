var userId = nodeState.get("username");
var userIdentity = idRepository.getIdentity(userId);

if (userIdentity) {
    var emailValues = userIdentity.getAttributeValues("mail");
    var email = (emailValues && emailValues.length > 0) ? emailValues[0] : "not-found";
    var firstname = userIdentity.getAttributeValues("givenname");
    
    logger.error("User email found: " + email);
    logger.error("User firstname found: " + firstname);

    // Simply assign to the variable (do not use withAuditEntryDetail)
    auditEntryDetail = {
        "eventNameNormalized": "LOGIN_SUCCESS",
  "successFlag": true,
  "outcomeStatus": "SUCCESS",
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
  "timeToLoginMs": 8000

    };
}

// ALWAYS define an outcome in Next-Gen scripts
outcome = "true";
