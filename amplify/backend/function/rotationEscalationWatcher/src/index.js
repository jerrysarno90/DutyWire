/* Amplify Params - DO NOT EDIT
	API_SHIFTLINKMAIN_GRAPHQLAPIENDPOINTOUTPUT
	API_SHIFTLINKMAIN_GRAPHQLAPIIDOUTPUT
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const aws4 = require('aws4');
const https = require('https');

const GRAPHQL_ENDPOINT = process.env.API_SHIFTLINKMAIN_GRAPHQLAPIENDPOINTOUTPUT;
const REGION = process.env.REGION;

const LIST_POSTINGS_QUERY = /* GraphQL */ `
  query ListOpenPostings($limit: Int, $nextToken: String) {
    listOvertimePostings(
      limit: $limit
      nextToken: $nextToken
      filter: { needsEscalation: { eq: false }, state: { eq: OPEN } }
    ) {
      items {
        id
        orgId
        title
        createdBy
        startsAt
        createdAt
        policySnapshot
        needsEscalation
        invites(limit: 500) {
          items {
            id
            status
            scheduledAt
            sequence
          }
        }
      }
      nextToken
    }
  }
`;

const MARK_ESCALATION_MUTATION = /* GraphQL */ `
  mutation MarkPostingEscalated($input: UpdateOvertimePostingInput!) {
    updateOvertimePosting(input: $input) {
      id
      needsEscalation
    }
  }
`;

const NOTIFY_OVERTIME_MUTATION = /* GraphQL */ `
  mutation NotifyOvertimeEvent($input: OvertimeNotificationInput!) {
    notifyOvertimeEvent(input: $input) {
      success
    }
  }
`;

exports.handler = async () => {
    try {
        const postings = await fetchAllPostings();
        let escalated = 0;

        for (const posting of postings) {
            const invites = posting.invites?.items ?? [];
            if (invites.length === 0) {
                continue;
            }

            const hasAcceptance = invites.some((invite) => invite.status === 'ACCEPTED');
            if (hasAcceptance) {
                continue;
            }

            const snapshot = parsePolicySnapshot(posting.policySnapshot);
            const responseDeadline = extractResponseDeadline(snapshot.responseDeadline);
            const now = Date.now();

            if (responseDeadline && now > responseDeadline.getTime()) {
                await markPostingForEscalation(posting.id);
                await notifyPostingAuthority(posting, 'Escalate overtime', `${posting.title} has reached its deadline.`);
                escalated += 1;
                console.log(`Marked posting ${posting.id} by response deadline.`);
                continue;
            }

            const latest = computeLatestInviteTime(posting, invites, snapshot);
            if (!latest) {
                continue;
            }

            if (now > latest.getTime()) {
                await markPostingForEscalation(posting.id);
                await notifyPostingAuthority(posting, 'Escalate overtime', `${posting.title} invite rotation completed with no takers.`);
                escalated += 1;
                console.log(`Marked posting ${posting.id} as needing escalation.`);
            }
        }

        return {
            statusCode: 200,
            body: JSON.stringify({ processed: postings.length, escalated })
        };
    } catch (error) {
        console.error('Escalation watcher failed', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Escalation watcher failed', error: error.message })
        };
    }
};

async function fetchAllPostings() {
    const results = [];
    let nextToken = undefined;

    do {
        const response = await callGraphQL(LIST_POSTINGS_QUERY, { limit: 25, nextToken });
        const payload = response?.data?.listOvertimePostings ?? {};
        const items = payload.items ?? [];
        results.push(...items);
        nextToken = payload.nextToken;
    } while (nextToken);

    return results;
}

async function markPostingForEscalation(postingId) {
    await callGraphQL(MARK_ESCALATION_MUTATION, {
        input: { id: postingId, needsEscalation: true }
    });
}

async function notifyPostingAuthority(posting, title, body) {
    const userId = posting.createdBy;
    if (!userId) {
        return;
    }
    const input = {
        orgId: posting.orgId || 'unknown',
        recipients: [userId],
        title,
        body,
        category: 'OVERTIME_ESCALATION',
        postingId: posting.id
    };
    try {
        await callGraphQL(NOTIFY_OVERTIME_MUTATION, { input });
    } catch (error) {
        console.error('[rotationEscalationWatcher] notifyPostingAuthority failed', error);
    }
}

function computeLatestInviteTime(posting, invites, snapshot = {}) {
    const delayMinutes = Number(snapshot.inviteDelayMinutes ?? 0);
    const baseTime = posting.startsAt || posting.createdAt;
    let latest = null;

    for (const invite of invites) {
        let scheduled = invite.scheduledAt ? new Date(invite.scheduledAt) : null;
        if (!scheduled && baseTime && delayMinutes > 0) {
            const sequence = Number(invite.sequence ?? 1);
            const base = new Date(baseTime);
            scheduled = new Date(base.getTime() + Math.max(sequence - 1, 0) * delayMinutes * 60000);
        }

        if (scheduled && (!latest || scheduled > latest)) {
            latest = scheduled;
        }
    }

    return latest;
}

function parsePolicySnapshot(snapshot) {
    if (!snapshot) {
        return {};
    }
    if (typeof snapshot === 'object') {
        return snapshot;
    }
    try {
        return JSON.parse(snapshot);
    } catch (error) {
        console.warn('Unable to parse policy snapshot', error);
        return {};
    }
}

function extractResponseDeadline(value) {
    if (!value) {
        return null;
    }
    const deadline = new Date(value);
    if (Number.isNaN(deadline.getTime())) {
        return null;
    }
    return deadline;
}

async function callGraphQL(query, variables) {
    const body = JSON.stringify({ query, variables });
    const url = new URL(GRAPHQL_ENDPOINT);

    const requestOptions = {
        host: url.host,
        path: url.pathname,
        method: 'POST',
        service: 'appsync',
        region: REGION,
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body)
        },
        body
    };

    aws4.sign(requestOptions);

    return new Promise((resolve, reject) => {
        const req = https.request({
            host: url.host,
            path: url.pathname,
            method: 'POST',
            headers: requestOptions.headers
        }, (res) => {
            let data = '';
            res.on('data', (chunk) => {
                data += chunk;
            });
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
        });

        req.on('error', (err) => reject(err));
        req.write(body);
        req.end();
    });
}
