type AmplifyOutputs = Record<string, unknown>;

type ConfigSource = { default?: AmplifyOutputs } | AmplifyOutputs | undefined;

const loadFromEnv = (): AmplifyOutputs | undefined => {
  const raw = import.meta.env.VITE_AMPLIFY_OUTPUTS ?? import.meta.env.VITE_AMPLIFY_CONFIG;
  if (!raw) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(raw) as AmplifyOutputs;
    return parsed;
  } catch (error) {
    console.warn('Failed to parse VITE_AMPLIFY_OUTPUTS JSON:', error);
    return undefined;
  }
};

const loadFromManifest = (): AmplifyOutputs | undefined => {
  const modules = import.meta.glob<ConfigSource>('../amplify_outputs.json', { eager: true });
  const first = Object.values(modules)[0];

  if (!first) {
    return undefined;
  }

  if (typeof first === 'object' && first !== null && 'default' in first) {
    return (first as { default?: AmplifyOutputs }).default;
  }

  return first as AmplifyOutputs;
};

export const resolveAmplifyOutputs = (): AmplifyOutputs => {
  const outputs: AmplifyOutputs = {};

  const manifestOutputs = loadFromManifest();
  if (manifestOutputs) {
    Object.assign(outputs, manifestOutputs);
  }

  const envOutputs = loadFromEnv();
  if (envOutputs) {
    Object.assign(outputs, envOutputs);
  }

  return outputs;
};
