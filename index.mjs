// File: index.mjs  (works with Node 18 default "index.mjs" handler)
// If your handler name is index.handler (CommonJS), change `export` to `exports`.

export const handler = async (event) => {
  // Read attributes from the user pool record
  const attrs = event?.request?.userAttributes ?? {};

  // Support either custom:orgID (what you created) or custom:orgId (if you ever rename in a new pool)
  const orgId  = attrs['custom:orgID'] ?? attrs['custom:orgId'] ?? null;
  const siteKey = attrs['custom:siteKey'] ?? null;

  // Prepare claims override
  event.response = event.response || {};
  event.response.claimsOverrideDetails = event.response.claimsOverrideDetails || {};
  const claims = event.response.claimsOverrideDetails.claimsToAddOrOverride || {};

  if (orgId)  claims['orgId'] = orgId;      // add a simple claim "orgId"
  if (siteKey) claims['siteKey'] = siteKey;  // optional convenience claim

  event.response.claimsOverrideDetails.claimsToAddOrOverride = claims;

  // Note: Cognito already adds "cognito:groups" automatically when users are in groups.
  // We don't need to override groups unless you want custom logic.

  return event;
};
