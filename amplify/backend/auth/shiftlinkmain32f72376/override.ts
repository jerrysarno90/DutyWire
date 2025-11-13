import {
  AmplifyAuthCognitoStackTemplate,
} from '@aws-amplify/cli-extensibility-helper';
import {
  CfnUserPool,
  CfnUserPoolClient,
} from 'aws-cdk-lib/aws-cognito';

const CUSTOM_ATTRIBUTES = ['orgID', 'siteKey', 'rank'] as const;
const CLIENT_ATTRIBUTE_NAMES = ['email', 'custom:orgID', 'custom:siteKey', 'custom:rank'];

export function override(resources: AmplifyAuthCognitoStackTemplate) {
  const existingSchema = resources.userPool.schema as CfnUserPool.SchemaAttributeProperty[] | undefined;
  const normalizedSchema: CfnUserPool.SchemaAttributeProperty[] = Array.isArray(existingSchema)
    ? [...existingSchema]
    : [];

  const alreadyDefined = new Set(normalizedSchema.map((attribute) => attribute.name));

  CUSTOM_ATTRIBUTES.forEach((name) => {
    if (alreadyDefined.has(name)) {
      return;
    }
    normalizedSchema.push({
      attributeDataType: 'String',
      name,
      mutable: true,
      required: false,
      stringAttributeConstraints: { minLength: '1', maxLength: '64' },
    });
  });

  resources.userPool.schema = normalizedSchema;

  const ensureClientAttributes = (client?: CfnUserPoolClient) => {
    if (!client) {
      return;
    }
    const readAttributes = new Set(client.readAttributes ?? []);
    const writeAttributes = new Set(client.writeAttributes ?? []);
    CLIENT_ATTRIBUTE_NAMES.forEach((attr) => {
      readAttributes.add(attr);
      writeAttributes.add(attr);
    });
    client.readAttributes = Array.from(readAttributes);
    client.writeAttributes = Array.from(writeAttributes);
  };

  ensureClientAttributes(resources.userPoolClient);
  ensureClientAttributes(resources.userPoolClientWeb);
}
