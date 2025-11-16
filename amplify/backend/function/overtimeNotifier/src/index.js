/* Amplify Params - DO NOT EDIT
    API_SHIFTLINKMAIN_GRAPHQLAPIENDPOINTOUTPUT
    API_SHIFTLINKMAIN_GRAPHQLAPIIDOUTPUT
    ENV
    REGION
    SNS_PLATFORM_APPLICATION_ARN_ANDROID
    SNS_PLATFORM_APPLICATION_ARN_IOS
Amplify Params - DO NOT EDIT */

const aws4 = require('aws4');
const https = require('https');
const querystring = require('querystring');

const GRAPHQL_ENDPOINT = process.env.API_SHIFTLINKMAIN_GRAPHQLAPIENDPOINTOUTPUT;
const REGION = process.env.REGION;
const PLATFORM_ARN_IOS = process.env.SNS_PLATFORM_APPLICATION_ARN_IOS || '';
const PLATFORM_ARN_ANDROID = process.env.SNS_PLATFORM_APPLICATION_ARN_ANDROID || '';

const ENDPOINTS_BY_USER = /* GraphQL */ `
  query NotificationEndpointsByUser($userId: String!, $limit: Int) {
    notificationEndpointsByUser(userId: $userId, limit: $limit, sortDirection: DESC) {
      items {
        id
        orgId
        deviceToken
        platform
        enabled
        platformEndpointArn
      }
      nextToken
    }
  }
`;

const ENDPOINTS_BY_ORG = /* GraphQL */ `
  query NotificationEndpointsByOrg($orgId: String!, $limit: Int, $nextToken: String) {
    notificationEndpointsByOrg(orgId: $orgId, limit: $limit, nextToken: $nextToken, sortDirection: DESC) {
      items {
        id
        orgId
        userId
        deviceToken
        platform
        enabled
        platformEndpointArn
      }
      nextToken
    }
  }
`;

const UPDATE_ENDPOINT_MUTATION = /* GraphQL */ `
  mutation UpdateNotificationEndpoint($input: UpdateNotificationEndpointInput!) {
    updateNotificationEndpoint(input: $input) {
      id
      platformEndpointArn
    }
  }
`;

exports.handler = async (event) => {
  console.log('[overtimeNotifier] event', JSON.stringify(event));
  const input = event?.arguments?.input;
  if (!input) {
    return result(false, 0, 0, 'Missing input payload');
  }

  const recipients = Array.isArray(input.recipients)
    ? [...new Set(input.recipients.filter((id) => typeof id === 'string' && id.trim().length))]
    : [];

  if (!recipients.length) {
    return result(false, 0, 0, 'No recipients provided');
  }
  if (!GRAPHQL_ENDPOINT) {
    return result(false, 0, recipients.length, 'GraphQL endpoint missing');
  }
  if (!input.title || !input.body) {
    return result(false, 0, recipients.length, 'Notification title/body missing');
  }

  const metadata = parseMetadata(input.metadata);
  const endpoints = await fetchEndpoints({ recipients, orgId: input.orgId });
  const activeTargets = endpoints.filter((endpoint) => endpoint.enabled !== false);

  if (!activeTargets.length) {
    console.log('[overtimeNotifier] No active endpoints for recipients');
    return result(true, 0, recipients.length, 'No active endpoints');
  }

  let delivered = 0;
  for (const endpoint of activeTargets) {
    try {
      const endpointArn = await ensureEndpointArn(endpoint);
      if (!endpointArn) {
        continue;
      }
      await publishMessage({
        endpointArn,
        title: input.title,
        body: input.body,
        category: input.category,
        postingId: input.postingId,
        metadata
      });
      delivered += 1;
    } catch (error) {
      console.error('[overtimeNotifier] publish failed', error);
    }
  }

  return result(true, delivered, recipients.length);
};

function result(success, delivered, recipientCount, message) {
  return {
    success,
    delivered,
    recipientCount,
    message: message || null
  };
}

async function fetchEndpoints({ recipients, orgId }) {
  const normalizedRecipients = new Set(recipients);
  const includeAll = normalizedRecipients.delete('*');
  const lookups = [];

  if (includeAll) {
    if (!orgId) {
      console.warn('[overtimeNotifier] Broadcast requested but orgId missing');
    } else {
      lookups.push(fetchEndpointsByOrg(orgId));
    }
  }

  for (const userId of normalizedRecipients) {
    lookups.push(
      callGraphQL(ENDPOINTS_BY_USER, { userId, limit: 25 })
        .then((response) => response?.data?.notificationEndpointsByUser?.items || [])
        .catch((error) => {
          console.error('[overtimeNotifier] endpoint fetch failed', error);
          return [];
        })
    );
  }

  if (!lookups.length) {
    return [];
  }

  const segments = await Promise.all(lookups);
  const deduped = new Map();
  segments
    .flat()
    .filter(Boolean)
    .forEach((endpoint) => {
      if (endpoint?.id && !deduped.has(endpoint.id)) {
        deduped.set(endpoint.id, endpoint);
      }
    });
  return Array.from(deduped.values());
}

async function fetchEndpointsByOrg(orgId) {
  let nextToken = null;
  const collected = [];

  do {
    const variables = { orgId, limit: 100 };
    if (nextToken) {
      variables.nextToken = nextToken;
    }
    try {
      const response = await callGraphQL(ENDPOINTS_BY_ORG, variables);
      const connection = response?.data?.notificationEndpointsByOrg;
      const items = connection?.items || [];
      collected.push(...items.filter(Boolean));
      nextToken = connection?.nextToken || null;
    } catch (error) {
      console.error('[overtimeNotifier] org endpoint fetch failed', error);
      break;
    }
  } while (nextToken && collected.length < 1000);

  return collected;
}

async function ensureEndpointArn(endpoint) {
  if (endpoint.platformEndpointArn) {
    return endpoint.platformEndpointArn;
  }
  const platform = (endpoint.platform || 'IOS').toUpperCase();
  const applicationArn = platform === 'ANDROID' ? PLATFORM_ARN_ANDROID : PLATFORM_ARN_IOS;
  if (!applicationArn) {
    console.warn('[overtimeNotifier] Missing platform application ARN for', platform);
    return null;
  }
  try {
    const responseXml = await snsRequest('CreatePlatformEndpoint', {
      PlatformApplicationArn: applicationArn,
      Token: endpoint.deviceToken
    });
    const match = responseXml.match(/<EndpointArn>([^<]+)<\/EndpointArn>/);
    if (!match) {
      console.error('[overtimeNotifier] Unable to parse endpoint ARN from SNS response');
      return null;
    }
    const endpointArn = match[1];
    await callGraphQL(UPDATE_ENDPOINT_MUTATION, {
      input: { id: endpoint.id, platformEndpointArn: endpointArn }
    });
    return endpointArn;
  } catch (error) {
    console.error('[overtimeNotifier] ensureEndpointArn failed', error);
    return null;
  }
}

async function publishMessage({ endpointArn, title, body, category, postingId, metadata }) {
  const dataPayload = {};
  if (category) dataPayload.category = category;
  if (postingId) dataPayload.postingId = postingId;
  if (metadata && Object.keys(metadata).length > 0) {
    dataPayload.metadata = metadata;
  }

  const apnsPayload = {
    aps: {
      alert: {
        title,
        body
      },
      sound: 'default'
    }
  };

  const gcmPayload = {
    notification: {
      title,
      body
    }
  };

  Object.entries(dataPayload).forEach(([key, value]) => {
    apnsPayload[key] = value;
  });

  const androidData = {};
  Object.entries(dataPayload).forEach(([key, value]) => {
    if (value === undefined || value === null) {
      return;
    }
    if (typeof value === 'object') {
      androidData[key] = JSON.stringify(value);
    } else {
      androidData[key] = String(value);
    }
  });
  if (Object.keys(androidData).length > 0) {
    gcmPayload.data = androidData;
  }

  const message = {
    default: body,
    APNS: JSON.stringify(apnsPayload),
    APNS_SANDBOX: JSON.stringify(apnsPayload),
    GCM: JSON.stringify(gcmPayload)
  };

  await snsRequest('Publish', {
    TargetArn: endpointArn,
    MessageStructure: 'json',
    Message: JSON.stringify(message)
  });
}

function parseMetadata(raw) {
  if (!raw) return null;
  if (typeof raw === 'object') {
    return raw;
  }
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (error) {
      console.warn('[overtimeNotifier] Unable to parse metadata payload', error);
      return null;
    }
  }
  return null;
}

async function snsRequest(action, params) {
  const body = querystring.stringify({
    Action: action,
    Version: '2010-03-31',
    ...params
  });

  const requestOptions = {
    host: `sns.${REGION}.amazonaws.com`,
    path: '/',
    method: 'POST',
    service: 'sns',
    region: REGION,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body)
    },
    body
  };

  aws4.sign(requestOptions);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        host: requestOptions.host,
        path: requestOptions.path,
        method: requestOptions.method,
        headers: requestOptions.headers
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 400) {
            return reject(new Error(`SNS ${action} failed: ${res.statusCode} ${data}`));
          }
          resolve(data);
        });
      }
    );

    req.on('error', (error) => reject(error));
    req.write(body);
    req.end();
  });
}

async function callGraphQL(query, variables) {
  const body = JSON.stringify({ query, variables });
  const url = new URL(GRAPHQL_ENDPOINT);

  const request = {
    host: url.host,
    path: url.pathname,
    method: 'POST',
    body,
    service: 'appsync',
    region: REGION,
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body)
    }
  };

  aws4.sign(request);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        host: url.host,
        path: url.pathname,
        method: 'POST',
        headers: request.headers
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.errors) {
              return reject(new Error(JSON.stringify(json.errors)));
            }
            resolve(json);
          } catch (error) {
            reject(error);
          }
        });
      }
    );

    req.on('error', (error) => reject(error));
    req.write(body);
    req.end();
  });
}
